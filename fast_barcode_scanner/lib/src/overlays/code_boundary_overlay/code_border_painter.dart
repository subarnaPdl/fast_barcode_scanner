import 'package:flutter/material.dart';

import '../../../fast_barcode_scanner.dart';
import '../../corner_point_utils.dart';

class CodeBorderPainter extends CustomPainter {
  final CodeBorderPaintBuilder? barcodePaintSelector;
  final TextStyle Function(Barcode)? barcodeValueStyle;

  CodeBorderPainter({
    required this.imageSize,
    required this.barcodes,
    this.barcodePaintSelector,
    this.barcodeValueStyle,
  });

  final Size imageSize;
  final List<Barcode> barcodes;

  static final _standardPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.red;

  void paintBarcode(Canvas canvas, Size size, Barcode barcode) {
    final path = Path();

    if (barcode.boundingBox != null) {
      final corners = [
        barcode.boundingBox!.topLeft,
        barcode.boundingBox!.bottomRight
      ];

      final offsets = corners
          .map((e) => scaleCodeCornerPoint(
                cornerPoint: Offset(e.x.toDouble(), e.y.toDouble()),
                analysisImageSize: imageSize,
                widgetSize: size,
              ))
          .toList();

      path.moveTo(offsets[0].dx, offsets[0].dy);

      double minX = -1, maxX = -1, minY = -1, maxY = -1;

      for (var offset in offsets) {
        if (minX == -1 || offset.dx < minX) {
          minX = offset.dx;
        }
        if (maxX == -1 || offset.dx > maxX) {
          maxX = offset.dx;
        }
        if (minY == -1 || offset.dy < minY) {
          minY = offset.dy;
        }
        if (maxY == -1 || offset.dy > maxY) {
          maxY = offset.dy;
        }
        path.lineTo(offset.dx, offset.dy);
      }

      path.close();

      final barcodePaint =
          barcodePaintSelector?.call(barcode) ?? _standardPaint;

      canvas.drawPath(path, barcodePaint);

      if (barcodeValueStyle == null) return;

      final TextPainter tp = TextPainter(
        text: TextSpan(text: barcode.value, style: barcodeValueStyle!(barcode)),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );

      tp.layout();

      final centerX = minX + ((maxX - minX) / 2);
      final textPositionX = centerX - (tp.width / 2);
      final textPositionY = maxY + 5;

      tp.paint(canvas, Offset(textPositionX, textPositionY));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (Barcode barcode in barcodes) {
      paintBarcode(canvas, size, barcode);
    }
  }

  @override
  bool shouldRepaint(CodeBorderPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
