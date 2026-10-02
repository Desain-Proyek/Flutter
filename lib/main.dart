import 'package:flutter/material.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/live_measurement_screen.dart';
import 'screens/field_log_screen.dart';
import 'screens/hardware_diy_guide_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/disaster_map_screen.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PortaStatApp());
}

class PortaStatApp extends StatefulWidget {
  const PortaStatApp({super.key});

  @override
  State<PortaStatApp> createState() => _PortaStatAppState();
}

class _PortaStatAppState extends State<PortaStatApp> {
  bool _isHighContrast = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortaStat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, _isHighContrast),
      darkTheme: _buildTheme(Brightness.dark, _isHighContrast),
      themeMode: ThemeMode.system,
      home: AuthGate(
        isHighContrast: _isHighContrast,
        onHighContrastChanged: (val) => setState(() => _isHighContrast = val),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, bool highContrast) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      brightness: brightness,
      primary: const Color(0xFF0284C7),
      secondary: const Color(0xFF0D9488),
      tertiary: const Color(0xFFE11D48),
      surface: isDark
          ? (highContrast ? Colors.black : const Color(0xFF0B1120))
          : (highContrast ? Colors.white : const Color(0xFFF8FAFC)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark
            ? (highContrast ? const Color(0xFF1E293B) : const Color(0xFF131C2E))
            : Colors.white,
        elevation: 0,
      ),
      fontFamily: 'Roboto',
    );
  }
}

class AuthGate extends StatelessWidget {
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;

  const AuthGate({
    super.key,
    required this.isHighContrast,
    required this.onHighContrastChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return MainNavigationContainer(
            isHighContrast: isHighContrast,
            onHighContrastChanged: onHighContrastChanged,
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;

  const MainNavigationContainer({
    super.key,
    required this.isHighContrast,
    required this.onHighContrastChanged,
  });

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeDashboardScreen(
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      const LiveMeasurementScreen(),
      const FieldLogScreen(),
      const DisasterMapScreen(),
      const HardwareDIYGuideScreen(),
      SettingsScreen(
        isHighContrast: widget.isHighContrast,
        onHighContrastChanged: widget.onHighContrastChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        elevation: 2,
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF0284C7)),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded, color: Color(0xFF0284C7)),
            label: 'Uji & Grafik',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded, color: Color(0xFF0284C7)),
            label: 'Catatan Air',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF0284C7)),
            label: 'Peta Wilayah',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build_rounded, color: Color(0xFF0284C7)),
            label: 'Perakitan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF0284C7)),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
