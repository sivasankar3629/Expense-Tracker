import 'package:flutter/material.dart';

import 'currency_scope.dart';
import 'kipto_art.dart';

/// This month's real spending, framed by the soft wave from Kipto's visual theme.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.period,
    required this.total,
    required this.count,
    required this.todayTotal,
  });

  final String period;
  final double total;
  final int count;
  final double todayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final showArt = constraints.maxWidth >= 340 &&
          MediaQuery.textScalerOf(context).scale(16) <= 20;
      return PhysicalShape(
        clipper: const _SummaryShape(),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF285C46),
        shadowColor: const Color(0x30285C46),
        elevation: 4,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF24664A), Color(0xFF357E51), Color(0xFF14513C)],
              stops: [0, 0.4, 1],
            ),
          ),
          child: Stack(
            children: [
              if (showArt)
                const Positioned(
                  right: 4,
                  top: 14,
                  child: IgnorePointer(child: KiptoArt.wallet(size: 112)),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SummaryWave(
                      // A pale wave on the light page; a deep one in dark mode,
                      // where a pale band would glare.
                      theme.brightness == Brightness.dark
                          ? const Color(0xFF2B4A37)
                          : const Color(0xFFDEEDD2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: showArt ? 108 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spent $period',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFE1EED8), fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.formatAmount(total),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: const Color(0xFFFFFEF7), fontSize: 40,
                              fontWeight: FontWeight.w800, letterSpacing: -1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          count == 1 ? '1 expense' : '$count expenses',
                          icon: Icons.receipt_long_rounded,
                        ),
                        _Pill(
                          'Today ${context.formatAmount(todayTotal)}',
                          icon: Icons.today_rounded,
                          light: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.icon, this.light = false});

  final String text;
  final IconData icon;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? const Color(0xFF1E523B) : const Color(0xFFFFFEF7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFDDEEC9) : const Color(0xFF1B583F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: foreground)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground, fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryShape extends CustomClipper<Path> {
  const _SummaryShape();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 32)
      ..quadraticBezierTo(0, 2, 32, 2)
      ..cubicTo(w * 0.4, -4, w * 0.53, 24, w * 0.72, 9)
      ..cubicTo(w * 0.88, -4, w, -9, w, 32)
      ..lineTo(w, h - 20)
      ..cubicTo(w * 0.75, h - 39, w * 0.58, h + 2, w * 0.37, h - 10)
      ..cubicTo(w * 0.2, h - 20, w * 0.11, h - 24, 0, h - 10)
      ..close();
  }

  @override
  bool shouldReclip(_SummaryShape oldClipper) => false;
}

class _SummaryWave extends CustomPainter {
  const _SummaryWave(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height - 19)
      ..cubicTo(size.width * 0.3, size.height - 42, size.width * 0.5,
          size.height + 4, size.width, size.height - 29)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SummaryWave oldDelegate) => color != oldDelegate.color;
}
