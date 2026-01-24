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
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E88E5), // Premium Blue
              brightness: Brightness.light,
              surface: const Color(0xFFF5F7FA),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
            ),
            // cardTheme: CardTheme(
            //   elevation: 2,
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            //   surfaceTintColor: Colors.white,
            // ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E88E5),
              brightness: Brightness.dark,
              surface: const Color(0xFF121212),
              onSurface: const Color(0xFFE0E0E0),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            // cardTheme: CardTheme(
            //   elevation: 4,
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            //   surfaceTintColor: const Color(0xFF1E1E1E),
            // ),
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
