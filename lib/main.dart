import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/sign_in_screen.dart';

void main() {
  runApp(const PhotoSenseApp());
}

/// PhotoSense - Intelligent Photo Gallery App
class PhotoSenseApp extends StatelessWidget {
  const PhotoSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SignInScreen(),
    );
  }
}
