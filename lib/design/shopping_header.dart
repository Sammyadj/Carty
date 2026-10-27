import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'carty_design.dart';

class ShoppingHeader extends StatelessWidget {
  const ShoppingHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final design = CartyDesign.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final illustration =
              constraints.maxWidth >= 335 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.3;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: design.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            design.eyebrow,
                            style: TextStyle(
                              color: design.textSecondary,
                              fontSize: 9,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      design.headline,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: design.variant == DesignVariant.pantry
                                ? 30
                                : 32,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A little planning. A better shop.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (illustration) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: SizedBox(
                    width: 106,
                    height: 132,
                    child: CustomPaint(painter: _GroceryDrawing(design)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Original vector artwork; no remote images or retailer product claims.
class _GroceryDrawing extends CustomPainter {
  const _GroceryDrawing(this.design);
  final CartyDesign design;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 106, size.height / 132);
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      const Rect.fromLTWH(2, 10, 100, 114),
      fill..color = design.mint,
    );
    canvas.save();
    canvas.translate(53, 70);
    canvas.rotate(design.variant == DesignVariant.city ? -.12 : .12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-31, -18, 62, 69),
        const Radius.circular(8),
      ),
      fill..color = design.heroColor,
    );
    canvas.drawArc(
      const Rect.fromLTWH(-15, -32, 30, 40),
      math.pi,
      math.pi,
      false,
      stroke..color = design.primaryDark,
    );
    canvas.drawOval(
      const Rect.fromLTWH(-28, -43, 23, 34),
      fill..color = const Color(0xFF85AC5C),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-15, -48, 20, 39),
      fill..color = const Color(0xFF477B4C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, -40, 14, 40),
        const Radius.circular(7),
      ),
      fill..color = const Color(0xFFF1BD72),
    );
    canvas.drawLine(
      const Offset(9, -25),
      const Offset(17, -28),
      stroke..color = const Color(0xFFB77D39),
    );
    canvas.drawLine(const Offset(9, -15), const Offset(17, -18), stroke);
    canvas.drawCircle(
      const Offset(-15, -6),
      14,
      fill..color = const Color(0xFFEC876B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-31, 0, 62, 51),
        const Radius.circular(8),
      ),
      fill..color = design.heroColor,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-12, 25)
        ..lineTo(-3, 34)
        ..lineTo(15, 14),
      stroke
        ..color = design.heroAccent
        ..strokeWidth = 4,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(91, 22), 5, fill..color = design.heroAccent);
    canvas.drawLine(
      const Offset(9, 42),
      const Offset(15, 42),
      stroke
        ..color = design.primaryColor
        ..strokeWidth = 2,
    );
    canvas.drawLine(const Offset(12, 39), const Offset(12, 45), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GroceryDrawing oldDelegate) =>
      oldDelegate.design != design;
}
