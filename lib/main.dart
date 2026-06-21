import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/profile_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'utils/constants.dart';
import 'services/ble_sensor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const BreatheSafeApp());
}

class BreatheSafeApp extends StatefulWidget {
  const BreatheSafeApp({super.key});

  @override
  State<BreatheSafeApp> createState() => _BreatheSafeAppState();
}

class _BreatheSafeAppState extends State<BreatheSafeApp> {
  final _profileService = ProfileService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return _fadeRoute(
              SplashScreen(profileService: _profileService),
            );
          case AppRoutes.onboarding:
            return _fadeRoute(
              OnboardingScreen(profileService: _profileService),
            );
          case AppRoutes.home:
            return _fadeRoute(
              _MainShell(profileService: _profileService),
            );
          default:
            return _fadeRoute(
              SplashScreen(profileService: _profileService),
            );
        }
      },
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AppDurations.pageTransition,
    );
  }
}

class _MainShell extends StatefulWidget {
  final ProfileService profileService;

  const _MainShell({required this.profileService});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _bleSensorService = BleSensorService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleSensorService.tryReconnectFromBackground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bleSensorService.tryReconnectFromBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bleSensorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bgWhite,
                  AppColors.bgGray,
                ],
              ),
            ),
          ),
          // Screen content — IndexedStack keeps both screens alive
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(bleService: _bleSensorService, profileService: widget.profileService),
              SettingsScreen(profileService: widget.profileService, bleService: _bleSensorService),
            ],
          ),
          // Bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
