import 'package:flutter/material.dart' as m;

import 'app_translations.dart';

/// The app root updates this before building its widget tree so static widget
/// properties can use the active locale as well.
class AppTextLocale {
  AppTextLocale._();

  static m.Locale current = const m.Locale('en');
}

/// Returns Arabic for an explicitly marked UI string when Arabic is active.
String appText(m.BuildContext context, String english, [String? arabic]) =>
    _localized(m.Localizations.localeOf(context), english, arabic);

/// Localizes a static widget property using the locale most recently built by
/// the app root. Use [appText] when a BuildContext is available.
String appTextValue(String english, [String? arabic]) =>
    _localized(AppTextLocale.current, english, arabic);

String _localized(m.Locale locale, String english, String? arabic) {
  if (locale.languageCode != 'ar') return english;
  return arabic ?? arabicUiStrings[english] ?? english;
}

/// A drop-in Text wrapper. `Text.localized` is for source-code UI literals;
/// the regular constructor leaves user-entered and database text untouched.
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.textScaler,
    this.textScaleFactor,
    this.selectionColor,
  }) : _localized = false,
       text = null;

  const Text.localized(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.textScaler,
    this.textScaleFactor,
    this.selectionColor,
  }) : _localized = true,
       text = null;

  const Text.rich(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.textScaler,
    this.textScaleFactor,
    this.selectionColor,
  }) : _localized = true,
       data = null;

  final String? data;
  final m.InlineSpan? text;
  final bool _localized;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.TextScaler? textScaler;
  @Deprecated('Use textScaler instead.')
  final double? textScaleFactor;
  final m.Color? selectionColor;

  @override
  m.Widget build(m.BuildContext context) {
    final renderedSpan = text == null ? null : _translateSpan(context, text!);
    final renderedData = _localized && data != null
        ? appText(context, data!)
        : data;
    final renderedSemantics = _localized && semanticsLabel != null
        ? appText(context, semanticsLabel!)
        : semanticsLabel;

    if (renderedSpan != null) {
      return m.Text.rich(
        renderedSpan,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: renderedSemantics,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        textScaler: textScaler,
        textScaleFactor: textScaleFactor,
        selectionColor: selectionColor,
      );
    }

    return m.Text(
      renderedData,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: renderedSemantics,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      textScaler: textScaler,
      textScaleFactor: textScaleFactor,
      selectionColor: selectionColor,
    );
  }
}

m.InlineSpan _translateSpan(m.BuildContext context, m.InlineSpan span) {
  if (span is m.TextSpan) {
    return span.copyWith(
      text: span.text == null ? null : appText(context, span.text!),
      children: span.children
          ?.map((child) => _translateSpan(context, child))
          .toList(growable: false),
    );
  }
  return span;
}
