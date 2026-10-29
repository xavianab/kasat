import 'package:flutter/material.dart';

import '../../app.dart';
import '../../i18n/i18n.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/soft_badge.dart';
import '../more/more_scaffold.dart';

class LanguageView extends StatelessWidget {
  const LanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    return ListenableBuilder(
      listenable: i18n,
      builder: (context, _) => MoreScaffold(
        title: i18n.t('i18n.title'),
        children: [
          for (final lang in kAppLanguages)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: Material(
                color: lang.code == i18n.code ? KC.primarySoft : KC.surface,
                borderRadius: KRadius.rMd,
                child: InkWell(
                  borderRadius: KRadius.rMd,
                  onTap: () async {
                    final ok = await i18n.trySet(lang.code);
                    if (ok || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: KC.text,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(KSpace.lg),
                        shape: const RoundedRectangleBorder(borderRadius: KRadius.rMd),
                        content: Text(
                          i18n.t('i18n.toast', {
                            'name': lang.englishName,
                            'current': i18n.language.englishName,
                          }),
                          style: KType.sans(size: 14, color: Colors.white, height: 1.4),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lang.nativeName, style: KType.sans(size: 16, weight: FontWeight.w600)),
                              Text(lang.englishName, style: KType.sans(size: 12.5, color: KC.muted)),
                            ],
                          ),
                        ),
                        if (!lang.ready)
                          SoftBadge(i18n.t('i18n.comingSoon'), color: KC.secondary, dense: true)
                        else if (lang.code == i18n.code)
                          const Icon(Icons.check_rounded, color: KC.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
