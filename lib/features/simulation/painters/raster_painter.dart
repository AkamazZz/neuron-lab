import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/step_frame.dart';

class RasterPainter extends CustomPainter {
  const RasterPainter({required this.events, required this.neuronCount});

  final List<SpikeEvent> events;
  final int neuronCount;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i += 1) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (events.isEmpty || neuronCount <= 0) {
      return;
    }
    final minStep = events.first.absoluteStep;
    final maxStep = events.last.absoluteStep;
    final span = (maxStep - minStep).clamp(1, 1 << 31);
    final dot = Paint()..color = const Color(0xff235d5f);
    for (final event in events) {
      final x = ((event.absoluteStep - minStep) / span) * size.width;
      final y = (event.neuronId / neuronCount) * size.height;
      canvas.drawCircle(Offset(x, y.clamp(0, size.height)), 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant RasterPainter oldDelegate) =>
      oldDelegate.events != events || oldDelegate.neuronCount != neuronCount;
}
