import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/layout/home_shell.dart';
import 'services/store/app_store.dart';
import 'shared/widgets/empty_state.dart';

class FarmFmsApp extends StatelessWidget {
  final AppStore store;

  const FarmFmsApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: Consumer<AppStore>(
        builder: (context, store, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: store.themeMode,
          home: const RootGate(),
        ),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening the farm ledger…'),
            ],
          ),
        ),
      );
    }
    if (store.session == null) return const LoginScreen();
    return const HomeShell();
  }
}

/// Scaffold wrapper used by authenticated screens when pushed on top of the
/// shell (e.g. task detail, worker detail).
class DetailScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? actions;
  final Widget? bottomBar;

  const DetailScaffold({super.key, required this.title, required this.body, this.actions, this.bottomBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions == null ? null : [actions!],
      ),
      body: body,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Convenience accessor for the store inside widgets.
extension StoreX on BuildContext {
  AppStore get store => read<AppStore>();
}

Widget expectedEmpty() => const EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Nothing here yet',
    );