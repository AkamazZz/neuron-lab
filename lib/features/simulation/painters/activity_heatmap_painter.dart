import 'package:flutter/material.dart';

import '../../../core/models/snapshots.dart';

class ActivityHeatmapPainter extends CustomPainter {
  const ActivityHeatmapPainter({required this.snapshot});

  final ActivitySnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final values = snapshot.recentFiringRates.isNotEmpty
        ? snapshot.recentFiringRates
        : snapshot.membranes;
    if (values.isEmpty) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x11000000),
      );
      return;
    }
    final columns = values.length <= 8 ? values.length : 8;
    final rows = (values.length / columns).ceil();
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    for (var i = 0; i < values.length; i += 1) {
      final value = values[i].clamp(0, 1).toDouble();
      final color = Color.lerp(
        const Color(0xffe9e1d0),
        const Color(0xff235d5f),
        value,
      )!;
      final row = i ~/ columns;
      final column = i % columns;
      canvas.drawRect(
        Rect.fromLTWH(
          column * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ActivityHeatmapPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot;
}
