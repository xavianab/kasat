import 'package:flutter/material.dart';

import '../models/incident_status.dart';
import '../theme/kasat_theme.dart';
import 'soft_badge.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.live = false});

  final IncidentStatus status;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.11),
        borderRadius: KRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            PulseDot(color: status.color, size: 7)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 7),
          Text(
            status.label,
            style: KType.sans(size: 12.5, weight: FontWeight.w600, color: status.color),
          ),
        ],
      ),
    );
  }
}

/// Received → Under Investigation → Resolved, as a soft stepper.
class StatusTrack extends StatelessWidget {
  const StatusTrack(this.status, {super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = IncidentStatus.values.where((s) => s.step >= 0).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 7, left: 4, right: 4),
                decoration: BoxDecoration(
                  color: steps[i].step <= status.step
                      ? status.color.withValues(alpha: 0.45)
                      : KC.border,
                  borderRadius: KRadius.rPill,
                ),
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
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Container
            (
            width: current ? 17 : 13,
            height: current ? 17 : 13,
            margin: EdgeInsets.only(top: current ? 0 : 2),
            decoration: BoxDecoration(
              color: reached ? color : KC.surface,
              border: Border.all(color: reached ? color : KC.borderStrong, width: 2),
              shape: BoxShape.circle,
            ),
            child: current
                ? const Icon(Icons.circle, size: 5, color: Colors.white)
                : null,
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            step.label,
            textAlign: TextAlign.center,
            style: KType.sans(
              size: 11,
              weight: current ? FontWeight.w700 : FontWeight.w500,
              color: reached ? color : KC.faint,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
