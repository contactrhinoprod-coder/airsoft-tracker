import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> createLabeledMarker(String name, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(140, 90);

  // Dessine le pin
  final paintPin = Paint()..color = color;
  canvas.drawCircle(const Offset(70, 30), 22, paintPin);
  canvas.drawPath(
    Path()
      ..moveTo(58, 48)
      ..lineTo(82, 48)
      ..lineTo(70, 66)
      ..close(),
    paintPin,
  );

  // Dessine le point blanc au centre du pin
  final paintCenter = Paint()..color = Colors.white;
  canvas.drawCircle(const Offset(70, 30), 9, paintCenter);

  // Dessine le nom en dessous
  final textPainter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1)),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, 68));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}
