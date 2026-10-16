import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/settings/currency_settings_screen.dart';

/// A currency the app doesn't list, made by the person: it works like any
/// built-in one — parent currency, an account's own, an exchange rate — and
/// survives restarts and backups.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    await db.close();
    setCustomCurrencyList(const []);
  });

  Future<void> addIsland() => db.addCustomCurrency(
    code: 'isd',
    symbol: 'I\$',
    name: 'Island Dollar',
    decimalDigits: 0,
  );

  group('making one', () {
    test('it resolves everywhere a code is looked up', () async {
      await addIsland();
      final c = currencyForCode('ISD');
      expect(c.code, 'ISD'); // made capital
      expect(c.symbol, 'I\$');
      expect(c.name, 'Island Dollar');
      expect(c.decimalDigits, 0);
      expect(allCurrencies.first.code, 'ISD');
    });

    test('rejects a bad code, a built-in code, a repeat, and blanks', () async {
      Future<void> add(String code, {String symbol = 'X', String name = 'X'}) =>
          db.addCustomCurrency(code: code, symbol: symbol, name: name);

      await expectLater(add('AB'), throwsArgumentError);
      await expectLater(add('A1C'), throwsArgumentError);
      await expectLater(add('USD'), throwsArgumentError);
      await expectLater(add('QQQ', symbol: '  '), throwsArgumentError);
      await expectLater(add('QQQ', name: ''), throwsArgumentError);
      await add('QQQ');
      await expectLater(add('qqq'), throwsArgumentError);
    });

    test(
      'works as the parent currency, an account’s and with a rate',
      () async {
        await addIsland();
        await db.setCurrencyCode('ISD');
        expect((await db.getSettings()).currencyCode, 'ISD');

        await db.setCurrencyCode('INR');
        final account = await db.addAccount(
          name: 'Island wallet',
          type: AccountType.cash,
          colorValue: 0,
          iconKey: 'cash',
          openingBalance: Money.fromRupees(100),
          currencyCode: 'ISD',
        );
        expect(account, isPositive);
        await db.addCurrencyRate(
          currencyCode: 'ISD',
          rateToBaseMicros: 2500000,
          effectiveAt: DateTime(2026, 10, 1),
        );
      },
    );

    test('editing changes symbol, name and decimals — not the code', () async {
      await addIsland();
      await db.updateCustomCurrency(
        code: 'ISD',
        symbol: 'Ɨ',
        name: 'Isle Dollar',
        decimalDigits: 2,
      );
      final c = currencyForCode('ISD');
      expect(c.symbol, 'Ɨ');
      expect(c.name, 'Isle Dollar');
      expect(c.decimalDigits, 2);
    });
  });

  group('deleting one', () {
    test(
      'refused while the parent currency, an account or a rule uses it',
      () async {
        await addIsland();
        await db.setCurrencyCode('ISD');
        await expectLater(db.deleteCustomCurrency('ISD'), throwsArgumentError);

        await db.setCurrencyCode('INR');
        await db.addAccount(
          name: 'Island wallet',
          type: AccountType.cash,
          colorValue: 0,
          iconKey: 'cash',
          openingBalance: const Money.zero(),
          currencyCode: 'ISD',
        );
        await expectLater(
          db.deleteCustomCurrency('ISD'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Island wallet'),
            ),
          ),
        );
        expect(currencyForCode('ISD').code, 'ISD');
      },
    );

    test('allowed when unused — its rates go with it', () async {
      await addIsland();
      await db.addCurrencyRate(
        currencyCode: 'ISD',
        rateToBaseMicros: 2500000,
        effectiveAt: DateTime(2026, 10, 1),
      );

      await db.deleteCustomCurrency('ISD');

      expect(await db.select(db.customCurrencies).get(), isEmpty);
      expect(await db.select(db.currencyRates).get(), isEmpty);
      expect(currencyForCode('ISD'), kDefaultCurrency);
    });
  });

  test('loaded again when the app opens', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_cc_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await first.addCustomCurrency(code: 'ISD', symbol: 'I', name: 'Island');
    await first.close();
    setCustomCurrencyList(const []);

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    await reopened.getSettings();
    expect(currencyForCode('ISD').name, 'Island');
  });

  test('backups carry them', () async {
    await addIsland();
    await db.setCurrencyCode('ISD');
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    setCustomCurrencyList(const []);

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.importAll(dump);

    expect(await fresh.select(fresh.customCurrencies).get(), hasLength(1));
    expect((await fresh.getSettings()).currencyCode, 'ISD');
    expect(currencyForCode('ISD').name, 'Island Dollar');
  });

  test('a v84 database gains the table on upgrade', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v85_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v84.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await old.getSettings();
    await old.customStatement('DROP TABLE custom_currencies');
    await old.customStatement('PRAGMA user_version = 84');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await expectLater(
      upgraded.select(upgraded.customCurrencies).get(),
      completion(isEmpty),
    );
  });

  testWidgets('Settings → Currency → Create a custom currency', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CurrencySettingsScreen(),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    await tester.tap(find.text('Create a custom currency'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Custom currency'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'isd');
    await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'I\$');
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Island Dollar',
    );
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await settle();
    expect(tester.takeException(), isNull);

    final rows = await tester.runAsync(
      () => db.select(db.customCurrencies).get(),
    );
    expect(rows!.single.code, 'ISD');
    expect(find.text('Island Dollar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
