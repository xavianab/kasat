import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/approx_location.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/k_field.dart';
import '../../../widgets/mono_badge.dart';

/// Coordinate entry that never accepts an exact fix.
///
/// The survivor types (or pastes) a coordinate, picks how coarse it should be,
/// and sees the snapped result before submitting. There is no "use my current
/// location" button on purpose: a GPS fix taken at the moment of reporting is
/// often the single most identifying field in a report.
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
                    hint: '-6.7924',
                    mono: true,
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
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KFieldLabel('Longitude'),
                  KTextField(
                    controller: lngController,
                    hint: '39.2083',
                    mono: true,
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
        const SizedBox(height: KSpace.md),
        const KFieldLabel('Reported precision'),
        KSegmented<LocationPrecision>(
          options: LocationPrecision.values,
          value: precision,
          labelOf: (p) => p.label,
          onChanged: onPrecisionChanged,
        ),
        const SizedBox(height: KSpace.md),
        const KFieldLabel('Landmark (optional)'),
        KTextField(
          controller: noteController,
          hint: 'e.g. near the north bus terminal',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: KSpace.md),
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
    return Container(
      decoration: BoxDecoration(
        color: KC.canvas,
        border: Border.all(color: resolved == null ? KC.border : KC.accentDeep),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 92,
            width: double.infinity,
            child: CustomPaint(painter: _CellPainter(active: resolved != null)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.sm, vertical: 7),
            decoration: const BoxDecoration(
              color: KC.surfaceHi,
              border: Border(top: BorderSide(color: KC.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    switch ((resolved, dirty)) {
                      (final ApproxLocation l, _) => l.coordinateLabel,
                      (null, true) => 'AWAITING VALID COORDINATE',
                      (null, false) => 'NO LOCATION ATTACHED',
                    },
                    style: KType.mono(
                      size: 11,
                      weight: FontWeight.w700,
                      color: resolved == null ? KC.faint : KC.accent,
                    ),
                  ),
                ),
                MonoBadge(
                  '±${precision.radiusLabel}',
                  color: resolved == null ? KC.faint : KC.accent,
                  dense: true,
                  size: 9,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Abstract cell diagram: a grid with one highlighted square standing in for
/// the area the report will be filed against. It is not a map and does not
/// pretend to be — showing real tiles would mean a network call.
class _CellPainter extends CustomPainter {
  _CellPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 18.0;
    final grid = Paint()
      ..color = KC.border
      ..strokeWidth = 0.5;

    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (!active) return;

    final cx = (size.width / 2 / cell).floor() * cell;
    final cy = (size.height / 2 / cell).floor() * cell;
    final rect = Rect.fromLTWH(cx - cell, cy - cell, cell * 3, cell * 3);

    canvas.drawRect(rect, Paint()..color = KC.accent.withValues(alpha: 0.13));
    canvas.drawRect(
      rect,
      Paint()
        ..color = KC.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final center = rect.center;
    final cross = Paint()
      ..color = KC.accent
      ..strokeWidth = 1;
    canvas.drawLine(center.translate(-5, 0), center.translate(5, 0), cross);
    canvas.drawLine(center.translate(0, -5), center.translate(0, 5), cross);
  }

  @override
  bool shouldRepaint(_CellPainter old) => old.active != active;
}
