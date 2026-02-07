import '../models/photo.dart';
import '../models/user.dart';

/// Mock data service providing sample data for the MVP mockup
class MockDataService {
  static User? _currentUser;

  /// Sample photos with mock analysis results
  static final List<Photo> _photos = [
    Photo(
      id: '1',
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
      facesCount: 0,
      detectedText: ['Mountain Peak', 'Adventure Awaits'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Photo(
      id: '2',
      imageUrl: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400',
      facesCount: 4,
      detectedText: ['Friends Forever', 'Summer 2024'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Photo(
      id: '3',
      imageUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=400',
      facesCount: 2,
      detectedText: ['Conference Room', 'Meeting in Progress', 'Do Not Disturb'],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Photo(
      id: '4',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      facesCount: 1,
      detectedText: [],
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Photo(
      id: '5',
      imageUrl: 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=400',
      facesCount: 5,
      detectedText: ['Teamwork', 'Innovation Lab', 'Welcome'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Photo(
      id: '6',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      facesCount: 1,
      detectedText: ['Portrait Session'],
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Photo(
      id: '7',
      imageUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=400',
      facesCount: 0,
      detectedText: ['Lake View', 'Nature Reserve', 'Peaceful'],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Photo(
      id: '8',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      facesCount: 1,
      detectedText: [],
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  /// Get current user (null if not signed in)
  static User? get currentUser => _currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => _currentUser != null;

  /// Get all photos
  static List<Photo> get photos => List.unmodifiable(_photos);

  /// Get a photo by ID
  static Photo? getPhotoById(String id) {
    try {
      return _photos.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Mock sign in
  static Future<User> signIn(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Simple validation
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    _currentUser = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@').first,
    );

    return _currentUser!;
  }

  /// Mock sign up
  static Future<User> signUp(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Simple validation
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required');
    }

    if (!email.contains('@')) {
      throw Exception('Please enter a valid email');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    _currentUser = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@').first,
    );

    return _currentUser!;
  }

  /// Mock sign out
  static Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  /// Mock upload photo (adds a new photo with random analysis)
  static Future<Photo> uploadPhoto(String localPath) async {
    await Future.delayed(const Duration(seconds: 2));

    final newPhoto = Photo(
      id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
      imageUrl: 'https://images.unsplash.com/photo-1523712999610-f77fbcfc3843?w=400',
      facesCount: DateTime.now().second % 5,
      detectedText: ['New Upload', 'Analyzed at ${DateTime.now().hour}:${DateTime.now().minute}'],
      createdAt: DateTime.now(),
    );

    _photos.insert(0, newPhoto);
    return newPhoto;
  }
}
