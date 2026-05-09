import '../../../core/models/step_frame.dart';

class RollingHistory {
  RollingHistory({this.maxEvents = 1200, this.maxSpikeCounts = 240});

  final int maxEvents;
  final int maxSpikeCounts;
  final List<SpikeEvent> raster = <SpikeEvent>[];
  final List<int> spikeCounts = <int>[];

  void addFrame(StepFrame frame) {
    raster.addAll(frame.spikes);
    spikeCounts.add(frame.spikes.length);
    if (raster.length > maxEvents) {
      raster.removeRange(0, raster.length - maxEvents);
    }
    if (spikeCounts.length > maxSpikeCounts) {
      spikeCounts.removeRange(0, spikeCounts.length - maxSpikeCounts);
    }
  }

  void clear() {
    raster.clear();
    spikeCounts.clear();
  }
}
