import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/week_start.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/calendar/calendar_screen.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';

/// GitHub #166: the week starts on Sunday or Monday — in the Calendar tab
/// and in every date picker.
void main() {
  group('grid', () {
    // 1 October 2026 is a Thursday.
    final october = DateTime(2026, 10, 1);

    test('Monday first: Mon–Wed come before the 1st', () {
      expect(WeekStart.monday.leadingBlanks(october), 3);
      expect(WeekStart.monday.initials.first, 'M');
    });

    test('Sunday first: Sun–Wed come before the 1st', () {
      expect(WeekStart.sunday.leadingBlanks(october), 4);
      expect(WeekStart.sunday.initials.first, 'S');
    });

    test('a month starting on the first day has no blanks', () {
      expect(WeekStart.monday.leadingBlanks(DateTime(2026, 6, 1)), 0); // Mon
      expect(WeekStart.sunday.leadingBlanks(DateTime(2026, 11, 1)), 0); // Sun
    });
  });

  testWidgets('date pickers read the first day from the setting', (
    tester,
  ) async {
    for (final (start, index) in [
      (WeekStart.sunday, 0),
      (WeekStart.monday, 1),
    ]) {
      late int seen;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [WeekStartLocalizationsDelegate(start)],
          home: Builder(
            builder: (context) {
              seen = MaterialLocalizations.of(context).firstDayOfWeekIndex;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, index, reason: '$start');
    }
  });

  group('screens', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    double leftOf(WidgetTester tester, String label) =>
        tester.getTopLeft(find.text(label).first).dx;

    testWidgets('Calendar starts its weeks on Monday by default', (
      tester,
    ) async {
      await pump(tester, const CalendarScreen());
      expect(tester.takeException(), isNull);
      expect(leftOf(tester, 'M'), lessThan(leftOf(tester, 'W')));
      expect(leftOf(tester, 'M'), lessThan(leftOf(tester, 'S')));
      await unmount(tester);
    });

    testWidgets('…and on Sunday when chosen', (tester) async {
      await tester.runAsync(() => db.setWeekStart(WeekStart.sunday));
      await pump(tester, const CalendarScreen());
      expect(tester.takeException(), isNull);
      expect(leftOf(tester, 'S'), lessThan(leftOf(tester, 'M')));
      await unmount(tester);
    });

    testWidgets('General → Calendar → Week starts on stores the choice', (
      tester,
    ) async {
      await pump(tester, const GeneralSettingsScreen());
      await tester.dragUntilVisible(
        find.text('Sunday'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sunday'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      final stored = await tester.runAsync(db.getSettings);
      expect(stored!.weekStart, WeekStart.sunday);
      await unmount(tester);
    });
  });

  test('a v82 database gains the column on upgrade, as Monday', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v83_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v82.sqlite');

    final old = AppDatabase(NativeDatabase(file));
    await old.getSettings();
    await old.customStatement('ALTER TABLE settings DROP COLUMN week_start');
    await old.customStatement('PRAGMA user_version = 82');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.getSettings()).weekStart, WeekStart.monday);
  });
}
