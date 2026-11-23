import 'package:flutter/material.dart';

/// Shared dimensions for the desktop workspace and touch interfaces.
class AppDensity {
  const AppDensity(this.platform);
  final TargetPlatform platform;

  static AppDensity of(BuildContext context) =>
      AppDensity(Theme.of(context).platform);

  bool get desktop =>
      platform != TargetPlatform.android && platform != TargetPlatform.iOS;
  double get control => desktop ? 40 : 48;
  double get icon => desktop ? 20 : 22;
  double get radius => desktop ? 8 : 12;
  double get body => desktop ? 12 : 13;
  double get pageInset => desktop ? 14 : 16;
  double get pageTop => desktop ? 24 : 18;
  double get panelInset => desktop ? 12 : 16;
  double get trackExtent => desktop ? 52 : 84;
  double get artwork => desktop ? 32 : 44;
}
