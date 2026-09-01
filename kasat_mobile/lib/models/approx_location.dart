import 'dart:math' as math;

/// How much the survivor's coordinate is deliberately degraded before it ever
/// leaves the handset.
enum LocationPrecision {
  block(code: 'BLOCK', label: 'Block', km: 0.5),
  district(code: 'DISTRICT', label: 'District', km: 2),
  city(code: 'CITY', label: 'City', km: 10),
  region(code: 'REGION', label: 'Region', km: 50);

  const LocationPrecision({
    required this.code,
    required this.label,
    required this.km,
  });

  final String code;
  final String label;
  final double km;

  String get radiusLabel => km < 1 ? '${(km * 1000).round()} m' : '${km.round()} km';

  static LocationPrecision fromCode(String code) {
    return LocationPrecision.values.firstWhere(
      (p) => p.code == code,
      orElse: () => LocationPrecision.district,
    );
  }
}

/// A coordinate that has already been snapped to a grid. Kasat never stores or
/// transmits the raw value the survivor typed — [ApproxLocation.snapped] is the
/// only constructor, so an exact fix cannot leak by accident.
class ApproxLocation {
  const ApproxLocation._({
    required this.latitude,
    required this.longitude,
    required this.precision,
    this.note,
  });

  /// Rounds [latitude]/[longitude] onto a grid whose cell size matches
  /// [precision], so every point inside the same cell reports one coordinate.
  factory ApproxLocation.snapped({
    required double latitude,
    required double longitude,
    required LocationPrecision precision,
    String? note,
  }) {
    const kmPerDegree = 111.32;
    final latStep = precision.km / kmPerDegree;
    final snappedLat = _snap(latitude, latStep);

    // A degree of longitude shrinks toward the poles, so widen the step to
    // keep the cell the same real-world size. The widening is derived from the
    // *snapped* latitude: deriving it from the raw value would give every
    // point its own slightly different longitude grid, which defeats the
    // point of snapping at all.
    final cosLat = math.cos(snappedLat * math.pi / 180).abs();
    final lngStep = latStep / math.max(cosLat, 0.01);

    return ApproxLocation._(
      latitude: snappedLat,
      longitude: _snap(longitude, lngStep),
      precision: precision,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    );
  }

  final double latitude;
  final double longitude;
  final LocationPrecision precision;

  /// Free-text landmark, e.g. "near the north bus terminal".
  final String? note;

  static double _snap(double value, double step) {
    return (value / step).roundToDouble() * step;
  }

  /// Decimal places are tied to [precision]: printing three decimals (~100 m)
  /// for a coordinate snapped to a 2 km grid would advertise an accuracy the
  /// value does not have.
  int get _displayDecimals {
    if (precision.km < 1) return 3;
    if (precision.km < 20) return 2;
    return 1;
  }

  String get coordinateLabel {
    final d = _displayDecimals;
    final lat = '${latitude.abs().toStringAsFixed(d)}°${latitude >= 0 ? 'N' : 'S'}';
    final lng = '${longitude.abs().toStringAsFixed(d)}°${longitude >= 0 ? 'E' : 'W'}';
    return '$lat $lng';
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'precision': precision.code,
        'note': note,
      };

  static ApproxLocation fromJson(Map<String, dynamic> json) {
    return ApproxLocation._(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      precision: LocationPrecision.fromCode(json['precision'] as String),
      note: json['note'] as String?,
    );
  }

  static bool isValidLatitude(double v) => v >= -90 && v <= 90;
  static bool isValidLongitude(double v) => v >= -180 && v <= 180;
}
