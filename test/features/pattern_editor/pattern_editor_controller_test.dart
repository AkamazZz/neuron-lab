import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'toggles cells, changes values, saves sorted pattern, builds experiment',
    () {
      final controller = PatternEditorController();

      controller.toggleCell(3);
      controller.toggleCell(1);
      controller.setStrength(1.5);
      controller.setNoise(0.2);
      controller.setActiveName('Pattern B');
      controller.saveActivePattern();

      expect(controller.state.activeCells, contains(3));
      expect(controller.state.strength, 1.5);
      expect(controller.state.noise, 0.2);
      expect(controller.state.savedPatterns, contains('pattern_b'));
      expect(controller.state.savedPatternSummaries.single.neuronIds, <int>[
        1,
        3,
      ]);

      final experiment = controller.state.toExperimentDefinition();
      expect(
        experiment.patterns.first.activations.map(
          (activation) => activation.neuronId,
        ),
        <int>[1, 3],
      );
      expect(
        experiment.phases.first.schedule.toJson()['noise_probability'],
        0.2,
      );
    },
  );

  test('loads saved slot back into editable grid', () {
    final controller = PatternEditorController();

    controller.toggleCell(7);
    controller.toggleCell(2);
    controller.setStrength(1.7);
    controller.setActiveName('Pattern C');
    controller.saveActivePattern();
    controller.toggleCell(7);
    controller.toggleCell(2);
    controller.setStrength(0.4);
    controller.setActiveName('Pattern A');

    controller.loadSavedPattern('pattern_c');

    expect(controller.state.activeName, 'Pattern C');
    expect(controller.state.activeCells, <int>{2, 7});
    expect(controller.state.strength, 1.7);
  });

  test(
    'changed current grid is custom experiment source despite saved slot',
    () {
      final controller = PatternEditorController();

      controller.toggleCell(1);
      controller.setStrength(1.0);
      controller.setActiveName('Pattern A');
      controller.saveActivePattern();
      controller.toggleCell(1);
      controller.toggleCell(9);
      controller.setStrength(1.8);
      controller.setActiveName('Pattern B');

      final experiment = controller.state.toExperimentDefinition();

      expect(experiment.patterns.first.label, 'Pattern B');
      expect(
        experiment.patterns.first.activations.map(
          (activation) => activation.neuronId,
        ),
        <int>[9],
      );
      expect(experiment.patterns.first.activations.single.current, 1.8);
      expect(
        experiment.phases.first.schedule.toJson()['pattern_id'],
        'pattern_b',
      );
    },
  );
}
