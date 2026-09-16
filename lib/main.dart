import 'package:flutter/material.dart';

import 'app.dart';
import 'repositories/backend/app_backend.dart';
import 'services/store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await AppBackend.open();
  final store = AppStore(backend);
  await store.init();
  runApp(FarmFmsApp(store: store));
}