import 'package:flutter/material.dart';

class SpikeCountPainter extends CustomPainter {
  const SpikeCountPainter({required this.counts});

  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baseline,
    );
    if (counts.isEmpty) {
      return;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 20);
    final barWidth = size.width / counts.length;
    final paint = Paint()..color = const Color(0xff7a4e20);
    for (var i = 0; i < counts.length; i += 1) {
      final h = (counts[i] / maxCount) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth.clamp(1, 6), h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpikeCountPainter oldDelegate) =>
      oldDelegate.counts != counts;
}
