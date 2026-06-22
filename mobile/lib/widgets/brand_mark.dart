import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Inline rendition of the brand "j" mark — ink-navy circle, paper-colored
/// serif "j", small accent tittle in the palette's amber/coral.
///
/// Used in app bars and avatars to keep the wordmark consistent without
/// shipping a vector asset for every size.
class JBrandMark extends StatelessWidget {
  final double size;
  const JBrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final double letterSize = size * 0.6;
    final double dotSize = size * 0.08;
    final double dotTop = size * 0.16;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: JuneColors.inkNavy,
              shape: BoxShape.circle,
            ),
          ),
          // Center the "j" optically with a slight upward lift to compensate
          // for the descender.
          Positioned(
            top: size * 0.15,
            child: Text(
              'j',
              style: GoogleFonts.lora(
                fontSize: letterSize,
                fontWeight: FontWeight.w500,
                color: JuneColors.paper,
                height: 1.0,
              ),
            ),
          ),
          // Amber tittle, sitting where Lora's natural dot would land.
          Positioned(
            top: dotTop,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: JuneColors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
