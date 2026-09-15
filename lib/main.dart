import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init notice (running offline/local mode): $e');
  }

  await AuthService().init();
  final activeUser = AuthService().currentUser?.username;
  await StorageService().init(activeUser);

  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: AuthService(),
        builder: (context, _) {
          if (AuthService().isLoggedIn) {
            return const MainNavigationScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
