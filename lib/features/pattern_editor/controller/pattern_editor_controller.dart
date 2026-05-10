import 'package:flutter/foundation.dart';

import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_state.dart';

class PatternEditorController extends ChangeNotifier {
  PatternEditorState _state = const PatternEditorState();

  PatternEditorState get state => _state;

  void toggleCell(int neuronId) {
    final cells = Set<int>.from(_state.activeCells);
    if (!cells.add(neuronId)) {
      cells.remove(neuronId);
    }
    _state = _state.copyWith(activeCells: cells);
    notifyListeners();
  }

  void setStrength(double value) {
    _state = _state.copyWith(strength: value);
    notifyListeners();
  }

  void setNoise(double value) {
    _state = _state.copyWith(noise: value);
    notifyListeners();
  }

  void setActiveName(String value) {
    _state = _state.copyWith(activeName: value);
    notifyListeners();
  }

  void saveActivePattern() {
    final pattern = _state.activePattern;
    _state = _state.copyWith(
      savedPatterns: {..._state.savedPatterns, pattern.id: pattern},
    );
    notifyListeners();
  }

  void loadSavedPattern(String id) {
    final pattern = _state.savedPatterns[id];
    if (pattern == null) {
      return;
    }
    final activations = pattern.activations.toList(growable: false)
      ..sort((a, b) => a.neuronId.compareTo(b.neuronId));
    final strength = activations.isEmpty
        ? _state.strength
        : activations.first.current;
    _state = _state.copyWith(
      activeCells: activations.map((activation) => activation.neuronId).toSet(),
      activeName: pattern.label,
      strength: strength,
    );
    notifyListeners();
  }
}
