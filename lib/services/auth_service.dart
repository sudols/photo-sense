import 'package:amplify_flutter/amplify_flutter.dart';

/// Service for handling authentication with AWS Cognito
class AuthService {
  /// Sign in with email and password
  static Future<AuthUser> signIn(String email, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        final user = await Amplify.Auth.getCurrentUser();
        return user;
      } else {
        throw Exception('Sign in failed');
      }
    } on AuthException catch (e) {
      if (e.message.contains('already a user signed in')) {
        // If a user is already signed in, just return the current user
        final user = await Amplify.Auth.getCurrentUser();
        return user;
      }
      throw Exception(e.message);
    }
  }

  /// Sign up with email and password
  static Future<void> signUp(String email, String password) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: {
          AuthUserAttributeKey.email: email,
        }),
      );

      if (!result.isSignUpComplete) {
        // User needs to confirm email
        throw Exception(
            'Please check your email for a confirmation code and sign in after verification.');
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Get current authenticated user
  static Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } on AuthException {
      return null;
    }
  }
}
