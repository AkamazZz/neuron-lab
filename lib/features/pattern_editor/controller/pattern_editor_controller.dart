import 'package:flutter/foundation.dart';

import '../../../core/models/pattern.dart';
import 'pattern_editor_state.dart';

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
    final id = _state.activeName.toLowerCase().replaceAll(' ', '_');
    final pattern = PatternDefinition(
      id: id,
      label: _state.activeName,
      activations: _state.activeCells
          .map(
            (cell) =>
                PatternActivation(neuronId: cell, current: _state.strength),
          )
          .toList(growable: false),
    );
    _state = _state.copyWith(
      savedPatterns: {..._state.savedPatterns, id: pattern},
    );
    notifyListeners();
  }
}
