import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';

class Bootstrap {
  const Bootstrap._();

  static Future<void> run() async {
    await runZonedGuarded(() async {
      final binding = kDebugMode
          ? MarionetteBinding.ensureInitialized()
          : WidgetsFlutterBinding.ensureInitialized();
      binding.deferFirstFrame();

      final runner = await AppRunner.init();

      runApp(CcnVisualizationApp(runner: runner));
      binding.allowFirstFrame();
    }, _onError);
  }

  static void _onError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('Uncaught error'),
      ),
    );
  }
}
