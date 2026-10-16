import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/persons/contact_import.dart';
import 'package:xpenc/features/persons/edit_person_sheet.dart';

/// GitHub #167: with contacts access off, XPENC shows no way into the
/// address book at all — no contacts button, no picker.
void main() {
  group('contactsAccessAllowed', () {
    test('granted (or iOS limited) shows the buttons', () {
      expect(
        contactsAccessAllowed(PermissionStatus.granted, asked: true),
        isTrue,
      );
      expect(
        contactsAccessAllowed(PermissionStatus.limited, asked: true),
        isTrue,
      );
    });

    test('never asked: shown, so the first tap can ask', () {
      expect(
        contactsAccessAllowed(PermissionStatus.notDetermined, asked: false),
        isTrue,
      );
    });

    test('asked and not granted: hidden — Android reports a turned-off '
        'permission as "not determined" too', () {
      expect(
        contactsAccessAllowed(PermissionStatus.notDetermined, asked: true),
        isFalse,
      );
      for (final s in [
        PermissionStatus.denied,
        PermissionStatus.permanentlyDenied,
        PermissionStatus.restricted,
      ]) {
        expect(contactsAccessAllowed(s, asked: false), isFalse, reason: '$s');
      }
    });

    test('no plugin (tests, desktop): nothing hidden', () {
      expect(contactsAccessAllowed(null, asked: true), isTrue);
    });
  });

  group('Edit person', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, {required bool access}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            contactsAccessProvider.overrideWith((ref) async => access),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: EditPersonSheet(person: null)),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows the contacts button while access is on', (tester) async {
      await pump(tester, access: true);
      expect(find.byTooltip('Pick from contacts'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hides it once access is off', (tester) async {
      await pump(tester, access: false);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Pick from contacts'), findsNothing);
      await unmount(tester);
    });
  });

  group('database', () {
    test('marks contacts access as asked', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect((await db.getSettings()).contactsPermissionAsked, isFalse);
      await db.markContactsPermissionAsked();
      expect((await db.getSettings()).contactsPermissionAsked, isTrue);
    });

    test('a v81 database gains the column on upgrade, as not asked', () async {
      final dir = Directory.systemTemp.createTempSync('xpenc_v82_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v81.sqlite');

      final old = AppDatabase(NativeDatabase(file));
      await old.getSettings();
      await old.customStatement(
        'ALTER TABLE settings DROP COLUMN contacts_permission_asked',
      );
      await old.customStatement('PRAGMA user_version = 81');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect((await upgraded.getSettings()).contactsPermissionAsked, isFalse);
    });
  });
}
