import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/navigation/app_navigation.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'ui/auth/welcome_screen.dart';
import 'ui/common/in_app_message_overlay.dart';
import 'ui/main/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FCM background handler BEFORE Firebase.initializeApp
  NotificationService.registerBackgroundHandler();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  // Initialize HomeWidget asynchronously without blocking UI startup
  WidgetService.initialize();

  runApp(
    const ProviderScope(
      child: HeartPearlApp(),
    ),
  );
}

class HeartPearlApp extends ConsumerWidget {
  const HeartPearlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider).themeMode;
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: AppNavigation.navigatorKey,
      title: 'HeartPearl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => InAppMessageOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            // Initialize FCM notifications for logged in user
            ref.read(notificationServiceProvider).initializeFCM(user.uid);
            return const MainScaffold();
          }
          return const WelcomeScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => const WelcomeScreen(),
      ),
    );
  }
}
