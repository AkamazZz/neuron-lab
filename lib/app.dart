import 'package:ccn_visualization/core/ffi/ccn_native.dart';
import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/scope/app_scope.dart';
import 'package:ccn_visualization/core/scope/simulation_scope.dart';
import 'package:ccn_visualization/features/simulation/controller/simulation_controller.dart';
import 'package:ccn_visualization/features/simulation/domain/simulation_interaction_controller.dart';
import 'package:ccn_visualization/features/simulation/ui/experiment_lab_screen.dart';

class AppRunner {
  AppRunner._({
    required this.dependencies,
    required this.simulationController,
    required this.interactionController,
  });

  final AppDependencies dependencies;
  final SimulationController simulationController;
  final SimulationInteractionController interactionController;

  static Future<AppRunner> init({CcnRepository? repository}) async {
    repository ??= NativeCcnRepository(CcnNative.loadAndVerify());
    final dependencies = AppDependencies(repository: repository);
    final simulationController = SimulationController(
      repository: dependencies.repository,
      initialExperiment: dependencies.initialExperiment,
    );
    await simulationController.loadPreset(
      simulationController.state.selectedExperiment,
    );
    return AppRunner._(
      dependencies: dependencies,
      simulationController: simulationController,
      interactionController: const SimulationInteractionController(),
    );
  }
}

class CcnVisualizationApp extends StatelessWidget {
  const CcnVisualizationApp({super.key, required this.runner});

  final AppRunner runner;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xff235d5f);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CCN Visualization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AppScope(
        dependencies: runner.dependencies,
        child: AnimatedBuilder(
          animation: runner.simulationController,
          builder: (context, _) {
            return SimulationScope(
              controller: runner.simulationController,
              interactionController: runner.interactionController,
              child: const ExperimentLabScreen(),
            );
          },
        ),
      ),
    );
  }
}
