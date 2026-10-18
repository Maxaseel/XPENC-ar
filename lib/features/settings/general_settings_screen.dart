import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_features.dart';
import '../../core/localization/app_language_store.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import 'more_screen_layout_sheet.dart';
import 'settings_common.dart';
import 'theme_picker_sheet.dart';
import '../../core/localization/app_text.dart';

/// General — currency, theme, font and layout. The settings that shape how
/// XPENC looks and reads, independent of app mode or any one feature.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final cs = theme.colorScheme;
    final trailingStyle = settingsTrailingStyle(context);

    final themeChoice = ref.watch(themeChoiceProvider);
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    final moreScreenViewMode = ref.watch(moreScreenViewModeProvider);
    final showCalendarDayTotals = ref.watch(showCalendarDayTotalsProvider);

    return Scaffold(
      appBar: AppTopBar(title: Text(isArabic ? 'عام' : 'General')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.language_rounded),
                  title: Text(isArabic ? 'لغة التطبيق' : 'App language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isArabic ? 'العربية' : 'English', style: trailingStyle),
                      const SizedBox(width: 4),
                      AppIcon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    ],
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(
                          title: const Text('English'),
                          onTap: () {
                            const locale = Locale('en');
                            ref.read(localeProvider.notifier).state = locale;
                            unawaited(AppLanguageStore().saveLocale(locale));
                            Navigator.pop(sheetContext);
                          },
                        ),
                        ListTile(
                          title: const Text('العربية'),
                          onTap: () {
                            const locale = Locale('ar');
                            ref.read(localeProvider.notifier).state = locale;
                            unawaited(AppLanguageStore().saveLocale(locale));
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.payments_outlined),
                  title: Text(isArabic ? 'العملة' : 'Currency'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currency.symbol} ${currency.code}',
                        style: trailingStyle,
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => context.push('/more/settings/currency'),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppSwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const AppIcon(Icons.attach_money_rounded),
                  title: Text(isArabic ? 'إظهار رمز العملة' : 'Show currency symbol'),
                  subtitle: Text(
                    showSymbol
                        ? 'Amounts show ${currency.symbol}'
                        : 'Amounts show plain numbers — use this if your '
                              'currency symbol is missing',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: showSymbol,
                  onChanged: (v) =>
                      ref.read(dbProvider).setShowCurrencySymbol(v),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: AppIcon(themeChoice.style.icon),
                  title: Text(isArabic ? 'المظهر' : 'Theme'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(themeChoice.style.label, style: trailingStyle),
                      const SizedBox(width: 4),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => ThemePickerSheet.show(context),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.text_fields_rounded),
                  title: Text(isArabic ? 'الخط' : 'Font'),
                  subtitle: Text(
                    'Text size, boldness and font family',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: AppIcon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push('/more/settings/font'),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.dashboard_outlined),
                  title: Text(isArabic ? 'تخطيط شاشة المزيد' : 'More screen layout'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MoreScreenLayoutSheet.label(moreScreenViewMode),
                        style: trailingStyle,
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => MoreScreenLayoutSheet.show(context),
                ),
              ],
            ),
          ),

          settingsSectionLabel(context, isArabic ? 'الرئيسية' : 'Dashboard'),
          AppCard(
            child: AppListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const AppIcon(Icons.dashboard_customize_outlined),
              title: Text(isArabic ? 'تخصيص الرئيسية' : 'Customize dashboard'),
              subtitle: Text(
                'Add, remove and reorder widgets, and pick what counts toward '
                'Net Worth.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/settings/dashboard'),
            ),
          ),

          settingsSectionLabel(context, isArabic ? 'التقويم' : 'Calendar'),
          AppCard(
            child: AppSwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const AppIcon(Icons.calendar_month_outlined),
              title: Text(isArabic ? 'إظهار إجمالي اليوم' : 'Show day totals'),
              subtitle: Text(
                'Selecting a day on the calendar shows its money in/out '
                'totals.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: showCalendarDayTotals,
              onChanged: (v) =>
                  ref.read(dbProvider).setShowCalendarDayTotals(v),
            ),
          ),

          settingsSectionLabel(context, isArabic ? 'التخطيط' : 'Layout'),
          AppCard(
            child: AppListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const AppIcon(Icons.dashboard_customize_outlined),
              title: Text(isArabic ? 'تخصيص شريط التنقل' : 'Customize bottom nav'),
              subtitle: Text(
                'Choose what goes next to the ➕ button',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/bottom-nav'),
            ),
          ),

          settingsSectionLabel(context, isArabic ? 'التقاط الرسائل' : 'Message Capture'),
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.sms_outlined),
                  title: Text(isArabic ? 'التقاط رسائل البنك' : 'Bank-SMS auto-capture'),
                  subtitle: Text(
                    'Coming soon — removed for now so the app installs '
                    'without a Play Protect block.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const AppIcon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/more/capture'),
                ),
                if (PlatformFeatures.ocr) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const AppIcon(Icons.rate_review_outlined),
                    title: const Text('OCR corrections'),
                    subtitle: Text(
                      'Optional — test a payment screenshot and help improve '
                      'OCR by sharing what you find, entirely on your terms.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/more/capture/ocr-feedback'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
