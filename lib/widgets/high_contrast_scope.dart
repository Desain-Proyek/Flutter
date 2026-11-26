import 'package:flutter/material.dart';

/// InheritedWidget providing the current "Mode Terik Matahari" (high-contrast) state.
class HighContrastScope extends InheritedWidget {
  final bool isHighContrast;

  const HighContrastScope({
    super.key,
    required this.isHighContrast,
    required super.child,
  });

  /// Returns whether high-contrast mode is currently enabled, defaulting to `false`
  /// if no [HighContrastScope] ancestor is present.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HighContrastScope>();
    return scope?.isHighContrast ?? false;
  }

  @override
  bool updateShouldNotify(HighContrastScope oldWidget) =>
      isHighContrast != oldWidget.isHighContrast;
}
