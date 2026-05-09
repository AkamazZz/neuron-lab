import 'package:flutter/material.dart';

import '../controller/pattern_editor_state.dart';

class PatternPreview extends StatelessWidget {
  const PatternPreview({super.key, required this.state});

  final PatternEditorState state;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${state.activeCells.length} active cells, strength '
      '${state.strength.toStringAsFixed(2)}, noise '
      '${(state.noise * 100).toStringAsFixed(0)}%',
    );
  }
}
