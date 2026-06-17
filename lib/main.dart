import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'theme/app_colors.dart';
import 'screens/vibe_check_screen.dart';
import 'package:firebase_core/firebase_core.dart';
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Full immersive during splash; restored after
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp();

  runApp(const AccescoApp());
}

class AccescoApp extends StatelessWidget {
  const AccescoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accesco',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // ── InstaStyle Dark Theme (Ch.03 Colour System) ────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundBase,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surfaceCard,
          primary: AppColors.brandWarmBrown,
          secondary: AppColors.brandTan,
          error: AppColors.fomoRed,
          onPrimary: AppColors.ivoryWhite,
          onSecondary: AppColors.backgroundBase,
          onSurface: AppColors.ivoryWhite,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      // ── Named routes — onboarding → login → profile setup → home ──────────
      routes: {
        '/login': (context) => const LoginScreen(),
        '/profile-setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const HomeScreen(),
        '/vibe-check': (context) => const VibeCheckScreen(),
      },
      // ── Initial screen: splash → onboarding ──────────────────────────
      home: SplashScreen(
        onComplete: () {
          // 1. Restore normal system UI (was immersive during splash)
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.backgroundBase,
            systemNavigationBarIconBrightness: Brightness.light,
          ));

          // 2. Replace splash with onboarding — uses navigatorKey since the
          //    callback's `context` is from MaterialApp.build (above the
          //    Navigator) and can't find one with Navigator.of(context).
          navigatorKey.currentState?.pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (_, __, ___) => const OnboardingScreen(),
              // Soft fade — splash already fades out, so this glides in
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
      ),
    );
  }
}