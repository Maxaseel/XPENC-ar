import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../core/localization/app_text.dart';

/// Settings' front door — a menu of modules, each its own page. Splitting it
/// this way (instead of one long scrolling list of every toggle) keeps each
/// page short enough to scan and keeps this menu itself from growing every
/// time a new setting is added.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppTopBar(title: Text(ref.watch(localeProvider).languageCode == 'ar' ? 'الإعدادات' : 'Settings')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _ModuleTile(
            icon: Icons.tune_rounded,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'عام' : 'General',
            subtitle: ref.watch(localeProvider).languageCode == 'ar' ? 'العملة والمظهر والخط وتخطيط الرئيسية' : 'Currency, theme, font, dashboard layout',
            onTap: () => context.push('/more/settings/general'),
          ),
          _ModuleTile(
            icon: Icons.savings_outlined,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'النمط والميزانية' : 'Mode & Budgeting',
            subtitle: 'App mode, budget cycle, Ready to Assign',
            onTap: () => context.push('/more/settings/mode-budgeting'),
          ),
          _ModuleTile(
            icon: Icons.people_outline,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'الأشخاص' : 'Persons',
            subtitle: 'Repayments and your payment methods',
            onTap: () => context.push('/more/settings/persons'),
          ),
          _ModuleTile(
            icon: Icons.security_outlined,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'الأمان والخصوصية' : 'Security & Privacy',
            subtitle: PlatformFeatures.screenshotBlocking
                ? 'PIN, recovery phrase, authenticator, screenshots'
                : 'PIN, recovery phrase, authenticator',
            onTap: () => context.push('/more/settings/security'),
          ),
          if (PlatformFeatures.permissionsScreen)
            _ModuleTile(
              icon: Icons.verified_user_outlined,
              title: ref.watch(localeProvider).languageCode == 'ar' ? 'الأذونات' : 'Permissions',
              subtitle: 'What XPENC can access — turn each on or off',
              onTap: () => context.push('/more/settings/permissions'),
            ),
          _ModuleTile(
            icon: Icons.notifications_outlined,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'الإشعارات' : 'Notifications',
            subtitle: PlatformFeatures.quickAddNotification
                ? 'Reminders and quick add from a notification'
                : 'Reminders',
            onTap: () => context.push('/more/settings/notifications'),
          ),
          _ModuleTile(
            icon: Icons.flash_on_outlined,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'إجراءات سريعة' : 'Quick Actions',
            subtitle: PlatformFeatures.homeWidgets
                ? 'Hold ➕ shortcuts, home screen widgets'
                : 'Hold ➕ shortcuts',
            onTap: () => context.push('/more/settings/quick-actions'),
          ),
          _ModuleTile(
            icon: Icons.storage_outlined,
            title: ref.watch(localeProvider).languageCode == 'ar' ? 'البيانات' : 'Data',
            subtitle: 'Recalculate balances, clear all data',
            onTap: () => context.push('/more/settings/data'),
          ),
          AppCard(
            child: AppListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const BrandMark(size: 34),
              title: const Text('${AppInfo.name} · ${AppInfo.version}'),
              subtitle: Text(
                'Developer, links and build info',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/about'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AppIcon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: AppIcon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
