import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the selected UI language independently from the financial database.
class AppLanguageStore {
  static const _fileName = 'xpenc_language.txt';

  Future<File> _languageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<Locale> loadLocale() async {
    try {
      final file = await _languageFile();
      if (!await file.exists()) return const Locale('en');
      final code = (await file.readAsString()).trim();
      return code == 'ar' ? const Locale('ar') : const Locale('en');
    } catch (_) {
      return const Locale('en');
    }
  }

  Future<void> saveLocale(Locale locale) async {
    try {
      final file = await _languageFile();
      await file.writeAsString(
        locale.languageCode == 'ar' ? 'ar' : 'en',
        flush: true,
      );
    } catch (_) {
      // Keep the in-memory selection even if device storage is unavailable.
    }
  }
}
