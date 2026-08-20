import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/style_preferences_screen.dart';
import 'screens/vibe_check_screen.dart';
import 'services/app_preferences.dart';
import 'services/auth_service.dart';
import 'theme/app_dimens.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Full immersive during splash; restored once it completes.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Guarded so the comment below is actually true. A missing or misplaced
  // google-services.json, a revoked API key, or a Play Services failure all
  // make this throw — and unguarded it takes the app down *before*
  // runApp(), producing a process that dies on launch with no UI at all.
  // Every Firebase-backed service already degrades to a signed-out state,
  // so browsing survives this.
  try {
    await Firebase.initializeApp();
  } catch (error, stack) {
    debugPrint('Firebase.initializeApp() failed: $error\n$stack');
  }

  // Both must resolve before the first frame: preferences decide where the
  // splash sends the user, and a uid must exist before the cart, wishlist or
  // any thrift listing is touched.
  //
  // Neither call throws on failure — a user who can't reach Firebase should
  // still get a browsable app rather than a crash on launch.
  await Future.wait([
    AppPreferences.instance.load(),
    AuthService.instance.ensureSignedIn(),
  ]);

  runApp(const InstaStyleApp());
}

class InstaStyleApp extends StatelessWidget {
  const InstaStyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InstaStyle',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // ── InstaStyle editorial light theme ───────────────────────────────
      // Every token — colour, type, radius, motion, component styling —
      // comes from AppTheme so no screen needs to define its own.
      theme: AppTheme.light,

      // Clamp accessibility text scaling: the editorial layouts stay readable
      // up to 1.3x, beyond which serif headlines start clipping their cards.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),

      routes: {
        '/home': (context) => const HomeScreen(),
        '/vibe-check': (context) => const VibeCheckScreen(),
      },

      // ── Entry flow ────────────────────────────────────────────────────
      //   splash → first run?  → onboarding → style preferences → home
      //                        ↳ returning  → home
      //
      // There is no sign-in step: identity is established silently by
      // AuthService.ensureSignedIn() during startup.
      home: SplashScreen(onComplete: _routeAfterSplash),
    );
  }

  /// Decides where the app opens once the splash video finishes.
  ///
  /// Uses [navigatorKey] rather than a `BuildContext`: the callback fires from
  /// `MaterialApp.build`, which sits above the Navigator and cannot find one.
  static void _routeAfterSplash() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final destination = AppPreferences.instance.isFirstTimeUser
        // First run: introduce the product, then collect sizes and styles.
        ? OnboardingScreen(
            onComplete: () => navigator.pushReplacement(
              StylePreferencesScreen.route(
                onComplete: () =>
                    navigator.pushReplacementNamed('/home'),
              ),
            ),
          )
        // Returning: straight in.
        : const HomeScreen();

    navigator.pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) => destination,
        // The splash already fades out, so this glides in behind it.
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
  }
}
