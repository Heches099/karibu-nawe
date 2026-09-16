import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'repositories/hive_boxes.dart';
import 'state/app_state.dart';
import 'seed/seed_data.dart';
import 'features/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive is a real embedded, persistent database: data written here
  // survives app restarts on Android/iOS/Desktop, and in IndexedDB on
  // Web — with no server required to get started. Swapping in a cloud
  // backend later (Firestore/Supabase) for true multi-device realtime
  // sync only means rewriting lib/repositories/*, per the architecture
  // notes there.
  await Hive.initFlutter();
  await HiveBoxes.openAll();

  final appState = AppState();
  await SeedData.run(appState);

  runApp(FarmSystemApp(appState: appState));
}

class FarmSystemApp extends StatelessWidget {
  final AppState appState;
  const FarmSystemApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        title: 'Farm Work Management System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const DashboardScreen(),
      ),
    );
  }
}
