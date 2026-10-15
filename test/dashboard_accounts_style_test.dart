import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';
import 'package:xpenc/features/settings/dashboard_settings_screen.dart';

/// The Dashboard's Accounts widget as a slider of cards or as one card
/// listing every account (GitHub #164).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> addBank() => db.addAccount(
    name: 'IPPB Savings',
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(5000),
  );

  /// The account names drawn inside a sideways-scrolling list.
  Finder inSlider(String name) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    ),
    matching: find.text(name),
  );

  test('defaults to the slider, and the choice is stored', () async {
    expect(
      (await db.getSettings()).dashboardAccountsStyle,
      DashboardAccountsStyle.slider,
    );
    await db.setDashboardAccountsStyle(DashboardAccountsStyle.oneCard);
    expect(
      (await db.getSettings()).dashboardAccountsStyle,
      DashboardAccountsStyle.oneCard,
    );
  });

  testWidgets('slider: every account sits in the sideways row', (tester) async {
    await tester.runAsync(addBank);
    await pump(tester, const DashboardScreen());
    expect(tester.takeException(), isNull);
    expect(inSlider('Cash'), findsOneWidget);
    expect(inSlider('IPPB Savings'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('one card: every account on its own row, nothing to swipe', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await addBank();
      await db.setDashboardAccountsStyle(DashboardAccountsStyle.oneCard);
    });
    await pump(tester, const DashboardScreen());
    expect(tester.takeException(), isNull);
    expect(inSlider('Cash'), findsNothing);
    expect(inSlider('IPPB Savings'), findsNothing);
    expect(find.text('IPPB Savings'), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Accounts'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Customize dashboard switches the Accounts widget', (
    tester,
  ) async {
    await pump(tester, const DashboardSettingsScreen());
    await tester.dragUntilVisible(
      find.text('One card'),
      find.byType(CustomScrollView),
      const Offset(0, -150),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('One card'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    final stored = await tester.runAsync(db.getSettings);
    expect(stored!.dashboardAccountsStyle, DashboardAccountsStyle.oneCard);
    expect(find.textContaining('nothing to swipe'), findsOneWidget);
    await unmount(tester);
  });

  test('a v79 database gains the column on upgrade, set to slider', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v80_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v79.sqlite');

    final old = AppDatabase(NativeDatabase(file));
    await old.getSettings();
    await old.customStatement(
      'ALTER TABLE settings DROP COLUMN dashboard_accounts_style',
    );
    await old.customStatement('PRAGMA user_version = 79');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(
      (await upgraded.getSettings()).dashboardAccountsStyle,
      DashboardAccountsStyle.slider,
    );
  });
}
