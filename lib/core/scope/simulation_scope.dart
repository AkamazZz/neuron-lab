import 'package:flutter/widgets.dart';

import '../../features/simulation/controller/simulation_controller.dart';
import '../../features/simulation/domain/simulation_interaction_controller.dart';

class SimulationScope extends InheritedWidget {
  const SimulationScope({
    super.key,
    required this.controller,
    required this.interactionController,
    required super.child,
  });

  final SimulationController controller;
  final SimulationInteractionController interactionController;

  static SimulationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SimulationScope>();
    assert(scope != null, 'SimulationScope was not found in the widget tree');
    return scope!.controller;
  }

  static SimulationInteractionController interactionOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SimulationScope>();
    assert(scope != null, 'SimulationScope was not found in the widget tree');
    return scope!.interactionController;
  }

  @override
  bool updateShouldNotify(covariant SimulationScope oldWidget) => true;
}
