import 'package:flutter/widgets.dart';

import 'package:ccn_visualization/core/ffi/ccn_native.dart';
import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';

class AppDependencies {
  AppDependencies({
    CcnRepository? repository,
    ExperimentDefinition? initialExperiment,
  }) : repository =
           repository ?? NativeCcnRepository(CcnNative.loadAndVerify()),
       initialExperiment =
           initialExperiment ?? PresetCatalog.continuousLearningFlow();

  final CcnRepository repository;
  final ExperimentDefinition initialExperiment;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.dependencies != dependencies;
}
