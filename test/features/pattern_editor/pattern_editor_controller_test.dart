import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggles cells, changes values, saves pattern, builds experiment', () {
    final controller = PatternEditorController();

    controller.toggleCell(3);
    controller.setStrength(1.5);
    controller.setNoise(0.2);
    controller.setActiveName('Pattern B');
    controller.saveActivePattern();

    expect(controller.state.activeCells, contains(3));
    expect(controller.state.strength, 1.5);
    expect(controller.state.noise, 0.2);
    expect(controller.state.savedPatterns, contains('pattern_b'));

    final experiment = controller.state.toExperimentDefinition();
    expect(experiment.patterns.first.activations.first.neuronId, 3);
    expect(experiment.phases.first.schedule.toJson()['noise_probability'], 0.2);
  });
}
