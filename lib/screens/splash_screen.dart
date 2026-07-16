import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/background_alert_service.dart';
import '../services/profile_service.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  final ProfileService profileService;

  const SplashScreen({super.key, required this.profileService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.notification,
      ].request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }

    try {
      await widget.profileService.init();
      await BackgroundAlertService.configureFromProfile(widget.profileService);
    } catch (e) {
      debugPrint('Error initializing profile: $e');
    }
    await Future.delayed(AppDurations.splashDelay);

    if (mounted) {
      if (widget.profileService.profile.isComplete) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgWhite, AppColors.bgGray],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/loading.png',
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.medical_services,
                    size: 200,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.appName,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personalized Air Safety',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
