import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'adhkar_app.dart';
import 'app_controller.dart';
import 'background_tasks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(backgroundTaskDispatcher);
  final controller = await AppController.create();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(AdhkarApp(controller: controller));
}
