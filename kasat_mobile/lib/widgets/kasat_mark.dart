import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Kasat flower mark. The SVG has no background, so the mark stays transparent.
class KasatMark extends StatelessWidget {
  const KasatMark({super.key, this.size = 24});

  final double size;

  static const asset = 'assets/brand/kasat-bloom.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
