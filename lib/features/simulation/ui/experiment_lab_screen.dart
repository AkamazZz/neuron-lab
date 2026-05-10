import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/network_visualization.dart';
import '../../../core/scope/simulation_scope.dart';
import '../controller/run_state.dart';
import '../controller/simulation_controller.dart';
import '../controller/simulation_state.dart';
import '../domain/continuous_network_render_data.dart';
import '../domain/challenge_replay_comparison.dart';
import '../domain/experiment_phase_interpreter.dart';
import '../domain/experiment_narration.dart';
import '../domain/selected_neuron_summary_builder.dart';
import '../domain/signal_trace_story.dart';
import '../domain/simulation_interaction_controller.dart';
import '../domain/spike_timing_explanation.dart';
import '../domain/visualization_projection.dart';
import '../painters/activity_heatmap_painter.dart';
import '../painters/continuous_network_painter.dart';
import '../painters/raster_painter.dart';
import '../painters/spike_count_painter.dart';
import '../painters/weight_snapshot_painter.dart';
import 'lab_sidebar.dart';
import 'metrics_panel.dart';
import 'phase_progress_view.dart';
import 'result_panel.dart';

class ExperimentLabScreen extends StatefulWidget {
  const ExperimentLabScreen({super.key});

  @override
  State<ExperimentLabScreen> createState() => _ExperimentLabScreenState();
}

class _ExperimentLabScreenState extends State<ExperimentLabScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _traceTick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
      final controller = SimulationScope.of(context);
      controller.stepTick(maxSteps: controller.state.stepsPerTick);
      final trace = controller.state.tracePlayback;
      if (trace.playing) {
        _traceTick += 1;
        final threshold = (8 / trace.speed).round().clamp(2, 16);
        if (_traceTick >= threshold) {
          _traceTick = 0;
          controller.stepTraceForward();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SimulationScope.of(context);
    final state = controller.state;
    final content = _LabContent(state: state);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 820) {
              return Column(
                children: [
                  SizedBox(height: 360, child: const LabSidebar()),
                  Expanded(child: content),
                ],
              );
            }
            return Row(
              children: [
                const SizedBox(width: 360, child: LabSidebar()),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LabContent extends StatelessWidget {
  const _LabContent({required this.state});
  final SimulationState state;
  static const _projector = VisualNetworkProjector();
  static const _phaseInterpreter = ExperimentPhaseInterpreter();
  static const _summaryBuilder = SelectedNeuronSummaryBuilder();
  static const _narrationBuilder = ExperimentNarrationBuilder();

  @override
  Widget build(BuildContext context) {
    final experiment = state.selectedExperiment;
    final inspected = state.inspectedVariant;
    final activity = inspected?.activity ?? state.activitySnapshot;
    final weights = inspected?.weights ?? state.weightSnapshot;
    final currentStep = inspected?.step ?? state.currentStep;
    final phaseLabel = inspected?.label ?? _phaseLabel(state);
    final networkFrame = _projector.project(
      experiment: experiment,
      activity: activity,
      weights: weights,
      latestFrame: inspected == null ? state.latestFrame : null,
      baselineWeights: state.baselineWeights,
      currentStep: currentStep,
      phaseLabel: phaseLabel,
    );
    final selectedSummary = _summaryBuilder.build(
      selectedNeuronId: state.selectedNeuronId,
      frame: networkFrame,
      experiment: experiment,
      variants: state.variantSnapshots,
      baselineWeights: state.baselineWeights,
      recentSpikes: state.rasterHistory,
    );
    final narration = _narrationBuilder.build(
      phaseLabel: phaseLabel,
      metrics: inspected?.metrics ?? state.metrics,
      selectedSummary: selectedSummary,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                experiment.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Text(_runStateLabel(state.runState)),
          ],
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        if (state.narrationEnabled && !state.narrationDismissed) ...[
          _NarrationPanel(checkpoint: narration),
          const SizedBox(height: 12),
        ],
        _PrimaryNetworkSurface(frame: networkFrame, state: state),
        if (selectedSummary != null) ...[
          const SizedBox(height: 12),
          _SelectedNeuronInspector(
            summary: selectedSummary,
            tracePlayback: state.tracePlayback,
          ),
        ],
        const SizedBox(height: 14),
        _VariantFlowView(state: state),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PhaseProgressView(progress: state.phaseProgress)),
            const SizedBox(width: 16),
            Expanded(
              child: MetricsPanel(
                metrics: inspected?.metrics ?? state.metrics,
                step: currentStep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Diagnostics', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _PainterSurface(
          title: 'Spike raster',
          height: 150,
          painter: RasterPainter(
            events: state.rasterHistory,
            neuronCount: experiment.network.neuronCount,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PainterSurface(
                title: 'Spike count',
                height: 120,
                painter: SpikeCountPainter(counts: state.spikeCountHistory),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _PainterSurface(
                title: 'Activity heatmap',
                height: 120,
                painter: ActivityHeatmapPainter(snapshot: activity),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PainterSurface(
          title: 'Sparse weights',
          height: 150,
          painter: WeightSnapshotPainter(
            snapshot: weights,
            neuronCount: experiment.network.neuronCount,
          ),
        ),
        const SizedBox(height: 16),
        Text('Result', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ResultPanel(result: state.result),
      ],
    );
  }

  String _phaseLabel(SimulationState state) {
    return _phaseInterpreter.labelForProgress(
      state.phaseProgress,
      state.selectedExperiment.phases,
    );
  }

  String _runStateLabel(RunState state) {
    switch (state) {
      case RunState.idle:
        return 'Idle';
      case RunState.loaded:
        return 'Loaded';
      case RunState.running:
        return 'Running';
      case RunState.paused:
        return 'Paused';
      case RunState.completed:
        return 'Completed';
      case RunState.failed:
        return 'Failed';
    }
  }
}

class _PrimaryNetworkSurface extends StatefulWidget {
  const _PrimaryNetworkSurface({required this.frame, required this.state});
  final VisualNetworkFrame frame;
  final SimulationState state;

  @override
  State<_PrimaryNetworkSurface> createState() => _PrimaryNetworkSurfaceState();
}

class _NarrationPanel extends StatelessWidget {
  const _NarrationPanel({required this.checkpoint});

  final NarrationCheckpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    final controller = SimulationScope.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.notes, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                checkpoint.message,
                key: const ValueKey('narration-message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('narration-dismiss-button'),
              tooltip: 'Hide narration',
              onPressed: controller.dismissNarration,
              icon: const Icon(Icons.close),
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryNetworkSurfaceState extends State<_PrimaryNetworkSurface> {
  static const _renderDataBuilder = ContinuousNetworkRenderDataBuilder();
  CameraGestureAnchor? _gestureAnchor;

  @override
  Widget build(BuildContext context) {
    final controller = SimulationScope.of(context);
    final interaction = SimulationScope.interactionOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      height: 470,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final renderData = _renderDataBuilder.build(
                frame: widget.frame,
                size: size,
                camera: widget.state.camera,
                selectedNeuronId: widget.state.selectedNeuronId,
                activeTraceSegment: widget.state.tracePlayback.activeSegment,
                showWeightDeltaOverlay: widget.state.showWeightDeltaOverlay,
                baselineWeights: widget.state.baselineWeights,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('primary-network-surface'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _selectAt(
                          controller: controller,
                          interaction: interaction,
                          size: size,
                          position: details.localPosition,
                        );
                      },
                      onScaleStart: (details) {
                        _gestureAnchor = interaction.beginGesture(
                          camera: controller.state.camera,
                          focalPoint: details.localFocalPoint,
                        );
                      },
                      onScaleUpdate: (details) {
                        final anchor = _gestureAnchor;
                        if (anchor == null) {
                          return;
                        }
                        controller.updateCamera(
                          interaction.updateGesture(
                            anchor: anchor,
                            focalPoint: details.localFocalPoint,
                            scale: details.scale,
                            rotation: details.rotation,
                          ),
                        );
                      },
                      child: CustomPaint(
                        painter: ContinuousNetworkPainter(
                          renderData: renderData,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rotate left',
                            onPressed: () => controller.updateCamera(
                              interaction.rotateLeft(controller.state.camera),
                            ),
                            icon: const Icon(Icons.rotate_left),
                            color: colorScheme.onSurface,
                          ),
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: () => controller.updateCamera(
                              interaction.zoomOut(controller.state.camera),
                            ),
                            icon: const Icon(Icons.zoom_out),
                            color: colorScheme.onSurface,
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: () => controller.updateCamera(
                              interaction.zoomIn(controller.state.camera),
                            ),
                            icon: const Icon(Icons.zoom_in),
                            color: colorScheme.onSurface,
                          ),
                          IconButton(
                            tooltip: 'Reset camera',
                            onPressed: controller.resetCamera,
                            icon: const Icon(Icons.center_focus_strong),
                            color: colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectAt({
    required SimulationController controller,
    required SimulationInteractionController interaction,
    required Size size,
    required Offset position,
  }) {
    final selectedNeuronId = interaction.selectedNeuronAt(
      frame: widget.frame,
      size: size,
      position: position,
      camera: controller.state.camera,
    );
    if (selectedNeuronId == null) {
      controller.clearSelectedNeuron();
    } else {
      controller.selectNeuron(selectedNeuronId);
    }
  }
}

class _SelectedNeuronInspector extends StatelessWidget {
  const _SelectedNeuronInspector({
    required this.summary,
    required this.tracePlayback,
  });

  final SelectedNeuronSummary summary;
  final SignalTracePlayback tracePlayback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = SimulationScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Neuron ${summary.neuron.id}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_typeLabel(summary.neuron.type))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Activity',
                  value: summary.neuron.activity.toStringAsFixed(2),
                ),
                _MetricChip(
                  label: 'Recent rate',
                  value: summary.neuron.recentFiringRate.toStringAsFixed(2),
                ),
                _MetricChip(
                  label: 'Spike',
                  value: summary.neuron.spiked ? 'Recent' : 'No recent spike',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(summary.phaseExplanation),
            const SizedBox(height: 12),
            _TraceControls(
              playback: tracePlayback,
              showWeightDeltaOverlay: controller.state.showWeightDeltaOverlay,
              showChallengeReplayComparison:
                  controller.state.showChallengeReplayComparison,
              onActivate: controller.activateTraceMode,
              onPlay: controller.playTrace,
              onPause: controller.pauseTrace,
              onStep: controller.stepTraceForward,
              onReset: controller.resetTrace,
              onSpeedChanged: controller.setTraceSpeed,
              onWeightDeltaOverlayChanged:
                  controller.setWeightDeltaOverlayVisible,
              onChallengeReplayComparisonChanged:
                  controller.setChallengeReplayComparisonVisible,
            ),
            if (controller.state.showChallengeReplayComparison) ...[
              const SizedBox(height: 10),
              _ChallengeReplayView(
                comparison: summary.challengeReplayComparison,
              ),
            ],
            const SizedBox(height: 12),
            _PathSummary(title: 'Incoming signals', paths: summary.incoming),
            const SizedBox(height: 10),
            _PathSummary(title: 'Outgoing targets', paths: summary.outgoing),
            const SizedBox(height: 10),
            _PathSummary(
              title: 'Notable weight changes',
              paths: summary.changedPaths,
              empty: 'No attached path changed beyond the display threshold.',
            ),
            const SizedBox(height: 10),
            _SpikeTimingSummary(explanations: summary.timingExplanations),
            const SizedBox(height: 12),
            Text('Phase comparison', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final comparison in summary.variantComparisons)
                  _VariantComparisonChip(comparison: comparison),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(VisualNeuronType type) {
    switch (type) {
      case VisualNeuronType.excitatory:
        return 'Excitatory';
      case VisualNeuronType.inhibitory:
        return 'Inhibitory';
    }
  }
}

class _SpikeTimingSummary extends StatelessWidget {
  const _SpikeTimingSummary({required this.explanations});

  final List<SpikeTimingExplanation> explanations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spike timing', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (explanations.isEmpty)
          const Text(
            'Detailed timing evidence is unavailable for the selected paths.',
          )
        else
          for (final explanation in explanations.take(3))
            Text(explanation.message),
      ],
    );
  }
}

class _TraceControls extends StatelessWidget {
  const _TraceControls({
    required this.playback,
    required this.showWeightDeltaOverlay,
    required this.showChallengeReplayComparison,
    required this.onActivate,
    required this.onPlay,
    required this.onPause,
    required this.onStep,
    required this.onReset,
    required this.onSpeedChanged,
    required this.onWeightDeltaOverlayChanged,
    required this.onChallengeReplayComparisonChanged,
  });

  final SignalTracePlayback playback;
  final bool showWeightDeltaOverlay;
  final bool showChallengeReplayComparison;
  final VoidCallback onActivate;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStep;
  final VoidCallback onReset;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onWeightDeltaOverlayChanged;
  final ValueChanged<bool> onChallengeReplayComparisonChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final story = playback.story;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Signal trace', style: theme.textTheme.titleSmall),
            ),
            Switch(
              key: const ValueKey('weight-delta-overlay-switch'),
              value: showWeightDeltaOverlay,
              onChanged: onWeightDeltaOverlayChanged,
            ),
            const Text('Weight deltas'),
            const SizedBox(width: 12),
            Switch(
              key: const ValueKey('challenge-replay-switch'),
              value: showChallengeReplayComparison,
              onChanged: onChallengeReplayComparisonChanged,
            ),
            const Text('Replay'),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('trace-activate-button'),
              onPressed: onActivate,
              icon: const Icon(Icons.route),
              label: Text(playback.active ? 'Rebuild trace' : 'Trace'),
            ),
          ],
        ),
        if (story != null) ...[
          const SizedBox(height: 8),
          Text(story.explanation),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const ValueKey('trace-play-pause-button'),
                tooltip: playback.playing ? 'Pause trace' : 'Play trace',
                onPressed: story.playbackLength > 1
                    ? (playback.playing ? onPause : onPlay)
                    : null,
                icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                key: const ValueKey('trace-step-button'),
                tooltip: 'Step trace',
                onPressed: story.playbackLength > 1 ? onStep : null,
                icon: const Icon(Icons.skip_next),
              ),
              IconButton(
                key: const ValueKey('trace-reset-button'),
                tooltip: 'Reset trace',
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
              ),
              SizedBox(
                width: 180,
                child: Slider(
                  key: const ValueKey('trace-speed-slider'),
                  min: 0.5,
                  max: 3.0,
                  divisions: 5,
                  value: playback.speed,
                  label: '${playback.speed.toStringAsFixed(1)}x',
                  onChanged: onSpeedChanged,
                ),
              ),
              Chip(
                label: Text(
                  'Step ${story.playbackLength == 0 ? 0 : playback.cursor + 1}/${story.playbackLength}',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _ChallengeReplayView extends StatelessWidget {
  const _ChallengeReplayView({required this.comparison});

  final ChallengeReplayComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challenge replay', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(comparison.explanation),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${comparison.baselineLabel}: ${comparison.baselineActivity.toStringAsFixed(2)}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${comparison.challengeLabel}: ${comparison.challengeActivity.toStringAsFixed(2)}',
                  ),
                ),
                Chip(label: Text(_outcomeLabel(comparison.outcome))),
              ],
            ),
            if (comparison.paths.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final path in comparison.paths) Text(path.label),
            ],
          ],
        ),
      ),
    );
  }

  String _outcomeLabel(ChallengeReplayOutcome outcome) {
    return switch (outcome) {
      ChallengeReplayOutcome.reused => 'Reused',
      ChallengeReplayOutcome.partiallyReused => 'Partial reuse',
      ChallengeReplayOutcome.notReused => 'Not reused',
      ChallengeReplayOutcome.unavailable => 'Unavailable',
    };
  }
}

class _PathSummary extends StatelessWidget {
  const _PathSummary({
    required this.title,
    required this.paths,
    this.empty = 'No telemetry path is currently attached.',
  });

  final String title;
  final List<VisualSynapse> paths;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = paths.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (visible.isEmpty)
          Text(empty)
        else
          for (final path in visible)
            Text(
              '${path.source} -> ${path.target}  weight '
              '${path.weight.toStringAsFixed(2)}, change '
              '${path.weightChange.toStringAsFixed(2)}'
              '${path.signalActivity > 0 ? ', active source spike' : ''}',
            ),
      ],
    );
  }
}

class _VariantComparisonChip extends StatelessWidget {
  const _VariantComparisonChip({required this.comparison});

  final SelectedNeuronVariantComparison comparison;

  @override
  Widget build(BuildContext context) {
    if (!comparison.available) {
      return Chip(label: Text('${comparison.label}: unavailable'));
    }
    return Chip(
      label: Text(
        '${comparison.label}: activity '
        '${comparison.activity.toStringAsFixed(2)}, '
        '${comparison.spiked ? 'spiked' : 'quiet'}, '
        '${comparison.notableChangedPaths.length} changed',
      ),
    );
  }
}

class _VariantFlowView extends StatelessWidget {
  const _VariantFlowView({required this.state});

  final SimulationState state;
  static const _phaseInterpreter = ExperimentPhaseInterpreter();

  @override
  Widget build(BuildContext context) {
    final controller = SimulationScope.of(context);
    final phases = state.selectedExperiment.phases;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < phases.length; i += 1)
          ChoiceChip(
            label: Text(_labelFor(phases[i].id, i)),
            selected: state.inspectedVariantIndex == i,
            avatar: Icon(
              _completed(i) ? Icons.check_circle : Icons.radio_button_checked,
              size: 18,
            ),
            onSelected: _completed(i)
                ? (selected) => controller.inspectVariant(selected ? i : null)
                : null,
          ),
        if (state.inspectedVariant != null)
          TextButton.icon(
            onPressed: () => controller.inspectVariant(null),
            icon: const Icon(Icons.visibility_off),
            label: const Text('Live'),
          ),
      ],
    );
  }

  bool _completed(int phaseIndex) => state.variantSnapshots.any(
    (snapshot) => snapshot.phaseIndex == phaseIndex,
  );

  String _labelFor(String phaseId, int index) {
    return _phaseInterpreter.labelForPhaseId(phaseId, index);
  }
}

class _PainterSurface extends StatelessWidget {
  const _PainterSurface({
    required this.title,
    required this.height,
    required this.painter,
  });

  final String title;
  final double height;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(painter: painter),
            ),
          ),
        ),
      ],
    );
  }
}
