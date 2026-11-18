import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/licenses.dart';
import 'core/providers/app_state.dart';
import 'core/services/migration_service.dart';
import 'screens/disguises/disguise_screen.dart';
import 'screens/setup/setup_flow.dart';
import 'screens/vault/vault_home_screen.dart';
import 'ui/vault_theme.dart';

final GlobalKey<NavigatorState> appNavigator = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await MigrationService.runMigrations();

  registerLicenses();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: const SecureVaultApp(),
    ),
  );
}

class SecureVaultApp extends StatelessWidget {
  const SecureVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Utility',
      navigatorKey: appNavigator,
      debugShowCheckedModeBanner: false,
      theme: buildVaultTheme(Brightness.light),
      darkTheme: buildVaultTheme(Brightness.dark),
      themeMode: themeMode,
      home: const AppRouter(),
    );
  }
}

/// Shows setup, the disguise or the vault, and locks the vault when the app
/// is left.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late final AppLifecycleListener _lifecycle;
  bool _wasUnlocked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => context.read<AppState>().onLeft(),
      onShow: () => context.read<AppState>().onReturned(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Opening or locking the vault closes every screen opened before it.
    if (_wasUnlocked != state.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigator.currentState?.popUntil((route) => route.isFirst);
      });
    }
    _wasUnlocked = state.isUnlocked;

    final Widget screen;
    if (!state.isSetupComplete) {
      screen = const SetupFlow(key: ValueKey('setup'));
    } else if (state.isUnlocked) {
      screen = VaultHomeScreen(key: ValueKey('vault-${state.currentVault?.id}'));
    } else {
      screen = DisguiseScreen(
        key: ValueKey('disguise-${state.currentDisguise.id}'),
        disguise: state.currentDisguise,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: screen,
    );
  }
}
