import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/snapshots.dart';

class WeightSnapshotPainter extends CustomPainter {
  const WeightSnapshotPainter({
    required this.snapshot,
    required this.neuronCount,
  });

  final SparseWeightSnapshot snapshot;
  final int neuronCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final nodePaint = Paint()..color = const Color(0xff333333);
    final edgePaint = Paint()..strokeWidth = 0.7;
    final samples = snapshot.weights.take(220);
    for (final sample in samples) {
      final source = _point(sample.source, center, radius);
      final target = _point(sample.target, center, radius);
      edgePaint.color = sample.inhibitory
          ? const Color(0x994d79a8)
          : const Color(0x99a84d4d);
      edgePaint.strokeWidth = sample.weight.abs().clamp(0.5, 3);
      canvas.drawLine(source, target, edgePaint);
    }
    for (var i = 0; i < neuronCount.clamp(0, 96); i += 1) {
      canvas.drawCircle(_point(i, center, radius), 2, nodePaint);
    }
  }

  Offset _point(int id, Offset center, double radius) {
    final count = neuronCount.clamp(1, 4096);
    final angle = (id / count) * math.pi * 2;
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  @override
  bool shouldRepaint(covariant WeightSnapshotPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.neuronCount != neuronCount;
}
