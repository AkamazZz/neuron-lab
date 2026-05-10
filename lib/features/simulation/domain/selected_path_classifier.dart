import 'package:ccn_visualization/core/models/network_visualization.dart';

class SelectedPathClassification {
  const SelectedPathClassification({
    required this.selectedNeuronId,
    required this.highlightedPathKeys,
    required this.connectedNeuronIds,
  });

  final int? selectedNeuronId;
  final Set<String> highlightedPathKeys;
  final Set<int> connectedNeuronIds;

  bool highlightsSynapse(VisualSynapse synapse) =>
      highlightedPathKeys.contains(_pathKey(synapse.source, synapse.target));

  bool subduesSynapse(VisualSynapse synapse) =>
      selectedNeuronId != null && !highlightsSynapse(synapse);

  bool subduesNeuron(int neuronId) =>
      selectedNeuronId != null &&
      neuronId != selectedNeuronId &&
      !connectedNeuronIds.contains(neuronId);

  static String _pathKey(int source, int target) => '$source:$target';
}

class SelectedPathClassifier {
  const SelectedPathClassifier();

  SelectedPathClassification classify({
    required VisualNetworkFrame frame,
    required int? selectedNeuronId,
  }) {
    if (selectedNeuronId == null) {
      return const SelectedPathClassification(
        selectedNeuronId: null,
        highlightedPathKeys: <String>{},
        connectedNeuronIds: <int>{},
      );
    }

    final highlightedPathKeys = <String>{};
    final connectedNeuronIds = <int>{selectedNeuronId};
    for (final synapse in frame.synapses) {
      final attached =
          synapse.source == selectedNeuronId ||
          synapse.target == selectedNeuronId;
      if (!attached) {
        continue;
      }
      highlightedPathKeys.add(_pathKey(synapse.source, synapse.target));
      connectedNeuronIds.add(synapse.source);
      connectedNeuronIds.add(synapse.target);
    }
    return SelectedPathClassification(
      selectedNeuronId: selectedNeuronId,
      highlightedPathKeys: highlightedPathKeys,
      connectedNeuronIds: connectedNeuronIds,
    );
  }

  String _pathKey(int source, int target) => '$source:$target';
}
