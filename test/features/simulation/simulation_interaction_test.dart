import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/features/simulation/domain/simulation_interaction_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interaction controller updates gesture camera and path selection', () {
    const interaction = SimulationInteractionController();
    const frame = VisualNetworkFrame(
      step: 3,
      phaseLabel: 'Learning',
      neurons: [
        VisualNeuron(
          id: 0,
          type: VisualNeuronType.excitatory,
          x: 0.4,
          y: 0.4,
          depth: 0.3,
          activity: 0.8,
          spiked: true,
          recentFiringRate: 0.6,
        ),
        VisualNeuron(
          id: 1,
          type: VisualNeuronType.inhibitory,
          x: 0.6,
          y: 0.6,
          depth: 0.7,
          activity: 0.2,
          spiked: false,
          recentFiringRate: 0.1,
        ),
      ],
      synapses: [
        VisualSynapse(
          source: 0,
          target: 1,
          weight: 0.7,
          inhibitory: false,
          signalActivity: 1,
          weightChange: 0.2,
        ),
      ],
    );

    final anchor = interaction.beginGesture(
      camera: NeuralFieldCamera.defaults,
      focalPoint: const Offset(20, 20),
    );
    final movedCamera = interaction.updateGesture(
      anchor: anchor,
      focalPoint: const Offset(38, 12),
      scale: 1.4,
      rotation: 0.2,
    );

    expect(movedCamera.pan, const Offset(18, -8));
    expect(movedCamera.zoom, 1.4);
    expect(movedCamera.rotation, closeTo(0.11, 0.0001));

    final selectedId = interaction.selectedNeuronAt(
      frame: frame,
      size: const Size(240, 160),
      position: const Offset(100, 68),
      camera: NeuralFieldCamera.defaults,
    );
    expect(selectedId, 0);

    final classification = interaction.classifyPaths(
      frame: frame,
      selectedNeuronId: 0,
    );
    expect(classification.highlightsSynapse(frame.synapses.single), isTrue);
    expect(classification.subduesNeuron(1), isFalse);
  });
}
