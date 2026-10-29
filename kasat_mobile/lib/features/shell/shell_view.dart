import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/kasat_theme.dart';
import '../alerts/alerts_view.dart';
import '../lookup/lookup_view.dart';
import '../more/more_menu.dart';
import '../report/report_form_view.dart';
import '../resources/resources_view.dart';
import '../vent/vent_feed_view.dart';

enum ShellTab {
  report(label: 'Report', icon: Icons.edit_outlined),
  track(label: 'My case', icon: Icons.schedule_outlined),
  resources(label: 'Hotlines & support', icon: Icons.favorite_outline_rounded),
  alerts(label: 'Notices', icon: Icons.campaign_outlined),
  vent(label: 'Vent', icon: Icons.chat_bubble_outline_rounded);

  const ShellTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class ShellView extends StatefulWidget {
  const ShellView({super.key, this.initialTab = ShellTab.report});

  final ShellTab initialTab;

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  late ShellTab _tab = widget.initialTab;
  final _lookupKey = GlobalKey<LookupViewState>();

  /// Sends the survivor to the tracking tab with a code pre-loaded — used
  /// straight after submission so the receipt has somewhere to go.
  void openTracking(String trackingId) {
    setState(() => _tab = ShellTab.track);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lookupKey.currentState?.loadTrackingId(trackingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(title: _tab.label),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  ReportFormView(onTrackRequested: openTracking),
                  LookupView(key: _lookupKey),
                  const ResourcesView(),
                  const AlertsView(),
                  const VentFeedView(embedded: true),
                ],
              ),
            ),
            _TabBar(
              current: _tab,
              onChanged: (t) {
                HapticFeedback.selectionClick();
                setState(() => _tab = t);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: KC.muted,
          ),
          const SizedBox(width: KSpace.xs),
          Text(title, style: KType.serif(size: 19)),
          const Spacer(),
          IconButton(
            key: MoreMenu.buttonKey,
            onPressed: () => MoreMenu.open(context),
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: KC.muted,
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
      decoration: const BoxDecoration(
        color: KC.surface,
        border: Border(top: BorderSide(color: KC.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
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
    final shortLabel = tab == ShellTab.resources ? 'Hotlines' : tab.label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? KC.primarySoft : Colors.transparent,
              borderRadius: KRadius.rPill,
            ),
            child: Icon(tab.icon, size: 21, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            shortLabel,
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
