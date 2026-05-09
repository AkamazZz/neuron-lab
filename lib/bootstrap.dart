import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';

class Bootstrap {
  const Bootstrap._();

  static Future<void> run() async {
    await runZonedGuarded(() async {
      if (kDebugMode) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }

      final runner = await AppRunner.init();
      runApp(CcnVisualizationApp(runner: runner));
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
