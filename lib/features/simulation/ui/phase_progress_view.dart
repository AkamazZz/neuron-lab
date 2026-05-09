import 'package:flutter/material.dart';

import '../../../core/models/phase.dart';

class PhaseProgressView extends StatelessWidget {
  const PhaseProgressView({super.key, required this.progress});

  final PhaseProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(progress.label)),
            Text(
              '${(progress.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.progress.clamp(0, 1)),
      ],
    );
  }
}
