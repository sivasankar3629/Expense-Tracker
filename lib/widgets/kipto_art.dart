import 'package:flutter/material.dart';

/// Decorative local artwork: no network requests or extra semantics stops.
class KiptoArt extends StatelessWidget {
  const KiptoArt.wallet({super.key, this.size = 112}) : asset = 'wallet';
  const KiptoArt.receipt({super.key, this.size = 88}) : asset = 'receipt';

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/art/$asset.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
