import 'package:flutter/material.dart';

/// Quiet botanical decoration beneath the app's scrollable surfaces.
class KiptoBackdrop extends StatelessWidget {
  const KiptoBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _Leaves(Theme.of(context).brightness == Brightness.dark),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Leaves extends CustomPainter {
  const _Leaves(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final left in [true, false]) {
      canvas.save();
      canvas.translate(left ? 0 : size.width, size.height);
      canvas.scale(left ? 1 : -1, 1);
      for (final (x, y, angle, height) in [
        (7.0, 4.0, -0.45, 103.0),
        (16.0, 12.0, 0.3, 124.0),
        (11.0, 0.0, 0.85, 77.0),
        (7.0, -34.0, -0.6, 81.0),
      ]) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(31, -height * 0.55, 0, -height)
          ..quadraticBezierTo(-18, -height * 0.4, 0, 0);
        paint.color = (angle > 0 ? const Color(0xFF8CB270) : const Color(0xFF337A55))
            .withValues(alpha: dark ? 0.12 : 0.22);
        canvas.drawPath(leaf, paint);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Leaves oldDelegate) => dark != oldDelegate.dark;
}
