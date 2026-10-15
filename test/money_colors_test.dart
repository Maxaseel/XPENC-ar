import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_colors.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/money_text.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/settings/colors_settings_screen.dart';

/// Settings → Colours (GitHub #156): each money direction's colour is the
/// person's pick, and transaction icons can follow the category, the
/// direction, or one colour.
void main() {
  // The colours are app-wide statics; put them back after every test.
  tearDown(() {
    AppColors.configure();
    TxIconStyle.configure(TxIconBackground.category, null);
  });

  group('AppColors.configure', () {
    test('null keeps the built-in colour, and reports a change', () {
      expect(AppColors.configure(), isFalse);
      expect(AppColors.income, AppColors.defaultIncome);

      expect(AppColors.configure(expense: const Color(0xFFDB2777)), isTrue);
      expect(AppColors.expense, const Color(0xFFDB2777));
      expect(AppColors.income, AppColors.defaultIncome);
      expect(colorForTxType(TxType.expense), const Color(0xFFDB2777));

      // Same again: nothing to rebuild.
      expect(AppColors.configure(expense: const Color(0xFFDB2777)), isFalse);
    });
  });

  group('txIconColor', () {
    const category = Color(0xFFF97316);

    test('category (default) keeps the row’s own colour', () {
      expect(txIconColor(TxType.expense, category), category);
    });

    test('direction uses the money colour', () {
      TxIconStyle.configure(TxIconBackground.direction, null);
      expect(txIconColor(TxType.expense, category), AppColors.expense);
      expect(txIconColor(TxType.income, category), AppColors.income);
    });

    test('single uses the picked colour, or the default until picked', () {
      TxIconStyle.configure(TxIconBackground.single, null);
      expect(txIconColor(TxType.expense, category), TxIconStyle.defaultSingle);
      TxIconStyle.configure(TxIconBackground.single, const Color(0xFF0D9488));
      expect(txIconColor(TxType.income, category), const Color(0xFF0D9488));
    });
  });

  testWidgets('rebuildAllWidgets repaints a const widget with the new colour', (
    tester,
  ) async {
    await tester.pumpWidget(const _ReadsIncome());
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
      AppColors.defaultIncome,
    );

    AppColors.configure(income: const Color(0xFF0EA5E9));
    await tester.pump();
    // A const widget doesn't rebuild on its own…
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
      AppColors.defaultIncome,
    );
    rebuildAllWidgets();
    await tester.pump();
    // …until everything is marked.
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
      const Color(0xFF0EA5E9),
    );
  });

  group('database', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('starts on the built-in colours and category icons', () async {
      final s = await db.getSettings();
      expect(s.incomeColor, isNull);
      expect(s.expenseColor, isNull);
      expect(s.transferColor, isNull);
      expect(s.personColor, isNull);
      expect(s.txIconBackground, TxIconBackground.category);
      expect(s.txIconColor, isNull);
    });

    test('stores and clears the picks', () async {
      await db.setMoneyColors(
        income: 0xFF0EA5E9,
        expense: 0xFFDB2777,
        transfer: null,
        person: 0xFF65A30D,
      );
      await db.setTxIconStyle(TxIconBackground.single, color: 0xFF0D9488);
      var s = await db.getSettings();
      expect(s.incomeColor, 0xFF0EA5E9);
      expect(s.expenseColor, 0xFFDB2777);
      expect(s.transferColor, isNull);
      expect(s.personColor, 0xFF65A30D);
      expect(s.txIconBackground, TxIconBackground.single);
      expect(s.txIconColor, 0xFF0D9488);

      await db.setMoneyColors(
        income: null,
        expense: null,
        transfer: null,
        person: null,
      );
      await db.setTxIconStyle(TxIconBackground.category);
      s = await db.getSettings();
      expect(s.incomeColor, isNull);
      expect(s.txIconBackground, TxIconBackground.category);
      expect(s.txIconColor, isNull);
    });

    test('a v80 database gains the colour columns on upgrade', () async {
      final dir = Directory.systemTemp.createTempSync('xpenc_v81_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v80.sqlite');

      final old = AppDatabase(NativeDatabase(file));
      await old.getSettings();
      for (final column in [
        'income_color',
        'expense_color',
        'transfer_color',
        'person_color',
        'tx_icon_background',
        'tx_icon_color',
      ]) {
        await old.customStatement('ALTER TABLE settings DROP COLUMN $column');
      }
      await old.customStatement('PRAGMA user_version = 80');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final s = await upgraded.getSettings();
      expect(s.incomeColor, isNull);
      expect(s.txIconBackground, TxIconBackground.category);
    });
  });

  group('Colours screen', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ColorsSettingsScreen(),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('picking a swatch stores it; the hex field takes any colour', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Money in'), findsWidgets);
      expect(find.text('Money out'), findsWidgets);

      await tester.tap(find.text('Money out').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Pink, from the swatches.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  const Color(0xFFDB2777) &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      var s = await tester.runAsync(db.getSettings);
      expect(s!.expenseColor, 0xFFDB2777);

      await tester.tap(find.text('People').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '123abc');
      await tester.tap(find.text('Use'));
      await settle(tester);
      s = await tester.runAsync(db.getSettings);
      expect(s!.personColor, 0xFF123ABC);
      await unmount(tester);
    });

    testWidgets('One colour shows its picker, and Reset puts it all back', (
      tester,
    ) async {
      await pump(tester);
      await tester.dragUntilVisible(
        find.text('One colour'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('One colour'));
      await settle(tester);
      var s = await tester.runAsync(db.getSettings);
      expect(s!.txIconBackground, TxIconBackground.single);
      expect(find.text('Icon colour'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Reset all colours'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Reset all colours'));
      await settle(tester);
      s = await tester.runAsync(db.getSettings);
      expect(s!.txIconBackground, TxIconBackground.category);
      expect(find.text('Icon colour'), findsNothing);
      await unmount(tester);
    });
  });
}

class _ReadsIncome extends StatelessWidget {
  const _ReadsIncome();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.income, child: const SizedBox(width: 10));
}
