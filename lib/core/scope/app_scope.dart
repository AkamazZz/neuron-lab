import 'package:flutter/widgets.dart';

import '../ffi/ccn_native.dart';
import '../ffi/ccn_repository.dart';
import '../models/experiment_definition.dart';
import '../../features/experiments/presets/preset_catalog.dart';

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
