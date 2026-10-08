import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

/// Brand logo.
/// - [useImage] = true  -> tries the PNG asset first, falls back to the text logo.
/// - [useImage] = false -> always renders the text logo (gradient mark + wordmark).
class LogoWidget extends StatelessWidget {
  final double size;
  final bool showSubtitle;
  final bool useImage;

  const LogoWidget({
    super.key,
    this.size = 36,
    this.showSubtitle = true,
    this.useImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useImage) {
      return Image.asset(
        'lib/assets/images/qnx_mart_logo.png',
        width: size * 2.5,
        height: size * 0.9,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildTextLogo(),
      );
    }
    return _buildTextLogo();
  }

  Widget _buildTextLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gradient brand mark
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: DT.logoGradient,
            borderRadius: BorderRadius.circular(size * 0.33),
            boxShadow: DT.shadowXs,
          ),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Q',
                  style: DT.text(
                    size: size * 0.46,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(
                  text: 'N',
                  style: DT.text(
                    size: size * 0.46,
                    weight: FontWeight.w800,
                    color: DT.amber300,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Wordmark
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'QN',
                    style: DT.text(
                      size: size * 0.44,
                      weight: FontWeight.w800,
                      color: DT.onyx900,
                      height: 1,
                      letterSpacing: -0.4,
                    ),
                  ),
                  TextSpan(
                    text: 'MART',
                    style: DT.text(
                      size: size * 0.44,
                      weight: FontWeight.w800,
                      color: DT.blue700,
                      height: 1,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 2),
              Text(
                'B2B Wholesale Hub',
                style: DT.text(
                  size: 9,
                  weight: FontWeight.w600,
                  color: DT.onyx600,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
