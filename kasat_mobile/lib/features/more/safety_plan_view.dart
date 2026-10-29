import 'package:flutter/material.dart';

import '../../data/safety_plan_store.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import 'more_scaffold.dart';

/// On-device checklist. Standard in tools like Bright Sky — and isolated
/// from reports so a case file never carries a home address or a friend's
/// name the person wrote for themselves.
class SafetyPlanView extends StatefulWidget {
  const SafetyPlanView({super.key, this.store});

  final SafetyPlanStore? store;

  @override
  State<SafetyPlanView> createState() => _SafetyPlanViewState();
}

class _SafetyPlanViewState extends State<SafetyPlanView> {
  late final SafetyPlanStore _store = widget.store ?? SafetyPlanStore();
  final _place = TextEditingController();
  final _person = TextEditingController();
  SafetyPlan _plan = const SafetyPlan();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _place.dispose();
    _person.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _store.init();
    if (!mounted) return;
    final plan = _store.read();
    _place.text = plan.safePlace;
    _person.text = plan.trustedPerson;
    setState(() {
      _plan = plan;
      _ready = true;
    });
  }

  Future<void> _persist(SafetyPlan plan) async {
    await _store.save(plan);
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _toggle(String id) async {
    await _store.toggle(id);
    if (mounted) setState(() => _plan = _store.read());
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KC.surface,
        shape: const RoundedRectangleBorder(borderRadius: KRadius.rLg),
        title: Text('Clear this plan?', style: KType.serif(size: 20)),
        content: Text(
          'Removes the ticks and the words you typed. It does not touch '
          'reports or your lock code.',
          style: KType.sans(size: 14, color: KC.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep it', style: KType.sans(color: KC.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: KType.sans(weight: FontWeight.w600, color: KC.secondary),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _store.clear();
    _place.clear();
    _person.clear();
    setState(() => _plan = const SafetyPlan());
  }

  @override
  Widget build(BuildContext context) {
    return MoreScaffold(
      title: 'My safety plan',
      children: [
        Text(
          'Optional. Only you can see this, and it never goes with a report. '
          'Skip any line that does not fit.',
          style: KType.sans(size: 15, color: KC.muted, height: 1.55),
        ),
        const SizedBox(height: KSpace.xl),
        if (!_ready)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KSpace.xxl),
            child: Center(child: CircularProgressIndicator(color: KC.primary)),
          )
        else ...[
          KPanel(
            title: 'Things I have thought about',
            padding: const EdgeInsets.fromLTRB(
              KSpace.lg,
              0,
              KSpace.lg,
              KSpace.md,
            ),
            child: Column(
              children: [
                for (final prompt in SafetyPlanStore.prompts)
                  _PromptRow(
                    key: Key('safety-${prompt.id}'),
                    label: prompt.label,
                    checked: _plan.checked.contains(prompt.id),
                    onTap: () => _toggle(prompt.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.lg),
          const KFieldLabel('A place I can go', optional: true),
          KTextField(
            controller: _place,
            hint: 'Only if you want to write one',
            maxLines: 2,
            minLines: 1,
            maxLength: 80,
            onChanged: (value) => _persist(_plan.copyWith(safePlace: value)),
          ),
          const SizedBox(height: KSpace.lg),
          const KFieldLabel('Someone I can tell', optional: true),
          KTextField(
            controller: _person,
            hint: 'A first name is enough',
            maxLines: 1,
            maxLength: 40,
            onChanged: (value) =>
                _persist(_plan.copyWith(trustedPerson: value)),
          ),
          const SizedBox(height: KSpace.xl),
          const KNote(
            title: 'If this phone is not only yours',
            icon: Icons.info_outline_rounded,
            body:
                'Clear the plan before you hand the phone over. Words you '
                'type here can be read by anyone who unlocks Kasat.',
          ),
          if (!_plan.isEmpty) ...[
            const SizedBox(height: KSpace.lg),
            KButton(
              label: 'Clear this plan',
              kind: KButtonKind.soft,
              onPressed: _confirmClear,
            ),
          ],
        ],
      ],
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? KC.primary : KC.surfaceAlt,
                border: Border.all(
                  color: checked ? KC.primary : KC.borderStrong,
                  width: 1.4,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Text(label, style: KType.sans(size: 14, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
