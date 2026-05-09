import 'package:flutter/material.dart';

class NeuronGridEditor extends StatelessWidget {
  const NeuronGridEditor({
    super.key,
    required this.activeCells,
    required this.onToggle,
    this.neuronCount = 64,
  });

  final Set<int> activeCells;
  final ValueChanged<int> onToggle;
  final int neuronCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: neuronCount,
      itemBuilder: (context, index) {
        final active = activeCells.contains(index);
        return Tooltip(
          message: 'Neuron $index',
          child: InkWell(
            onTap: () => onToggle(index),
            borderRadius: BorderRadius.circular(4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active ? colorScheme.primary : colorScheme.surface,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }
}
