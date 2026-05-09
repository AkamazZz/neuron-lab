import 'package:ccn_visualization/core/ffi/ccn_native.dart';
import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stepExperiment exposes Rust statistics and refreshed snapshots',
    () async {
      final repository = NativeCcnRepository(CcnNative.loadAndVerify());
      var created = false;
      try {
        await repository.loadExperiment(
          PresetCatalog.patternRecognition(seed: 11),
        );
        created = true;

        final before = await repository.activitySnapshot();
        final frame = await repository.stepExperiment(4);
        final activity = await repository.activitySnapshot();
        final weights = await repository.weightSnapshot();

        expect(before.step, 0);
        expect(frame.statistics.totalSpikes, greaterThan(0));
        expect(frame.statistics.batchSpikes, frame.spikes.length);
        expect(frame.statistics.activeNeuronCount, greaterThan(0));
        expect(frame.statistics.averageWeight, greaterThan(0));
        expect(activity.step, frame.endStep);
        expect(weights.step, frame.endStep);
        expect(activity.recentFiringRates.any((rate) => rate > 0), isTrue);
      } finally {
        if (created) {
          await repository.free();
        }
      }
    },
  );
}
