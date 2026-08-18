import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays the Toko Mama logo (SVG). Use this instead of hardcoding
/// `SvgPicture.asset` paths throughout the app.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/logo.svg',
      width: size,
      height: size,
      semanticsLabel: 'Toko Mama logo',
    );
  }
}
