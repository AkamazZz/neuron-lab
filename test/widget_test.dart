import 'package:ccn_visualization/app.dart';
import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/simulation/domain/visualization_projection.dart';
import 'package:ccn_visualization/features/simulation/painters/continuous_network_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repository.dart';

void main() {
  testWidgets('first screen exposes lab controls and result area', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.pump();

    expect(find.text('CCN Visualization'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Pattern editor'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Result'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Result'), findsOneWidget);
  });

  testWidgets('preset selection changes visible summary', (tester) async {
    await _pumpApp(tester);
    await tester.pump();

    await tester.tap(find.text('Memory Echo'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Echo'), findsWidgets);
    expect(find.textContaining('persistence'), findsOneWidget);
  });

  testWidgets('network tap selects neuron and shows inspector', (tester) async {
    final runner = await _pumpApp(tester);
    await tester.pump();

    final paintFinder = find.byKey(const ValueKey('primary-network-surface'));
    await tester.scrollUntilVisible(
      paintFinder,
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
    await tester.pump();
    final networkPaintFinder = find
        .byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is ContinuousNetworkPainter,
        )
        .first;
    final painter =
        tester.widget<CustomPaint>(networkPaintFinder).painter!
            as ContinuousNetworkPainter;
    const projector = VisualNetworkProjector();
    final projected = projector
        .projectFrame(frame: painter.frame, size: tester.getSize(paintFinder))
        .neurons
        .first;
    await tester.tapAt(tester.getTopLeft(paintFinder) + projected.center);
    await tester.pump();
    expect(
      runner.simulationController.state.selectedNeuronId,
      projected.neuron.id,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Neuron '),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.textContaining('Neuron '), findsOneWidget);
    expect(find.textContaining('Activity:'), findsOneWidget);
    expect(find.text('Phase comparison'), findsOneWidget);
  });

  testWidgets('selected neuron inspector activates trace controls', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..frameResponses.add(
        const StepFrame(
          startStep: 5,
          steps: 2,
          spikes: [
            SpikeEvent(
              stepOffset: 0,
              absoluteStep: 6,
              neuronId: 0,
              membrane: 1,
            ),
            SpikeEvent(
              stepOffset: 1,
              absoluteStep: 7,
              neuronId: 1,
              membrane: 1,
            ),
          ],
        ),
      )
      ..stateResponses.add(NativeExperimentState.running);
    final runner = await _pumpApp(tester, repository: repository);
    await runner.simulationController.stepOnce();
    runner.simulationController.selectNeuron(0);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('trace-activate-button')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey('trace-activate-button')), findsOneWidget);
    runner.simulationController.activateTraceMode();
    await tester.pump();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pump();

    expect(find.text('Signal trace'), findsOneWidget);
    expect(
      runner.simulationController.state.tracePlayback.story?.explanation,
      contains('recent activity'),
    );
    expect(find.textContaining('recent activity'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trace-play-pause-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trace-step-button')), findsOneWidget);
    expect(runner.simulationController.state.tracePlayback.active, isTrue);
  });

  testWidgets('trace activation explains unavailable telemetry', (
    tester,
  ) async {
    final runner = await _pumpApp(tester);
    runner.simulationController.selectNeuron(0);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('trace-activate-button')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey('trace-activate-button')), findsOneWidget);
    runner.simulationController.activateTraceMode();
    await tester.pump();

    expect(find.textContaining('Not enough recent activity'), findsOneWidget);
  });

  testWidgets('weight delta overlay switch controls network render data', (
    tester,
  ) async {
    final runner = await _pumpApp(tester);
    runner.simulationController.selectNeuron(0);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('weight-delta-overlay-switch')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('weight-delta-overlay-switch')),
      findsOneWidget,
    );

    runner.simulationController.setWeightDeltaOverlayVisible(true);
    await tester.pump();

    expect(runner.simulationController.state.showWeightDeltaOverlay, isTrue);
  });

  testWidgets('selected neuron inspector explains spike timing evidence', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..weightResponses.addAll([
        const SparseWeightSnapshot(
          weights: [
            WeightSample(source: 0, target: 1, weight: 0.4, inhibitory: false),
          ],
        ),
        const SparseWeightSnapshot(
          weights: [
            WeightSample(source: 0, target: 1, weight: 0.7, inhibitory: false),
          ],
        ),
      ])
      ..frameResponses.add(
        const StepFrame(
          startStep: 5,
          steps: 2,
          spikes: [
            SpikeEvent(
              stepOffset: 0,
              absoluteStep: 6,
              neuronId: 0,
              membrane: 1,
            ),
            SpikeEvent(
              stepOffset: 1,
              absoluteStep: 7,
              neuronId: 1,
              membrane: 1,
            ),
          ],
        ),
      )
      ..stateResponses.add(NativeExperimentState.running);
    final runner = await _pumpApp(tester, repository: repository);
    await runner.simulationController.stepOnce();
    runner.simulationController.selectNeuron(0);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Spike timing'),
      160,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Spike timing'), findsOneWidget);
    expect(find.textContaining('fired before target'), findsOneWidget);
    expect(find.textContaining('strengthened'), findsOneWidget);
  });

  testWidgets('challenge replay comparison shows unavailable state', (
    tester,
  ) async {
    final runner = await _pumpApp(tester);
    runner.simulationController.selectNeuron(0);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('challenge-replay-switch')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('challenge-replay-switch')),
      findsOneWidget,
    );

    runner.simulationController.setChallengeReplayComparisonVisible(true);
    await tester.pump();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -140));
    await tester.pump();

    expect(find.text('Challenge replay'), findsOneWidget);
    expect(find.textContaining('available after'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('narration can be enabled and dismissed', (tester) async {
    final runner = await _pumpApp(tester);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('narration-mode-switch')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('narration-mode-switch')), findsOneWidget);

    runner.simulationController.setNarrationEnabled(true);
    await tester.pump();

    expect(find.byKey(const ValueKey('narration-message')), findsOneWidget);
    expect(find.textContaining('Baseline'), findsOneWidget);

    runner.simulationController.dismissNarration();
    await tester.pump();

    expect(find.byKey(const ValueKey('narration-message')), findsNothing);
  });
}

Future<AppRunner> _pumpApp(
  WidgetTester tester, {
  FakeRepository? repository,
}) async {
  final runner = await AppRunner.init(
    repository: repository ?? FakeRepository(),
  );
  addTearDown(runner.simulationController.dispose);
  await tester.pumpWidget(CcnVisualizationApp(runner: runner));
  return runner;
}
