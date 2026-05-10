import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';
import 'package:ccn_visualization/features/simulation/domain/continuous_network_render_data.dart';
import 'package:ccn_visualization/features/simulation/domain/selected_neuron_summary_builder.dart';
import 'package:ccn_visualization/features/simulation/domain/selected_path_classifier.dart';
import 'package:ccn_visualization/features/simulation/domain/visualization_projection.dart';
import 'package:ccn_visualization/features/simulation/painters/activity_heatmap_painter.dart';
import 'package:ccn_visualization/features/simulation/painters/continuous_network_painter.dart';
import 'package:ccn_visualization/features/simulation/painters/raster_painter.dart';
import 'package:ccn_visualization/features/simulation/painters/spike_count_painter.dart';
import 'package:ccn_visualization/features/simulation/painters/weight_snapshot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visual projection keeps layout stable across activity frames', () {
    const projector = VisualNetworkProjector();
    final experiment = PresetCatalog.continuousLearningFlow();
    final empty = projector.project(
      experiment: experiment,
      activity: const ActivitySnapshot(),
      weights: const SparseWeightSnapshot(),
      latestFrame: null,
      baselineWeights: const <String, double>{},
      currentStep: 0,
      phaseLabel: 'Baseline',
    );
    final active = projector.project(
      experiment: experiment,
      activity: const ActivitySnapshot(
        membranes: [1, 0.5],
        recentFiringRates: [0.9, 0.1],
        spiked: [true, false],
      ),
      weights: const SparseWeightSnapshot(
        weights: [
          WeightSample(source: 0, target: 1, weight: 0.7, inhibitory: false),
        ],
      ),
      latestFrame: const StepFrame(
        startStep: 0,
        steps: 1,
        spikes: [
          SpikeEvent(stepOffset: 0, absoluteStep: 1, neuronId: 0, membrane: 1),
        ],
      ),
      baselineWeights: const {'0:1': 0.4},
      currentStep: 1,
      phaseLabel: 'Learning',
    );

    expect(active.neurons.first.x, empty.neurons.first.x);
    expect(active.neurons.first.y, empty.neurons.first.y);
    expect(active.neurons.first.depth, empty.neurons.first.depth);
    expect(active.synapses.single.signalActivity, 1);
    expect(active.synapses.single.weightChange, closeTo(0.3, 0.0001));
  });

  test(
    'camera projection resets and hit testing uses nearest visible neuron',
    () {
      const projector = VisualNetworkProjector();
      final experiment = PresetCatalog.continuousLearningFlow();
      final frame = projector.project(
        experiment: experiment,
        activity: const ActivitySnapshot(),
        weights: const SparseWeightSnapshot(),
        latestFrame: null,
        baselineWeights: const <String, double>{},
        currentStep: 0,
        phaseLabel: 'Baseline',
      );
      const size = Size(320, 220);
      final defaultProjection = projector.projectFrame(
        frame: frame,
        size: size,
      );
      final movedProjection = projector.projectFrame(
        frame: frame,
        size: size,
        camera: const NeuralFieldCamera(
          pan: Offset(24, -12),
          zoom: 1.4,
          rotation: 0.2,
        ),
      );

      expect(
        movedProjection.neurons.first.center,
        isNot(defaultProjection.neurons.first.center),
      );

      const hitTester = NeuronHitTester();
      final hit = hitTester.hitTest(
        frame: frame,
        size: size,
        position: defaultProjection.neurons.first.center,
      );
      expect(hit?.neuronId, defaultProjection.neurons.first.neuron.id);

      final miss = hitTester.hitTest(
        frame: frame,
        size: size,
        position: const Offset(-100, -100),
      );
      expect(miss, isNull);
    },
  );

  test('selected-neuron summary ranks paths and missing variants', () {
    const frame = VisualNetworkFrame(
      step: 4,
      phaseLabel: 'Learning',
      neurons: [
        VisualNeuron(
          id: 0,
          type: VisualNeuronType.excitatory,
          x: 0.5,
          y: 0.5,
          depth: 0.5,
          activity: 0.7,
          spiked: true,
          recentFiringRate: 0.6,
        ),
        VisualNeuron(
          id: 1,
          type: VisualNeuronType.inhibitory,
          x: 0.6,
          y: 0.6,
          depth: 0.6,
          activity: 0.2,
          spiked: false,
          recentFiringRate: 0.1,
        ),
      ],
      synapses: [
        VisualSynapse(
          source: 0,
          target: 1,
          weight: 0.8,
          inhibitory: false,
          signalActivity: 1,
          weightChange: 0.3,
        ),
      ],
    );

    const summaryBuilder = SelectedNeuronSummaryBuilder();
    final summary = summaryBuilder.build(
      selectedNeuronId: 0,
      frame: frame,
      experiment: PresetCatalog.continuousLearningFlow(),
      variants: const <VariantSnapshot>[],
      baselineWeights: const <String, double>{},
    );

    expect(summary, isNotNull);
    expect(summary!.outgoing.single.target, 1);
    expect(summary.activePaths.single.target, 1);
    expect(summary.changedPaths.single.weightChange, closeTo(0.3, 0.0001));
    expect(summary.phaseExplanation, contains('Training telemetry'));
    expect(summary.variantComparisons, isNotEmpty);
    expect(summary.variantComparisons.first.available, isFalse);
  });

  testWidgets(
    'selected-neuron highlighting painter renders without exceptions',
    (tester) async {
      const frame = VisualNetworkFrame(
        neurons: [
          VisualNeuron(
            id: 0,
            type: VisualNeuronType.excitatory,
            x: 0.45,
            y: 0.45,
            depth: 0.4,
            activity: 0.9,
            spiked: true,
            recentFiringRate: 0.7,
          ),
          VisualNeuron(
            id: 1,
            type: VisualNeuronType.inhibitory,
            x: 0.58,
            y: 0.58,
            depth: 0.7,
            activity: 0.3,
            spiked: false,
            recentFiringRate: 0.2,
          ),
        ],
        synapses: [
          VisualSynapse(
            source: 0,
            target: 1,
            weight: 0.6,
            inhibitory: false,
            signalActivity: 1,
            weightChange: 0.2,
          ),
        ],
        step: 3,
        phaseLabel: 'Learning',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 160,
            child: CustomPaint(
              painter: ContinuousNetworkPainter(
                renderData: _renderData(
                  frame: frame,
                  size: const Size(240, 160),
                  selectedNeuronId: 0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weight delta overlay painter renders selected labels', (
    tester,
  ) async {
    const frame = VisualNetworkFrame(
      neurons: [
        VisualNeuron(
          id: 0,
          type: VisualNeuronType.excitatory,
          x: 0.35,
          y: 0.45,
          depth: 0.4,
          activity: 0.9,
          spiked: true,
          recentFiringRate: 0.7,
        ),
        VisualNeuron(
          id: 1,
          type: VisualNeuronType.inhibitory,
          x: 0.68,
          y: 0.58,
          depth: 0.7,
          activity: 0.3,
          spiked: false,
          recentFiringRate: 0.2,
        ),
      ],
      synapses: [
        VisualSynapse(
          source: 0,
          target: 1,
          weight: 0.7,
          inhibitory: false,
          signalActivity: 1,
          weightChange: 0.3,
        ),
      ],
      step: 3,
      phaseLabel: 'Learning',
    );

    final renderData = _renderData(
      frame: frame,
      size: const Size(240, 160),
      selectedNeuronId: 0,
      showWeightDeltaOverlay: true,
      baselineWeights: const {'0:1': 0.4},
    );

    expect(renderData.weightDeltas.single.label, '0.40 -> 0.70 (+0.30)');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 160,
          child: CustomPaint(
            painter: ContinuousNetworkPainter(renderData: renderData),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'painters render empty, sparse, and dense data without layout changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: Column(
              children: const [
                SizedBox(width: 200, height: 120, child: _EmptyNetworkPaint()),
                SizedBox(
                  width: 200,
                  height: 120,
                  child: CustomPaint(
                    painter: RasterPainter(
                      events: [
                        SpikeEvent(
                          stepOffset: 0,
                          absoluteStep: 1,
                          neuronId: 2,
                          membrane: 0.8,
                        ),
                      ],
                      neuronCount: 8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 80,
                  child: CustomPaint(
                    painter: SpikeCountPainter(counts: [0, 3, 1]),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 80,
                  child: CustomPaint(
                    painter: ActivityHeatmapPainter(
                      snapshot: ActivitySnapshot(recentFiringRates: [0.1, 0.9]),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  height: 120,
                  child: CustomPaint(
                    painter: WeightSnapshotPainter(
                      neuronCount: 4,
                      snapshot: SparseWeightSnapshot(
                        weights: [
                          WeightSample(
                            source: 0,
                            target: 1,
                            weight: 0.4,
                            inhibitory: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 200, height: 120, child: _DenseNetworkPaint()),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}

class _DenseNetworkPaint extends StatelessWidget {
  const _DenseNetworkPaint();

  @override
  Widget build(BuildContext context) {
    const projector = VisualNetworkProjector();
    final experiment = PresetCatalog.continuousLearningFlow();
    final frame = projector.project(
      experiment: experiment,
      activity: ActivitySnapshot(
        membranes: List<double>.filled(72, 0.8),
        recentFiringRates: List<double>.filled(72, 0.6),
        spiked: List<bool>.filled(72, true),
      ),
      weights: SparseWeightSnapshot(
        weights: List<WeightSample>.generate(
          420,
          (index) => WeightSample(
            source: index % 72,
            target: (index * 7 + 3) % 72,
            weight: index.isEven ? 0.6 : -0.4,
            inhibitory: index.isOdd,
          ),
        ),
      ),
      latestFrame: const StepFrame(startStep: 0, steps: 1, spikes: []),
      baselineWeights: const <String, double>{},
      currentStep: 12,
      phaseLabel: 'Dense',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: ContinuousNetworkPainter(
            renderData: _renderData(
              frame: frame,
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyNetworkPaint extends StatelessWidget {
  const _EmptyNetworkPaint();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: ContinuousNetworkPainter(
            renderData: _renderData(
              frame: const VisualNetworkFrame(
                neurons: [],
                synapses: [],
                step: 0,
                phaseLabel: 'Empty',
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        );
      },
    );
  }
}

ContinuousNetworkRenderData _renderData({
  required VisualNetworkFrame frame,
  required Size size,
  int? selectedNeuronId,
  bool showWeightDeltaOverlay = false,
  Map<String, double> baselineWeights = const <String, double>{},
}) {
  const builder = ContinuousNetworkRenderDataBuilder(
    pathClassifier: SelectedPathClassifier(),
  );
  return builder.build(
    frame: frame,
    size: size,
    camera: NeuralFieldCamera.defaults,
    selectedNeuronId: selectedNeuronId,
    showWeightDeltaOverlay: showWeightDeltaOverlay,
    baselineWeights: baselineWeights,
  );
}
