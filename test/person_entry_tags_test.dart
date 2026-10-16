import 'dart:convert';
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
import 'package:xpenc/features/persons/person_detail_screen.dart';

/// GitHub #168: tags on money lent and borrowed. An entry keeps its own
/// tags; when it moved money, its ledger row carries the same tags so it
/// shows by tag in Transactions too.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<PersonEntryRow> entry(int id) async =>
      (await db.select(db.personEntries).get()).firstWhere((e) => e.id == id);

  Future<Set<int>> txTags(int? txId) async =>
      txId == null ? {} : (await db.tagIdsForTransaction(txId)).toSet();

  late int trip;
  late int food;

  setUp(() async {
    trip = await db.addTag(name: 'Goa trip', colorValue: 0xFF0EA5E9);
    food = await db.addTag(name: 'Food', colorValue: 0xFFF97316);
  });

  test('an entry that moved money: tagged, and so is its ledger row', () async {
    final asha = await db.addPerson('Asha');
    final id = await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: await cashId(),
      tagIds: {trip, food},
    );

    expect(await db.tagIdsForPersonEntry(id), {trip, food});
    expect(await txTags((await entry(id)).transactionId), {trip, food});
  });

  test('an entry that only records who owes whom keeps its tags', () async {
    final asha = await db.addPerson('Asha');
    final id = await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(200),
      date: DateTime(2026, 10, 1),
      tagIds: {trip},
    );

    expect((await entry(id)).transactionId, isNull);
    expect(await db.tagIdsForPersonEntry(id), {trip});
  });

  test(
    'editing keeps the tags — the rebuilt ledger row carries them too',
    () async {
      final asha = await db.addPerson('Asha');
      final id = await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 10, 1),
        accountId: await cashId(),
        tagIds: {trip},
      );
      final oldTx = (await entry(id)).transactionId;

      await db.updatePersonEntry(
        id: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(650),
        date: DateTime(2026, 10, 2),
        accountId: await cashId(),
      );

      final newTx = (await entry(id)).transactionId;
      expect(newTx, isNot(oldTx));
      expect(await db.tagIdsForPersonEntry(id), {trip});
      expect(await txTags(newTx), {trip});
    },
  );

  test('editing with new tags replaces them on both', () async {
    final asha = await db.addPerson('Asha');
    final id = await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: await cashId(),
      tagIds: {trip},
    );

    await db.updatePersonEntry(
      id: id,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: await cashId(),
      tagIds: {food},
    );

    expect(await db.tagIdsForPersonEntry(id), {food});
    expect(await txTags((await entry(id)).transactionId), {food});
  });

  test('tagging the ledger row from Transactions updates the entry', () async {
    final asha = await db.addPerson('Asha');
    final id = await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: await cashId(),
    );

    await db.setTransactionTags((await entry(id)).transactionId!, {food});

    expect(await db.tagIdsForPersonEntry(id), {food});
  });

  test('a tagged entry, and its person, can still be deleted', () async {
    final asha = await db.addPerson('Asha');
    final id = await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: await cashId(),
      tagIds: {trip},
    );
    await db.deletePersonEntry(id);
    expect(await db.select(db.personEntryTags).get(), isEmpty);

    final ravi = await db.addPerson('Ravi');
    await db.addPersonEntry(
      personId: ravi,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(100),
      date: DateTime(2026, 10, 1),
      tagIds: {food},
    );
    await db.deletePerson(ravi);
    expect(await db.select(db.personEntryTags).get(), isEmpty);
  });

  test('deleting a tag takes it off entries, Auto rules and tag groups — '
      'none of them blocks the delete', () async {
    final asha = await db.addPerson('Asha');
    await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(100),
      date: DateTime(2026, 10, 1),
      tagIds: {trip},
    );
    final rule = await db.addRecurringRule(
      name: 'Rent',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(100),
      accountId: await cashId(),
      categoryId:
          (await db.watchCategories(CategoryKind.expense).first).first.id,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 1, 1),
    );
    await db.setRecurringRuleTags(rule, {trip});
    final group = await db.addTagGroup(name: 'Holidays', colorValue: 0);
    await db.setTagGroupTags(group, {trip});

    await db.deleteTag(trip);

    final left = await db.select(db.tags).get();
    expect(left.map((t) => t.id), isNot(contains(trip)));
    expect(await db.select(db.personEntryTags).get(), isEmpty);
  });

  test('backups carry entry tags', () async {
    final asha = await db.addPerson('Asha');
    await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(100),
      date: DateTime(2026, 10, 1),
      tagIds: {trip, food},
    );
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.importAll(dump);

    final links = await fresh.select(fresh.personEntryTags).get();
    expect(links.map((l) => l.tagId).toSet(), {trip, food});
  });

  test('a v83 database gains the table on upgrade', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v84_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v83.sqlite');

    final old = AppDatabase(NativeDatabase(file));
    await old.getSettings();
    await old.customStatement('DROP TABLE person_entry_tags');
    await old.customStatement('PRAGMA user_version = 83');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await expectLater(
      upgraded.select(upgraded.personEntryTags).get(),
      completion(isEmpty),
    );
  });

  testWidgets('a person’s page shows each entry’s tags', (tester) async {
    final asha = await tester.runAsync(() async {
      final id = await db.addPerson('Asha');
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 10, 1),
        accountId: await cashId(),
        tagIds: {trip},
      );
      return id;
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PersonDetailScreen(personId: asha!),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Goa trip'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
