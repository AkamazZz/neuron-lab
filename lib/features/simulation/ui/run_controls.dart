import 'package:flutter/material.dart';

import '../controller/run_state.dart';

class RunControls extends StatelessWidget {
  const RunControls({
    super.key,
    required this.runState,
    required this.onRun,
    required this.onPause,
    required this.onStep,
    required this.onReset,
    required this.onRerun,
    required this.stepsPerTick,
    required this.onSpeedChanged,
  });

  final RunState runState;
  final VoidCallback onRun;
  final VoidCallback onPause;
  final VoidCallback onStep;
  final VoidCallback onReset;
  final VoidCallback onRerun;
  final int stepsPerTick;
  final ValueChanged<int> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final running = runState == RunState.running;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: running ? null : onRun,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run'),
        ),
        IconButton.filledTonal(
          tooltip: 'Pause',
          onPressed: running ? onPause : null,
          icon: const Icon(Icons.pause),
        ),
        IconButton.filledTonal(
          tooltip: 'Step',
          onPressed: running ? null : onStep,
          icon: const Icon(Icons.skip_next),
        ),
        IconButton.filledTonal(
          tooltip: 'Reset',
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt),
        ),
        IconButton.filledTonal(
          tooltip: 'Rerun same seed',
          onPressed: onRerun,
          icon: const Icon(Icons.replay),
        ),
        SizedBox(
          width: 180,
          child: Row(
            children: [
              const Icon(Icons.speed, size: 20),
              Expanded(
                child: Slider(
                  value: stepsPerTick.toDouble(),
                  min: 1,
                  max: 24,
                  divisions: 23,
                  label: '${stepsPerTick}x',
                  onChanged: (value) => onSpeedChanged(value.round()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
