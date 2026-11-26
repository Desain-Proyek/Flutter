import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/live_measurement_screen.dart';
import 'screens/field_log_screen.dart';
import 'screens/hardware_diy_guide_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/disaster_map_screen.dart';
import 'services/auth_service.dart';
import 'services/map_cache_service.dart';
import 'widgets/high_contrast_scope.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Pada cloud_firestore ^6.9.0, offline persistence aktif secara default di platform native/desktop (Windows, Android, iOS), namun non-aktif secara default di Web.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  var user = FirebaseAuth.instance.currentUser;
  debugPrint('Firebase initialized. currentUser: ${user != null ? "uid=${user.uid}" : "null (NOT signed in)"}');

  if (user == null) {
    debugPrint('[Auth] No user signed in. Signing in anonymously before app starts...');
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
      debugPrint('[Auth] Successfully signed in anonymously on startup: uid=${user?.uid}');
    } catch (e) {
      debugPrint('[Auth] Startup anonymous sign-in error: $e');
    }
  }

  await MapCacheService().init();
  final prefs = await SharedPreferences.getInstance();
  final initialHighContrast = prefs.getBool('is_high_contrast') ?? false;

  runApp(PortaStatApp(initialHighContrast: initialHighContrast));
}

class PortaStatApp extends StatefulWidget {
  final bool initialHighContrast;

  const PortaStatApp({super.key, this.initialHighContrast = false});

  @override
  State<PortaStatApp> createState() => _PortaStatAppState();
}

class _PortaStatAppState extends State<PortaStatApp> {
  static const String _highContrastPrefKey = 'is_high_contrast';
  late bool _isHighContrast;

  @override
  void initState() {
    super.initState();
    _isHighContrast = widget.initialHighContrast;
  }

  Future<void> _setHighContrast(bool val) async {
    setState(() => _isHighContrast = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_highContrastPrefKey, val);
    } catch (e) {
      debugPrint('[Settings] Failed to persist high contrast preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortaStat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, _isHighContrast),
      darkTheme: _buildTheme(Brightness.dark, _isHighContrast),
      themeMode: ThemeMode.system,
      home: HighContrastScope(
        isHighContrast: _isHighContrast,
        child: AuthGate(
          isHighContrast: _isHighContrast,
          onHighContrastChanged: _setHighContrast,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, bool highContrast) {
    final isDark = brightness == Brightness.dark;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      brightness: brightness,
      primary: highContrast
          ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF005A9C))
          : const Color(0xFF0284C7),
      secondary: const Color(0xFF0D9488),
      tertiary: const Color(0xFFE11D48),
      surface: isDark
          ? (highContrast ? Colors.black : const Color(0xFF0B1120))
          : (highContrast ? Colors.white : const Color(0xFFF8FAFC)),
    );

    final colorScheme = highContrast
        ? baseScheme.copyWith(
            onSurface: isDark ? Colors.white : Colors.black,
            onSurfaceVariant: isDark ? Colors.white : Colors.black87,
            outline: isDark ? Colors.white70 : Colors.black,
          )
        : baseScheme;

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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

    if (!highContrast) return baseTheme;

    final fg = isDark ? Colors.white : Colors.black;
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
        bodySmall: baseTheme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
        labelLarge: baseTheme.textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
        labelMedium: baseTheme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
        titleSmall: baseTheme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
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
