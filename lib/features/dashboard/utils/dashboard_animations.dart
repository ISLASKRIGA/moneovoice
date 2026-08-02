import 'package:flutter/material.dart';

/// AnimationController que aplica una curva personalizada al valor
/// devuelto, permitiendo efectos ultra-smooth en transiciones.
class CurvedAnimController extends AnimationController {
  final Curve curve;
  final Curve reverseCurve;

  CurvedAnimController({
    required super.vsync,
    required super.duration,
    super.reverseDuration,
    this.curve = Curves.easeOutCubic,
    this.reverseCurve = Curves.easeInCubic,
  });

  @override
  double get value {
    final raw = super.value;
    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
      return reverseCurve.transform(raw);
    }
    return curve.transform(raw);
  }
}
