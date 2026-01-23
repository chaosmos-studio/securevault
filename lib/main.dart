import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_state.dart';
import 'core/services/migration_service.dart';
import 'screens/setup/setup_wizard.dart';
import 'screens/disguises/calculator_disguise.dart';
import 'screens/disguises/notes_disguise.dart';
import 'screens/disguises/clock_disguise.dart';
import 'screens/disguises/moodspace_disguise.dart';
import 'screens/vault/vault_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await MigrationService.runMigrations();

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
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: 'Utility',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: appState.themeMode,
          home: const AppRouter(),
          routes: {
            '/setup': (context) => const SetupWizard(),
            '/home': (context) => const DisguiseRouter(),
            '/vault': (context) => const VaultHomeScreen(),
          },
        );
      },
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.isSetupComplete) {
          return const SetupWizard();
        }

        if (appState.isUnlocked) {
          return const VaultHomeScreen();
        }

        return const DisguiseRouter();
      },
    );
  }
}

class DisguiseRouter extends StatefulWidget {
  const DisguiseRouter({super.key});

  @override
  State<DisguiseRouter> createState() => _DisguiseRouterState();
}

class _DisguiseRouterState extends State<DisguiseRouter> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        switch (appState.currentDisguise) {
          case DisguiseType.calculator:
            return const CalculatorDisguise();
          case DisguiseType.notes:
            return const NotesDisguise();
          case DisguiseType.clock:
            return const ClockDisguise();
          case DisguiseType.moodspace:
            return const MoodSpaceDisguise();
        }
      },
    );
  }
}
