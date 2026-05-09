import 'package:ccn_visualization/app.dart';
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
}

Future<AppRunner> _pumpApp(WidgetTester tester) async {
  final runner = await AppRunner.init(repository: FakeRepository());
  addTearDown(runner.simulationController.dispose);
  await tester.pumpWidget(CcnVisualizationApp(runner: runner));
  return runner;
}
