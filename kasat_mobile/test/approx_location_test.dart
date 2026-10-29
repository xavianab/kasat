import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/models/approx_location.dart';

void main() {
  group('ApproxLocation.snapped', () {
    test('degrades an exact coordinate', () {
      final snapped = ApproxLocation.snapped(
        latitude: -6.792354,
        longitude: 39.208328,
        precision: LocationPrecision.city,
      );

      expect(snapped.latitude, isNot(-6.792354));
      expect(snapped.longitude, isNot(39.208328));
    });

    test('maps points inside one cell onto the same coordinate', () {
      // Anchor on a snapped point so the perturbations are measured from the
      // cell centre rather than from an arbitrary spot that might sit on a
      // cell edge.
      const precision = LocationPrecision.district;
      final centre = ApproxLocation.snapped(
        latitude: 51.5,
        longitude: -0.124,
        precision: precision,
      );

      // ~110 m in each axis, comfortably inside a 2 km cell.
      final nearby = ApproxLocation.snapped(
        latitude: centre.latitude + 0.001,
        longitude: centre.longitude - 0.001,
        precision: precision,
      );

      expect(nearby.latitude, centre.latitude);
      expect(nearby.longitude, centre.longitude);
    });

    test('latitude error stays within the chosen cell size', () {
      const trueLat = 12.345678;
      const trueLng = 98.765432;

      for (final precision in LocationPrecision.values) {
        final snapped = ApproxLocation.snapped(
          latitude: trueLat,
          longitude: trueLng,
          precision: precision,
        );
        final error = (snapped.latitude - trueLat).abs();
        expect(
          error,
          lessThanOrEqualTo(precision.km / 111.32),
          reason: '${precision.code} overshot its own cell',
        );
      }
    });

    test('keeps a longitude cell the same real-world width near the pole', () {
      final equator = ApproxLocation.snapped(
        latitude: 0,
        longitude: 10.04,
        precision: LocationPrecision.city,
      );
      final arctic = ApproxLocation.snapped(
        latitude: 70,
        longitude: 10.04,
        precision: LocationPrecision.city,
      );

      final equatorError = (equator.longitude - 10.04).abs();
      final arcticError = (arctic.longitude - 10.04).abs();
      expect(arcticError, greaterThan(equatorError));
    });

    test('never prints more precision than it actually has', () {
      String labelAt(LocationPrecision precision) => ApproxLocation.snapped(
            latitude: -6.792354,
            longitude: 39.208328,
            precision: precision,
          ).coordinateLabel;

      expect(labelAt(LocationPrecision.block).split('°').first.split('.').last.length, 3);
      expect(labelAt(LocationPrecision.district).split('°').first.split('.').last.length, 2);
      expect(labelAt(LocationPrecision.region).split('°').first.split('.').last.length, 1);
    });

    test('drops a blank landmark rather than storing an empty string', () {
      final snapped = ApproxLocation.snapped(
        latitude: 1,
        longitude: 1,
        precision: LocationPrecision.block,
        note: '   ',
      );
      expect(snapped.note, isNull);
    });

    test('round-trips through JSON', () {
      final original = ApproxLocation.snapped(
        latitude: -33.86,
        longitude: 151.20,
        precision: LocationPrecision.region,
        note: 'near the ferry terminal',
      );
      final restored = ApproxLocation.fromJson(original.toJson());

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.precision, original.precision);
      expect(restored.note, original.note);
    });
  });
}
