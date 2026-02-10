import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:flutter/material.dart';
import 'screens/auth/sign_in_screen.dart';
import 'theme/app_theme.dart';
import 'amplify_outputs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(const PhotoSenseApp());
}

Future<void> _configureAmplify() async {
  try {
    final auth = AmplifyAuthCognito();
    final storage = AmplifyStorageS3();
    final api = AmplifyAPI(
      options: APIPluginOptions(modelProvider: AmplifyModelProvider.instance),
    );
    
    await Amplify.addPlugins([auth, storage, api]);
    await Amplify.configure(amplifyConfig);
    
    safePrint('Amplify configured successfully!');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

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
