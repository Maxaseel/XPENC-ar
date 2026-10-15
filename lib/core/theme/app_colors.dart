import 'package:flutter/material.dart';

/// Semantic colour is reserved for money direction only — it must always
/// *mean* something, and it must mean the same thing in every theme. Green is
/// income whether the app is monochrome or violet; a theme may never repaint it.
///
/// The person may (GitHub #156): Settings → Colours picks the hue for each
/// direction. That keeps the rule — one direction, one colour, everywhere —
/// only the hue is theirs. So these are read at build time, never baked into
/// a `const`; `XpencApp` calls [configure] and rebuilds every widget when
/// they change.
class AppColors {
  const AppColors._();

  static const defaultIncome = Color(0xFF16A34A);
  static const defaultExpense = Color(0xFFDC2626);
  static const defaultTransfer = Color(0xFF2563EB);
  static const defaultPerson = Color(0xFFA855F7);

  /// Money in.
  static Color income = defaultIncome;

  /// Money out.
  static Color expense = defaultExpense;

  /// Neither in nor out — moves between your own accounts.
  static Color transfer = defaultTransfer;

  /// Money moved to or from a person. It leaves (or enters) your account, but
  /// lending is not spending and being repaid is not earning — so it wears
  /// neither green nor red.
  static Color person = defaultPerson;

  /// Points the direction colours at the person's picks — null keeps the
  /// default. Returns whether anything changed, so the caller only forces a
  /// full rebuild when it has to.
  static bool configure({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? person,
  }) {
    final nextIncome = income ?? defaultIncome;
    final nextExpense = expense ?? defaultExpense;
    final nextTransfer = transfer ?? defaultTransfer;
    final nextPerson = person ?? defaultPerson;
    if (nextIncome == AppColors.income &&
        nextExpense == AppColors.expense &&
        nextTransfer == AppColors.transfer &&
        nextPerson == AppColors.person) {
      return false;
    }
    AppColors.income = nextIncome;
    AppColors.expense = nextExpense;
    AppColors.transfer = nextTransfer;
    AppColors.person = nextPerson;
    return true;
  }

  /// A balance correction — the ledger catching up with reality. Neither
  /// earned nor spent, and deliberately a "look at this" amber.
  static const correction = Color(0xFFD97706);

  /// The default accent, used when no theme is loaded yet. Live code should
  /// read the accent off the theme (`colorScheme.secondary`) so it follows the
  /// palette the user picked.
  static const accent = Color(0xFF2563EB);
}

/// Marks every element in the app to rebuild — what a change to
/// [AppColors] (GitHub #156) needs, since a `const` widget never rebuilds on
/// its own and these colours are read at build time. State is kept: nothing
/// is remounted, only built again. Call it after a frame, never during one.
void rebuildAllWidgets() {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

/// Every colour a theme varies. Semantic money colours are deliberately absent.
///
/// The two rules a palette must obey:
///  * [surfaceHigh] (cards) must be clearly distinct from [bg] (the page), or
///    cards dissolve into the background.
///  * [track] must read as a groove against [surfaceHigh], or an empty progress
///    bar is invisible.
@immutable
class Palette {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.track,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.primary,
    required this.onPrimary,
  });

  final Brightness brightness;

  /// The page, behind the cards.
  final Color bg;

  /// Page-level surface: app bars, sheets, input fills.
  final Color surface;

  /// Cards — raised above [bg].
  final Color surfaceHigh;

  /// The unfilled part of a progress bar.
  final Color track;

  final Color border;
  final Color text;
  final Color textMuted;

  /// Interactive accent: the ➕ button, focus rings, links.
  final Color accent;

  /// Filled buttons and badges. Monochrome palettes make this the text colour;
  /// vivid palettes make it the accent.
  final Color primary;
  final Color onPrimary;
}

/// The palettes the presets are built from.
class AppPalettes {
  const AppPalettes._();

  // ── Monochrome: minimal chrome, one accent ───────────────────────────────
  static const monoLight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F5),
    surface: Color(0xFFF2F2F5),
    surfaceHigh: Color(0xFFFFFFFF),
    track: Color(0xFFE5E5EA),
    border: Color(0xFFDBDBE1),
    text: Color(0xFF0A0A0B),
    textMuted: Color(0xFF6B6B70),
    accent: Color(0xFF2563EB),
    primary: Color(0xFF0A0A0B),
    onPrimary: Color(0xFFFFFFFF),
  );

  /// True black, AMOLED friendly.
  static const monoDark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E10),
    surfaceHigh: Color(0xFF17171A),
    track: Color(0xFF232328),
    border: Color(0xFF2F2F35),
    text: Color(0xFFF5F5F6),
    textMuted: Color(0xFF9A9AA0),
    accent: Color(0xFF3B82F6),
    primary: Color(0xFFF5F5F6),
    onPrimary: Color(0xFF0A0A0B),
  );

  // ── Noir: warm ink, coral & gold accent ─────────────────────────────────
  /// Cream paper, near-black ink. The coral is deepened from [noirDark]'s so
  /// it still holds contrast on a light page.
  static const noirLight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F1EA),
    surface: Color(0xFFF6F1EA),
    surfaceHigh: Color(0xFFFFFDFA),
    track: Color(0xFFE9E0D5),
    border: Color(0xFF1B1118),
    text: Color(0xFF140D12),
    textMuted: Color(0xFF6E6268),
    accent: Color(0xFFE2541B),
    primary: Color(0xFF140D12),
    onPrimary: Color(0xFFFFF7EE),
  );

  static const noirDark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF0B0A0E),
    surface: Color(0xFF0B0A0E),
    surfaceHigh: Color(0xFF18151B),
    track: Color(0xFF241E28),
    border: Color(0xFF3A3040),
    text: Color(0xFFF6F1EC),
    textMuted: Color(0xFF948C97),
    accent: Color(0xFFFF9645),
    primary: Color(0xFFFF9645),
    onPrimary: Color(0xFF1B1118),
  );

  // ── Glass: frosted white over a soft gradient. Light only. ──────────────
  /// Glass on a light background. [bg] is only nominal — the page itself
  /// is the user's `GlassBackdrop`. [surface] and [surfaceHigh] are
  /// translucent; menus and pickers that float over content without a blur
  /// get `GlassTone.solidFrost` from the theme instead.
  static const glass = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFE9EEFB),
    surface: Color(0x66FFFFFF),
    surfaceHigh: Color(0x73FFFFFF),
    track: Color(0x14000000),
    border: Color(0xCCFFFFFF),
    // iOS's own label colours and system blue.
    text: Color(0xFF0A0A0F),
    textMuted: Color(0xFF65656D),
    accent: Color(0xFF007AFF),
    primary: Color(0xFF007AFF),
    onPrimary: Color(0xFFFFFFFF),
  );

  /// Glass on a dark background (Black, Ocean, Nebula): iOS's dark-mode
  /// label colours and system blue, over clear dark glass.
  static const glassDark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0x33FFFFFF),
    surfaceHigh: Color(0x1FFFFFFF),
    track: Color(0x33FFFFFF),
    border: Color(0x40FFFFFF),
    text: Color(0xFFF5F5F7),
    textMuted: Color(0xFF9C9CA3),
    accent: Color(0xFF0A84FF),
    primary: Color(0xFF0A84FF),
    onPrimary: Color(0xFFFFFFFF),
  );
}

/// Convenience so widgets can read semantic colours off the theme.
extension MoneyColors on ThemeData {
  Color get incomeColor => AppColors.income;
  Color get expenseColor => AppColors.expense;
  Color get transferColor => AppColors.transfer;

  /// The live accent for the palette in use.
  Color get accentColor => colorScheme.secondary;
}
