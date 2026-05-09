import 'package:flutter/material.dart';

class PatternSaveControls extends StatelessWidget {
  const PatternSaveControls({
    super.key,
    required this.activeName,
    required this.onNameChanged,
    required this.onSave,
  });

  final String activeName;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: activeName,
            decoration: const InputDecoration(labelText: 'Save slot'),
            items: const [
              DropdownMenuItem(value: 'Pattern A', child: Text('Pattern A')),
              DropdownMenuItem(value: 'Pattern B', child: Text('Pattern B')),
              DropdownMenuItem(value: 'Pattern C', child: Text('Pattern C')),
            ],
            onChanged: (value) {
              if (value != null) {
                onNameChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Save pattern',
          onPressed: onSave,
          icon: const Icon(Icons.save),
        ),
      ],
    );
  }
}
