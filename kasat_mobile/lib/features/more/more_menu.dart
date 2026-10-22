import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../theme/kasat_theme.dart';
import '../duress/duress_setup_view.dart';
import '../i18n/language_view.dart';
import '../settings/settings_view.dart';
import '../vent/vent_feed_view.dart';
import 'help_someone_view.dart';
import 'how_it_works_view.dart';
import 'privacy_view.dart';
import 'safety_plan_view.dart';

/// Optional tools that sit beside the main actions. Opening this must
/// never change report, tracking, help, or notices.
class MoreMenu {
  static const buttonKey = Key('more-menu');

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: KC.surface,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.lg)),
      ),
      builder: (context) => const MoreMenuSheet(),
    );
  }
}

class MoreMenuSheet extends StatelessWidget {
  const MoreMenuSheet({super.key});

  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpace.xl,
            KSpace.md,
            KSpace.xl,
            KSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KC.borderStrong,
                    borderRadius: KRadius.rPill,
                  ),
                ),
              ),
              const SizedBox(height: KSpace.lg),
              Text(i18n.t('more.title'), style: KType.serif(size: 22)),
              const SizedBox(height: 4),
              Text(
                i18n.t('more.blurb'),
                style: KType.sans(size: 13.5, color: KC.muted, height: 1.4),
              ),
              const SizedBox(height: KSpace.lg),
              _MoreRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: i18n.t('welcome.vent'),
                detail: i18n.t('vent.blurb'),
                onTap: () => _open(context, const VentFeedView()),
              ),
              _MoreRow(
                icon: Icons.route_outlined,
                title: i18n.t('more.how'),
                detail: i18n.t('more.howDetail'),
                onTap: () => _open(context, const HowItWorksView()),
              ),
              _MoreRow(
                icon: Icons.checklist_outlined,
                title: i18n.t('more.plan'),
                detail: i18n.t('more.planDetail'),
                onTap: () => _open(context, const SafetyPlanView()),
              ),
              _MoreRow(
                icon: Icons.diversity_1_outlined,
                title: i18n.t('more.helpSomeone'),
                detail: i18n.t('more.helpSomeoneDetail'),
                onTap: () => _open(context, const HelpSomeoneView()),
              ),
              _MoreRow(
                icon: Icons.visibility_off_outlined,
                title: i18n.t('more.privacy'),
                detail: i18n.t('more.privacyDetail'),
                onTap: () => _open(context, const PrivacyView()),
              ),
              _MoreRow(
                icon: Icons.translate_rounded,
                title: i18n.t('more.language'),
                detail: i18n.t('more.languageDetail'),
                onTap: () => _open(context, const LanguageView()),
              ),
              if (KasatConfig.enableShakeToSms)
                _MoreRow(
                  icon: Icons.vibration_rounded,
                  title: i18n.t('more.duress'),
                  detail: i18n.t('more.duressDetail'),
                  onTap: () => _open(context, const DuressSetupView()),
                ),
              _MoreRow(
                icon: Icons.tune_rounded,
                title: i18n.t('more.settings'),
                detail: i18n.t('more.settingsDetail'),
                onTap: () => _open(context, const SettingsView()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KRadius.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: KC.primarySoft,
                borderRadius: KRadius.rSm,
              ),
              child: Icon(icon, size: 20, color: KC.primary),
            ),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KType.sans(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KType.sans(
                      size: 12.5,
                      color: KC.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: KC.faint),
          ],
        ),
      ),
    );
  }
}
