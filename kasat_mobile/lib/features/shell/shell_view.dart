import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_mark.dart';
import '../../widgets/soft_badge.dart';
import '../lookup/lookup_view.dart';
import '../more/more_menu.dart';
import '../report/report_form_view.dart';
import '../resources/resources_view.dart';
import '../welcome/welcome_view.dart';

enum ShellTab {
  home(label: 'Home', icon: Icons.home_outlined),
  report(label: 'Report', icon: Icons.edit_outlined),
  track(label: 'My case', icon: Icons.schedule_outlined),
  resources(label: 'Hotlines', icon: Icons.favorite_outline_rounded);

  const ShellTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class ShellView extends StatefulWidget {
  const ShellView({
    super.key,
    this.initialTab = ShellTab.home,
    this.offline = false,
  });

  final ShellTab initialTab;
  final bool offline;

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  late ShellTab _tab = widget.initialTab;
  final _lookupKey = GlobalKey<LookupViewState>();

  /// Sends the survivor to the tracking tab with a code pre-loaded right after
  /// submission so the receipt has somewhere to go.
  void openTracking(String trackingId) {
    setState(() => _tab = ShellTab.track);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lookupKey.currentState?.loadTrackingId(trackingId);
    });
  }

  void _selectTab(ShellTab tab) {
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canPop = Navigator.of(context).canPop();
    final showBack = canPop || _tab != ShellTab.home;

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: _tab == ShellTab.home ? null : _tab.label,
              showBack: showBack,
              onBack: () {
                if (canPop) {
                  Navigator.of(context).maybePop();
                } else {
                  setState(() => _tab = ShellTab.home);
                }
              },
            ),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  HomeTabContent(
                    offline: widget.offline,
                    onSelectTab: _selectTab,
                  ),
                  ReportFormView(onTrackRequested: openTracking),
                  LookupView(key: _lookupKey),
                  const ResourcesView(),
                ],
              ),
            ),
            if (!keyboardOpen)
              _TabBar(
                current: _tab,
                onChanged: _selectTab,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showBack,
    required this.onBack,
  });

  final String? title;
  final bool showBack;
  final VoidCallback onBack;

  Future<void> _toggleLanguage(BuildContext context) async {
    HapticFeedback.selectionClick();
    final i18n = KasatScope.of(context).i18n;
    final next = i18n.code == 'am' ? 'en' : 'am';
    await i18n.trySet(next);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 4),
      decoration: BoxDecoration(
        color: KC.canvas,
        border: Border(bottom: BorderSide(color: KC.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: KC.muted),
            )
          else
            const SizedBox(width: KSpace.sm),
          const KasatMark(size: 24),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Text(
              title == null ? 'Kasat' : 'Kasat · $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KType.sans(size: 16, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: KSpace.xs),
          Flexible(
            child: GestureDetector(
              key: WelcomeView.languageToggleKey,
              onTap: () => _toggleLanguage(context),
              child: SoftBadge(
                i18n.t('welcome.langToggle'),
                icon: Icons.translate_rounded,
                color: KC.primary,
                size: 11,
                dense: true,
              ),
            ),
          ),
          IconButton(
            key: MoreMenu.buttonKey,
            onPressed: () => MoreMenu.open(context),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.menu_rounded, size: 22, color: KC.muted),
            tooltip: 'More',
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final ShellTab current;
  final ValueChanged<ShellTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KC.surface,
        border: Border(top: BorderSide(color: KC.border)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final tab in ShellTab.values)
                  Expanded(
                    child: _TabButton(
                      tab: tab,
                      selected: tab == current,
                      onTap: () => onChanged(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? KC.primary : KC.faint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? KC.primarySoft : Colors.transparent,
              borderRadius: KRadius.rMd,
            ),
            child: Icon(tab.icon, size: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KType.sans(
              size: 11,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
