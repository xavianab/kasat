import 'package:flutter/material.dart';

import '../models/incident_status.dart';
import '../theme/kasat_theme.dart';
import 'mono_badge.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.live = false});

  final IncidentStatus status;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3.5, 8, 3.5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.13),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            LiveDot(color: status.color, size: 5)
          else
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: KType.mono(
              size: 10,
              weight: FontWeight.w700,
              color: status.color,
              tracking: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal Received → Under Investigation → Resolved tracker.
class StatusTrack extends StatelessWidget {
  const StatusTrack(this.status, {super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = IncidentStatus.values;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: steps[i].step <= status.step ? status.color : KC.border,
              ),
            ),
          _Node(
            step: steps[i],
            reached: steps[i].step <= status.step,
            current: steps[i] == status,
          ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.step, required this.reached, required this.current});

  final IncidentStatus step;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = reached ? step.color : KC.faint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: current ? 11 : 8,
          height: current ? 11 : 8,
          decoration: BoxDecoration(
            color: reached ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          step.code.replaceAll('_', ' '),
          style: KType.mono(
            size: 8,
            weight: FontWeight.w700,
            color: color,
            tracking: 0.6,
          ),
        ),
      ],
    );
  }
}
