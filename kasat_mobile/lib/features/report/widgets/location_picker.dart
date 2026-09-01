import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/approx_location.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/k_field.dart';
import '../../../widgets/soft_badge.dart';

/// Coordinate entry that never accepts an exact fix.
///
/// The survivor types (or pastes) a coordinate, chooses how vague it should be,
/// and sees the result before submitting. There is no "use my current location"
/// button on purpose: a GPS fix taken at the moment of reporting is often the
/// single most identifying field in a report.
class LocationPicker extends StatelessWidget {
  const LocationPicker({
    super.key,
    required this.latController,
    required this.lngController,
    required this.noteController,
    required this.precision,
    required this.onPrecisionChanged,
    required this.resolved,
    required this.onChanged,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController noteController;
  final LocationPrecision precision;
  final ValueChanged<LocationPrecision> onPrecisionChanged;

  /// Snapped output computed by the parent, or null while the inputs are
  /// empty or invalid.
  final ApproxLocation? resolved;
  final VoidCallback onChanged;

  static final _coordinateFormat = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
  ];

  @override
  Widget build(BuildContext context) {
    final hasInput = latController.text.isNotEmpty || lngController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KFieldLabel('Latitude'),
                  KTextField(
                    controller: latController,
                    hint: '9.0108',
                    code: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: _coordinateFormat,
                    onChanged: (_) => onChanged(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KFieldLabel('Longitude'),
                  KTextField(
                    controller: lngController,
                    hint: '38.7613',
                    code: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: _coordinateFormat,
                    onChanged: (_) => onChanged(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.lg),
        const KFieldLabel('How vague should this be?'),
        KSegmented<LocationPrecision>(
          options: LocationPrecision.values,
          value: precision,
          labelOf: (p) => p.label,
          onChanged: onPrecisionChanged,
        ),
        const SizedBox(height: KSpace.lg),
        const KFieldLabel('A nearby landmark', optional: true),
        KTextField(
          controller: noteController,
          hint: 'near the bus terminal',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: KSpace.lg),
        _SnapPreview(resolved: resolved, precision: precision, dirty: hasInput),
      ],
    );
  }
}

class _SnapPreview extends StatelessWidget {
  const _SnapPreview({
    required this.resolved,
    required this.precision,
    required this.dirty,
  });

  final ApproxLocation? resolved;
  final LocationPrecision precision;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final active = resolved != null;

    return Container(
      decoration: BoxDecoration(
        color: KC.surfaceAlt,
        borderRadius: KRadius.rMd,
        border: Border.all(color: active ? KC.primary : KC.border, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 104,
            width: double.infinity,
            child: CustomPaint(painter: _CellPainter(active: active)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: KSpace.md, vertical: KSpace.md),
            decoration: const BoxDecoration(
              color: KC.surface,
              border: Border(top: BorderSide(color: KC.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    switch ((resolved, dirty)) {
                      (final ApproxLocation l, _) => l.coordinateLabel,
                      (null, true) => 'Waiting for a valid coordinate',
                      (null, false) => 'No place attached',
                    },
                    style: active
                        ? KType.code(size: 14, color: KC.secondary)
                        : KType.sans(size: 13.5, color: KC.faint),
                  ),
                ),
                SoftBadge(
                  'within ${precision.radiusLabel}',
                  color: active ? KC.primary : KC.faint,
                  dense: true,
                  size: 11.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Abstract area diagram: a soft grid with one highlighted cell standing in for
/// the area the report will be filed against. It is not a map and does not
/// pretend to be — showing real tiles would mean a network call, which is
/// exactly what this screen is avoiding.
class _CellPainter extends CustomPainter {
  _CellPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 26.0;
    final grid = Paint()
      ..color = KC.border
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (!active) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: cell * 3, height: cell * 3),
      const Radius.circular(KRadius.sm),
    );

    canvas.drawRRect(rect, Paint()..color = KC.primary.withValues(alpha: 0.16));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = KC.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(center, 5, Paint()..color = KC.primary);
  }

  @override
  bool shouldRepaint(_CellPainter old) => old.active != active;
}
