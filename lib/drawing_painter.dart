import 'package:flutter/material.dart';
import 'colored_line.dart';

class DrawingPainter extends CustomPainter {
  final List<ColoredLine> lines;

  DrawingPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..style = line.strokeWidth > 0 ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = line.strokeWidth;

      if (line.strokeWidth > 0) {
        for (int i = 0; i < line.offsets.length - 1; i++) {
          canvas.drawLine(line.offsets[i], line.offsets[i + 1], paint);
        }
      } else {
        Path path = Path()..moveTo(line.offsets[0].dx, line.offsets[0].dy);
        for (var offset in line.offsets) {
          path.lineTo(offset.dx, offset.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return true;
  }
}
