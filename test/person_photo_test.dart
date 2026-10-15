import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/persons/edit_person_sheet.dart';
import 'package:xpenc/features/persons/person_photo_storage.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// A 1×1 PNG — a real image, so nothing fails to decode it.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

/// A person's profile photo, chosen from the gallery.
void main() {
  late Directory temp;
  late Directory docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('xpenc_person_photo_');
    docs = Directory('${temp.path}/docs')..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('storeFile copies the picked image into app storage, keeping its '
      'extension', () async {
    final picked = File('${temp.path}/picked.png')..writeAsBytesSync(_png);

    final stored = await PersonPhotoStorage.storeFile(picked);

    expect(stored, startsWith('${docs.path}/person_photos/'));
    expect(stored, endsWith('.png'));
    expect(File(stored).readAsBytesSync(), _png);
  });

  testWidgets('Add photo picks from the gallery and Save keeps it', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final picked = File('${temp.path}/picked.png')..writeAsBytesSync(_png);

    // The gallery: hands back the picked file, and asks for a small image.
    Map<Object?, Object?>? pickArgs;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async {
        if (call.method != 'pickImage') return null;
        pickArgs = call.arguments as Map<Object?, Object?>;
        return picked.path;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/image_picker'),
        null,
      ),
    );

    final person = await tester.runAsync(() async {
      final id = await db.addPerson('Asha');
      return (await db.watchPersons().first).firstWhere((p) => p.id == id);
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: EditPersonSheet(person: person)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Add photo'), findsOneWidget);

    await tester.tap(find.text('Add photo'));
    // The copy into app storage is real file IO.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(pickArgs?['source'], 1); // ImageSource.gallery
    expect(pickArgs?['maxWidth'], 512.0);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.byTooltip('Remove photo'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    final saved = await tester.runAsync(
      () async =>
          (await db.watchPersons().first).firstWhere((p) => p.id == person!.id),
    );
    expect(saved!.photoPath, isNotNull);
    expect(saved.photoPath, contains('person_photos'));
    expect(saved.photoPath, isNot(picked.path));
    expect(File(saved.photoPath!).existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
