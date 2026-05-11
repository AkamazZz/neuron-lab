import 'package:ccn_visualization/core/scope/simulation_scope.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';
import 'package:ccn_visualization/features/pattern_editor/ui/pattern_editor_panel.dart';
import 'package:ccn_visualization/features/simulation/controller/simulation_controller.dart';
import 'package:ccn_visualization/features/simulation/domain/simulation_interaction_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_repository.dart';

void main() {
  testWidgets('shows saved slot details and loads slot for editing', (
    tester,
  ) async {
    final repository = FakeRepository();
    await _pumpPanel(tester, repository);

    await tester.tap(find.byTooltip('Neuron 4'));
    await tester.tap(find.byTooltip('Neuron 2'));
    await tester.ensureVisible(find.byTooltip('Save pattern'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save pattern'));
    await tester.pump();

    expect(find.text('Saved slots'), findsOneWidget);
    expect(find.textContaining('Pattern A: 2 active'), findsOneWidget);
    expect(find.textContaining('neurons 2, 4'), findsOneWidget);
    expect(find.textContaining('current 1.20'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Neuron 9'));
    await tester.pump();
    await tester.tap(find.byTooltip('Neuron 9'));
    await tester.ensureVisible(find.byTooltip('Load Pattern A for editing'));
    await tester.pump();
    await tester.tap(find.byTooltip('Load Pattern A for editing'));
    await tester.pump();
    await tester.ensureVisible(find.text('Use custom pattern'));
    await tester.pump();
    await tester.tap(find.text('Use custom pattern'));
    await tester.pump();

    final activations = repository.loaded!.patterns.first.activations;
    expect(activations.map((activation) => activation.neuronId), <int>[2, 4]);
  });

  testWidgets('shows input dropout wording and experiment usage preview', (
    tester,
  ) async {
    await _pumpPanel(tester, FakeRepository());

    expect(find.text('Input dropout 5%'), findsOneWidget);
    expect(
      find.text('Suppresses selected pattern inputs during training.'),
      findsOneWidget,
    );
    expect(find.text('Experiment preview'), findsOneWidget);
    expect(
      find.textContaining('Source: current grid Pattern A'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Train: pattern_a with 5% input dropout'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Probe: pattern_a without dropout'),
      findsOneWidget,
    );
    expect(find.textContaining('schedule noise_probability'), findsOneWidget);
  });
}

Future<void> _pumpPanel(WidgetTester tester, FakeRepository repository) async {
  final controller = SimulationController(
    repository: repository,
    initialExperiment: PresetCatalog.patternRecognition(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SimulationScope(
            controller: controller,
            interactionController: const SimulationInteractionController(),
            child: const PatternEditorPanel(),
          ),
        ),
      ),
    ),
  );
}
