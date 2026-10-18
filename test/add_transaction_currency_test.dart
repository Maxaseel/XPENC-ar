import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/amount_keypad_field.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {TxType? initialType}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AddTransactionScreen(initialType: initialType),
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

  /// Opens the "Paid via"/account picker and taps the account named [name].
  Future<void> pickAccount(WidgetTester tester, String name) async {
    await tester.tap(find.text('Select account').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'the inline amount field uses the selected account\'s currency',
    (tester) async {
      await db.addAccount(
        name: 'Travel',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
        currencyCode: 'USD',
      );

      await pump(tester, initialType: TxType.expense);
      await pickAccount(tester, 'Travel');

      final amountField = tester.widget<TextField>(
        find.byKey(const Key('amountInput')),
      );
      expect(amountField.decoration!.prefixText, contains(r'$'));
      expect(amountField.decoration!.prefixText, isNot(contains('₹')));
      expect(find.byType(AmountKeypadGrid), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets(
    'expense and income accept direct amount entry without the calculator',
    (tester) async {
      await pump(tester, initialType: TxType.expense);
      final amountFinder = find.byKey(const Key('amountInput'));
      expect(amountFinder, findsOneWidget);
      expect(find.byType(AmountKeypadGrid), findsNothing);

      await tester.ensureVisible(amountFinder);
      await tester.enterText(amountFinder, '123.45');
      await tester.pump();
      expect(
        tester.widget<TextField>(amountFinder).controller!.text,
        '123.45',
      );

      await tester.tap(find.text('Income'));
      await tester.pump();
      expect(amountFinder, findsOneWidget);
      expect(
        tester.widget<TextField>(amountFinder).controller!.text,
        '123.45',
      );
      expect(find.byType(AmountKeypadGrid), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('transfers retain the existing amount keypad', (tester) async {
    await pump(tester, initialType: TxType.expense);
    await tester.tap(find.text('Transfer'));
    await tester.pump();

    expect(find.byKey(const Key('amountInput')), findsNothing);
    expect(find.byKey(const Key('amountDisplay')), findsOneWidget);
    expect(find.byType(AmountKeypadGrid), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    "the #85 'Foreign currency' toggle is hidden once the account has its "
    'own currency',
    (tester) async {
      await db.addAccount(
        name: 'Home wallet',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      await db.addAccount(
        name: 'Travel',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
        currencyCode: 'USD',
      );

      await pump(tester, initialType: TxType.expense);

      await pickAccount(tester, 'Home wallet');
      expect(find.text('Foreign currency'), findsOneWidget);

      await tester.tap(find.text('Home wallet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Travel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Foreign currency'), findsNothing);

      await unmount(tester);
    },
  );
}
