import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/tables.dart';

/// Settings → General → Calendar → Week starts on (GitHub #166): which day
/// leads every week the app draws — the Calendar tab and every date picker.
extension WeekStartX on WeekStart {
  /// [MaterialLocalizations.firstDayOfWeekIndex]: 0 is Sunday, 1 Monday.
  int get materialIndex => this == WeekStart.sunday ? 0 : 1;

  /// One-letter weekday labels, in this week's order.
  List<String> get initials => this == WeekStart.sunday
      ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// How many blank cells come before [firstOfMonth] in a 7-wide month grid.
  int leadingBlanks(DateTime firstOfMonth) => this == WeekStart.sunday
      ? firstOfMonth.weekday % 7
      : firstOfMonth.weekday - 1;
}

/// The app's English Material strings, with the week starting where the
/// person chose — the first column every date picker draws.
class WeekStartMaterialLocalizations extends DefaultMaterialLocalizations {
  const WeekStartMaterialLocalizations(this.firstDayOfWeekIndex);

  @override
  final int firstDayOfWeekIndex;
}

/// Hands [WeekStartMaterialLocalizations] to `MaterialApp`, ahead of the
/// default — and reloads when the setting changes.
class WeekStartLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const WeekStartLocalizationsDelegate(this.weekStart);

  final WeekStart weekStart;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(
    WeekStartMaterialLocalizations(weekStart.materialIndex),
  );

  @override
  bool shouldReload(WeekStartLocalizationsDelegate old) =>
      old.weekStart != weekStart;
}
