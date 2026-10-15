import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/money_text.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';

/// GitHub #159: money coming in and going out is labelled "Money in" /
/// "Money out" — a refund or a meal voucher isn't income, and tax isn't an
/// everyday expense. The labels are longer than "Income" / "Expense", so they
/// must still fit a 360dp phone at a larger text size.
void main() {
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  test('a transaction type reads as money in / money out', () {
    expect(labelForTxType(TxType.income), 'Money in');
    expect(labelForTxType(TxType.expense), 'Money out');
  });

  testWidgets('Add transaction: Money out / Money in / Transfer fit', (
    tester,
  ) async {
    await pump(tester, const AddTransactionScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Money out'), findsWidgets);
    expect(find.text('Money in'), findsWidgets);
    expect(find.text('Income'), findsNothing);
    expect(find.text('Expense'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Dashboard: the month card says Money in / Money out', (
    tester,
  ) async {
    await pump(tester, const DashboardScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Money in'), findsWidgets);
    expect(find.text('Money out'), findsWidgets);
    expect(find.text('Income'), findsNothing);
    await unmount(tester);
  });
}
