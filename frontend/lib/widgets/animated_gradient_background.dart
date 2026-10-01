import 'dart:math';
import 'package:flutter/material.dart';

/// Slowly rotating gradient background (navy -> teal palette by default).
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final bool isDark;
  final BorderRadius? borderRadius;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF0F1E36),
      Color(0xFF1E3A5F),
      Color(0xFF1E40AF),
      Color(0xFF115E59),
    ],
    this.duration = const Duration(seconds: 10),
    this.isDark = false,
    this.borderRadius,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller
        ..duration = widget.duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Evenly spaced stops for any number of colors (the old version
  /// hard-coded 4 stops and crashed with a different colour count).
  List<double> _stops(int count) {
    if (count < 2) return const [0.0, 1.0];
    return List.generate(count, (i) => i / (count - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors =
    widget.colors.length < 2 ? [...widget.colors, ...widget.colors] : widget.colors;
    final stops = _stops(colors.length);

    // Respect "reduce motion" accessibility setting.
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double t = reduceMotion ? 0 : _controller.value * 2 * pi;
        final gradient = LinearGradient(
          begin: Alignment(cos(t), sin(t)),
          end: Alignment(-cos(t), -sin(t)),
          colors: colors,
          stops: stops,
        );

        final Widget box = DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: child,
        );

        return widget.borderRadius == null
            ? box
            : ClipRRect(borderRadius: widget.borderRadius!, child: box);
      },
    );
  }
}

/// Rounded animated gradient card. The radius now actually clips the gradient.
class AnimatedGradientContainer extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final double borderRadius;

  const AnimatedGradientContainer({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF0F1E36),
      Color(0xFF1E3A5F),
      Color(0xFF1E40AF),
      Color(0xFF115E59),
    ],
    this.duration = const Duration(seconds: 8),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      colors: colors,
      duration: duration,
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}
