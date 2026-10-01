import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

/// Primary full-width button.
/// Same API as before. Primary = deep onyx, accent = amber.
/// No longer depends on GlossyDecoration.
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isAccent;
  final bool isLoading;
  final double width;
  final double height;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isAccent = false,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final LinearGradient gradient = isAccent
        ? const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [DT.amber600, DT.amber700],
    )
        : const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [DT.onyx800, DT.onyx900],
    );

    final bool disabled = isLoading;

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.75 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(DT.rMd + 2),
            boxShadow: DT.shadowXs,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(DT.rMd + 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              splashColor: Colors.white24,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  text,
                  style: DT.text(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
