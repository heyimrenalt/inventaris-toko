import 'package:flutter/material.dart';

/// Shape and elevation tokens. Shadows are deliberately soft/low — no heavy
/// drop shadows anywhere except the elevated search bar, which is a
/// specific user request to make it "pop" off the header.
abstract final class AppDimensions {
  static const cardRadius = 16.0;
  static const buttonRadius = 14.0;
  static const badgeRadius = 8.0;
  static const pillRadius = 20.0;
  static const inputRadius = 12.0;

  /// Matches the mockup's `.stk` stock-number chip, which uses a radius
  /// between [badgeRadius] and [inputRadius].
  static const stockBadgeRadius = 10.0;

  // Icon sizes — Material standard scale.
  static const iconXs = 16.0;
  static const iconSm = 18.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const iconXl = 32.0;

  static const cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const elevatedSearchShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 4)),
  ];
}
