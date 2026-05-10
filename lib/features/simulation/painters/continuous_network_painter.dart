import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/features/simulation/domain/continuous_network_render_data.dart';
import 'package:ccn_visualization/features/simulation/domain/path_weight_delta.dart';
import 'package:ccn_visualization/features/simulation/domain/signal_trace_story.dart';

class ContinuousNetworkPainter extends CustomPainter {
  ContinuousNetworkPainter({required this.renderData});

  final ContinuousNetworkRenderData renderData;

  final Paint _backgroundPaint = Paint()..color = const Color(0xff101817);
  final Paint _linePaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _pulsePaint = Paint()..style = PaintingStyle.fill;
  final Paint _tracePaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _labelBackgroundPaint = Paint()..style = PaintingStyle.fill;
  final Paint _haloPaint = Paint()..style = PaintingStyle.fill;
  final Paint _focusPaint = Paint()..style = PaintingStyle.fill;
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _dendritePaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _outlinePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _emptyStatePaint = Paint()
    ..color = const Color(0x33ffffff)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Path _arrowPath = Path();

  VisualNetworkFrame get frame => renderData.frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _backgroundPaint);

    if (size.isEmpty || frame.neurons.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final positions = renderData.projection.positions;
    final selectedPaths = renderData.selectedPaths;
    final activeTraceSegment = renderData.activeTraceSegment;
    final sortedSynapses =
        frame.synapses
            .where(
              (synapse) =>
                  positions.containsKey(synapse.source) &&
                  positions.containsKey(synapse.target),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final sourceDepthA = frame.neurons[a.source].depth;
            final sourceDepthB = frame.neurons[b.source].depth;
            return sourceDepthA.compareTo(sourceDepthB);
          });

    final inactiveLimit = math.min(sortedSynapses.length, 360);
    for (final synapse in sortedSynapses.take(inactiveLimit)) {
      _drawSynapse(
        canvas,
        synapse,
        positions,
        active: false,
        selected: selectedPaths.highlightsSynapse(synapse),
        traced: _isTraceSegment(synapse, activeTraceSegment),
        subdued: selectedPaths.subduesSynapse(synapse),
      );
    }

    final activeSynapses = sortedSynapses
        .where((synapse) => synapse.signalActivity > 0)
        .take(56);
    for (final synapse in activeSynapses) {
      _drawSynapse(
        canvas,
        synapse,
        positions,
        active: true,
        selected: selectedPaths.highlightsSynapse(synapse),
        traced: _isTraceSegment(synapse, activeTraceSegment),
        subdued: selectedPaths.subduesSynapse(synapse),
      );
    }

    if (selectedPaths.selectedNeuronId != null) {
      final highlightedSynapses = sortedSynapses
          .where(selectedPaths.highlightsSynapse)
          .take(72);
      for (final synapse in highlightedSynapses) {
        _drawSynapse(
          canvas,
          synapse,
          positions,
          active: true,
          selected: true,
          traced: _isTraceSegment(synapse, activeTraceSegment),
          subdued: false,
        );
      }
    }

    if (activeTraceSegment != null) {
      final tracedSynapses = sortedSynapses.where(
        (synapse) => _isTraceSegment(synapse, activeTraceSegment),
      );
      for (final synapse in tracedSynapses) {
        _drawSynapse(
          canvas,
          synapse,
          positions,
          active: true,
          selected: true,
          traced: true,
          subdued: false,
        );
      }
    }

    for (final delta in renderData.weightDeltas) {
      _drawWeightDeltaLabel(canvas, delta, positions);
    }

    final sortedNeurons = renderData.projection.neurons.toList(growable: false)
      ..sort((a, b) => a.neuron.depth.compareTo(b.neuron.depth));
    for (final projected in sortedNeurons) {
      _drawNeuron(
        canvas,
        projected.neuron,
        projected.center,
        selected: projected.neuron.id == selectedPaths.selectedNeuronId,
        traced:
            activeTraceSegment != null &&
            (projected.neuron.id == activeTraceSegment.source ||
                projected.neuron.id == activeTraceSegment.target),
        subdued: selectedPaths.subduesNeuron(projected.neuron.id),
      );
    }

    _drawContext(canvas, size);
  }

  void _drawSynapse(
    Canvas canvas,
    VisualSynapse synapse,
    Map<int, Offset> positions, {
    required bool active,
    required bool selected,
    required bool traced,
    required bool subdued,
  }) {
    final source = positions[synapse.source]!;
    final target = positions[synapse.target]!;
    final direction = target - source;
    final distance = direction.distance;
    if (distance < 1) {
      return;
    }

    final weight = synapse.weight.abs().clamp(0.0, 1.0);
    final change = synapse.weightChange.abs().clamp(0.0, 0.4);
    final baseColor = synapse.inhibitory
        ? const Color(0xff62a6ff)
        : const Color(0xffffb35c);
    final learnedColor = synapse.weightChange >= 0
        ? const Color(0xff88f5a0)
        : const Color(0xffff7474);
    final color = Color.lerp(baseColor, learnedColor, change * 2.0)!;
    final selectedAlpha = synapse.signalActivity > 0 || change >= 0.05
        ? 0.95
        : 0.7;

    _linePaint
      ..color = color.withValues(
        alpha: traced
            ? 1.0
            : selected
            ? selectedAlpha
            : subdued
            ? 0.04 + weight * 0.06
            : active
            ? 0.86
            : 0.12 + weight * 0.18,
      )
      ..strokeWidth = traced
          ? 5.8 + weight * 2.8
          : selected
          ? 2.6 + weight * 2.6
          : active
          ? 2.2 + weight * 2.4
          : 0.45 + weight * 1.5;

    if (traced) {
      _tracePaint
        ..color = const Color(0xfffdf6a8).withValues(alpha: 0.55)
        ..strokeWidth = _linePaint.strokeWidth + 6;
      canvas.drawLine(source, target, _tracePaint);
    }
    canvas.drawLine(source, target, _linePaint);

    if (!active && !selected) {
      return;
    }

    final progress = ((frame.step % 18) / 18.0);
    final pulseCenter = Offset.lerp(source, target, progress)!;
    _pulsePaint.color = traced
        ? const Color(0xfffff7a6)
        : color.withValues(alpha: selected ? 1.0 : 0.95);
    canvas.drawCircle(pulseCenter, 3.5 + weight * 5.5, _pulsePaint);

    final arrowPoint = Offset.lerp(
      source,
      target,
      math.min(progress + 0.08, 1),
    )!;
    final unit = direction / distance;
    final normal = Offset(-unit.dy, unit.dx);
    _arrowPath
      ..reset()
      ..moveTo(arrowPoint.dx, arrowPoint.dy)
      ..lineTo(
        arrowPoint.dx - unit.dx * 10 + normal.dx * 4,
        arrowPoint.dy - unit.dy * 10 + normal.dy * 4,
      )
      ..lineTo(
        arrowPoint.dx - unit.dx * 10 - normal.dx * 4,
        arrowPoint.dy - unit.dy * 10 - normal.dy * 4,
      )
      ..close();
    canvas.drawPath(_arrowPath, _pulsePaint);
  }

  void _drawNeuron(
    Canvas canvas,
    VisualNeuron neuron,
    Offset center, {
    required bool selected,
    required bool traced,
    required bool subdued,
  }) {
    final depthScale = 0.7 + neuron.depth * 0.8;
    final activity = neuron.activity.clamp(0.0, 1.0);
    final radius = (5.5 + neuron.recentFiringRate * 8.0) * depthScale;
    final baseColor = neuron.type == VisualNeuronType.inhibitory
        ? const Color(0xff67b7ff)
        : const Color(0xffffd07b);
    final activeColor = neuron.type == VisualNeuronType.inhibitory
        ? const Color(0xffb8dcff)
        : const Color(0xfffff0c2);
    final fill = Color.lerp(baseColor, activeColor, activity)!;
    final alpha = subdued ? 0.34 : 1.0;

    if (neuron.spiked) {
      _haloPaint.color = fill.withValues(alpha: 0.28 * alpha);
      canvas.drawCircle(center, radius * 2.8, _haloPaint);
    }
    if (selected) {
      _focusPaint.color = const Color(0xffffffff).withValues(alpha: 0.22);
      canvas.drawCircle(center, radius * 3.4, _focusPaint);
      _ringPaint
        ..color = const Color(0xffffffff).withValues(alpha: 0.9)
        ..strokeWidth = 2.4;
      canvas.drawCircle(center, radius * 2.15, _ringPaint);
    }
    if (traced) {
      _focusPaint.color = const Color(0xfffff7a6).withValues(alpha: 0.28);
      canvas.drawCircle(center, radius * 3.8, _focusPaint);
      _ringPaint
        ..color = const Color(0xfffff7a6).withValues(alpha: 0.95)
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, radius * 2.45, _ringPaint);
    }

    _dendritePaint
      ..color = fill.withValues(alpha: (0.22 + neuron.depth * 0.22) * alpha)
      ..strokeWidth = 1.0;
    for (var branch = 0; branch < 5; branch += 1) {
      final angle = neuron.id * 0.37 + branch * math.pi * 0.42;
      final start = Offset(
        center.dx + math.cos(angle) * radius * 0.8,
        center.dy + math.sin(angle) * radius * 0.8,
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius * (1.8 + activity),
        center.dy + math.sin(angle) * radius * (1.4 + activity),
      );
      canvas.drawLine(start, end, _dendritePaint);
    }

    final neuronPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          fill.withValues(alpha: alpha),
          baseColor.withValues(alpha: 0.72 * alpha),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    canvas.drawCircle(center, radius, neuronPaint);

    _outlinePaint
      ..color = neuron.type == VisualNeuronType.inhibitory
          ? const Color(0xffd3ecff).withValues(alpha: 0.86 * alpha)
          : const Color(0xfffff5d1).withValues(alpha: 0.86 * alpha)
      ..strokeWidth = neuron.type == VisualNeuronType.inhibitory ? 2.2 : 1.2;
    canvas.drawCircle(center, radius, _outlinePaint);
  }

  bool _isTraceSegment(VisualSynapse synapse, SignalTraceSegment? segment) {
    return segment != null &&
        synapse.source == segment.source &&
        synapse.target == segment.target;
  }

  void _drawWeightDeltaLabel(
    Canvas canvas,
    PathWeightDelta delta,
    Map<int, Offset> positions,
  ) {
    final source = positions[delta.source];
    final target = positions[delta.target];
    if (source == null || target == null) {
      return;
    }
    final midpoint = Offset.lerp(source, target, 0.5)!;
    final color = _deltaColor(delta.direction);
    _tracePaint
      ..color = color.withValues(alpha: 0.76)
      ..strokeWidth = 4.2;
    canvas.drawLine(source, target, _tracePaint);
    final painter = TextPainter(
      text: TextSpan(
        text: delta.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final rect = Rect.fromLTWH(
      midpoint.dx - painter.width / 2 - 6,
      midpoint.dy - painter.height / 2 - 4,
      painter.width + 12,
      painter.height + 8,
    );
    _labelBackgroundPaint.color = const Color(
      0xff101817,
    ).withValues(alpha: 0.84);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      _labelBackgroundPaint,
    );
    _outlinePaint
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      _outlinePaint,
    );
    painter.paint(canvas, Offset(rect.left + 6, rect.top + 4));
  }

  Color _deltaColor(PathWeightDeltaDirection direction) {
    switch (direction) {
      case PathWeightDeltaDirection.strengthened:
        return const Color(0xff8ff0a4);
      case PathWeightDeltaDirection.weakened:
        return const Color(0xffff8585);
      case PathWeightDeltaDirection.unchanged:
        return const Color(0xffd9e3df);
      case PathWeightDeltaDirection.unknown:
        return const Color(0xffffd36e);
    }
  }

  void _drawContext(Canvas canvas, Size size) {
    final paragraph = TextPainter(
      text: TextSpan(
        text: '${frame.phaseLabel}  -  step ${frame.step}',
        style: const TextStyle(
          color: Color(0xccffffff),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);
    paragraph.paint(canvas, const Offset(12, 10));
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      math.min(size.width, size.height) * 0.18,
      _emptyStatePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ContinuousNetworkPainter oldDelegate) =>
      oldDelegate.renderData != renderData;
}
