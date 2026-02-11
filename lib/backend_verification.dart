import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'amplify_outputs.dart';

void main() {
  runApp(const BackendVerificationApp());
}

class BackendVerificationApp extends StatelessWidget {
  const BackendVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BackendVerificationScreen(),
    );
  }
}

class BackendVerificationScreen extends StatefulWidget {
  const BackendVerificationScreen({super.key});

  @override
  State<BackendVerificationScreen> createState() => _BackendVerificationScreenState();
}

class _BackendVerificationScreenState extends State<BackendVerificationScreen> {
  String _status = 'Initializing...';
  String _logs = '';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController(); // For confirmation code

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  void _log(String message) {
    setState(() {
      _logs = '$message\n$_logs';
      print(message);
    });
  }

  Future<void> _configureAmplify() async {
    try {
      final auth = AmplifyAuthCognito();
      final storage = AmplifyStorageS3();
      final api = AmplifyAPI();
      
      await Amplify.addPlugins([auth, storage, api]);
      await Amplify.configure(amplifyConfig);
      
      setState(() => _status = 'Amplify Configured');
      _log('Amplify configured successfully');
      
      _checkCurrentUser();
    } catch (e) {
      setState(() => _status = 'Configuration Error');
      _log('Error configuring Amplify: $e');
    }
  }

  Future<void> _checkCurrentUser() async {
    try {
      final result = await Amplify.Auth.getCurrentUser();
      setState(() => _status = 'Signed In: ${result.username}');
      _log('Current User: ${result.userId} - ${result.username}');
    } catch (e) {
      setState(() => _status = 'Guest');
      _log('No current user');
    }
  }

  Future<void> _signIn() async {
    try {
      final result = await Amplify.Auth.signIn(
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _log('Sign In Result: ${result.isSignedIn}');
      if (result.isSignedIn) {
        _checkCurrentUser();
      } else {
        _log('Sign In not complete: ${result.nextStep.signInStep}');
      }
    } catch (e) {
      _log('Sign In Error: $e');
    }
  }

  Future<void> _signUp() async {
    try {
      final result = await Amplify.Auth.signUp(
        username: _emailController.text.trim(),
        password: _passwordController.text,
        options: SignUpOptions(userAttributes: {
          AuthUserAttributeKey.email: _emailController.text.trim(),
        }),
      );
      _log('Sign Up Result: ${result.isSignUpComplete}');
      if (!result.isSignUpComplete) {
        _log('Verification needed: ${result.nextStep.signUpStep}');
      }
    } catch (e) {
      _log('Sign Up Error: $e');
    }
  }

  Future<void> _confirmSignUp() async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: _emailController.text.trim(),
        confirmationCode: _codeController.text.trim(),
      );
      _log('Confirm Sign Up Result: ${result.isSignUpComplete}');
    } catch (e) {
      _log('Confirmation Error: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await Amplify.Auth.signOut();
      _checkCurrentUser();
      _log('Signed Out');
    } catch (e) {
      _log('Sign Out Error: $e');
    }
  }

  Future<void> _uploadTestFile() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final operation = Amplify.Storage.uploadData(
        data: S3DataPayload.string('Hello World from Flutter PhotoSense Verification'),
        path: StoragePath.fromIdentityId(
          (identityId) => 'photos/$identityId/test_$timestamp.txt',
        ),
      );
      final result = await operation.result;
      _log('Upload Result: ${result.uploadedItem.path}');
    } catch (e) {
      _log('Upload Error: $e');
    }
  }

  Future<void> _listPhotos() async {
    const listPhotosQuery = '''
      query ListPhotos {
        listPhotos {
          items {
            id
            s3Key
            facesCount
            createdAt
          }
        }
      }
    ''';
    
    try {
      final request = GraphQLRequest<String>(document: listPhotosQuery);
      final response = await Amplify.API.query(request: request).response;
      
      if (response.data != null) {
        _log('List Photos Response: ${response.data}');
        final json = jsonDecode(response.data!);
        final items = json['listPhotos']['items'] as List;
        _log('Found ${items.length} photos');
      } else if (response.errors.isNotEmpty) {
         _log('List Photos Errors: ${response.errors}');
      }
    } catch (e) {
      _log('List Photos Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Verification')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            width: double.infinity,
            child: Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                Row(
                  children: [
                    ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _signUp, child: const Text('Sign Up')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _signOut, child: const Text('Sign Out')),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Confirmation Code'),
                ),
                ElevatedButton(onPressed: _confirmSignUp, child: const Text('Confirm Sign Up')),
                const Divider(),
                const Text('Operations (Must be signed in)'),
                Wrap(
                  spacing: 8,
                  children: [
                     ElevatedButton(onPressed: _uploadTestFile, child: const Text('Upload Test File')),
                     ElevatedButton(onPressed: _listPhotos, child: const Text('List Photos (GraphQL)')),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            padding: const EdgeInsets.all(8),
            color: Colors.black12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(_logs, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
