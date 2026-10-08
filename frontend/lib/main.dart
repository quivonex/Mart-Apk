import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'constants/app_constants.dart';
import 'constants/app_theme.dart';
import 'utils/shared_preferences_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QNX MART',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SharedPreferencesHelper.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primary),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data == true) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}