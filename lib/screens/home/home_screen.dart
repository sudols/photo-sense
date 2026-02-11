import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/Photo.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_grid_item.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_in_screen.dart';
import '../photo/photo_detail_screen.dart';
import '../people/people_screen.dart';
import '../search/search_screen.dart';

/// Home screen with photo grid and upload functionality
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;
  bool _isLoading = true;
  List<Photo> _photos = [];
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserAndPhotos();
  }

  Future<void> _loadUserAndPhotos() async {
    setState(() => _isLoading = true);
    try {
      // Get current user info
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final attributes = await Amplify.Auth.fetchUserAttributes();
        final emailAttr = attributes.firstWhere(
          (a) => a.userAttributeKey == AuthUserAttributeKey.email,
          orElse: () => AuthUserAttribute(
            userAttributeKey: AuthUserAttributeKey.email,
            value: user.username,
          ),
        );
        _userEmail = emailAttr.value;
      }

      // Fetch photos from AppSync
      await _fetchPhotos();
    } catch (e) {
      safePrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPhotos() async {
    try {
      final request = ModelQueries.list(Photo.classType);
      final response = await Amplify.API.query(request: request).response;

      if (response.data != null) {
        setState(() {
          _photos = response.data!.items.whereType<Photo>().toList();
          _photos.sort((a, b) {
            final aTime = a.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
            final bTime = b.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
            return bTime.compareTo(aTime); // newest first
          });
        });
      } else if (response.errors.isNotEmpty) {
        safePrint('Query errors: ${response.errors}');
      }
    } catch (e) {
      safePrint('Error fetching photos: $e');
    }
  }

  Future<void> _uploadPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      // Generate unique S3 key
      final uuid = const Uuid().v4();
      final extension = pickedFile.name.split('.').last;

      // Upload to S3 using identity-based path
      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: kIsWeb
            ? AWSFile.fromStream(pickedFile.openRead(), size: await pickedFile.length())
            : AWSFile.fromPath(pickedFile.path),
        path: StoragePath.fromIdentityId(
          (identityId) => 'photos/$identityId/$uuid.$extension',
        ),
      ).result;

      final actualS3Key = uploadResult.uploadedItem.path;

      // Create Photo record in AppSync
      // Use the same UUID for the Photo ID and the file name to simplify Lambda lookup
      final newPhoto = Photo(
        id: uuid,
        s3Key: actualS3Key,
        facesCount: 0,
        analyzedAt: TemporalDateTime.now(),
      );
      final createRequest = ModelMutations.create(newPhoto);
      final createResponse = await Amplify.API.mutate(request: createRequest).response;

      if (createResponse.errors.isNotEmpty) {
        throw Exception('Failed to create photo record: ${createResponse.errors}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo uploaded successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        await _fetchPhotos(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _userEmail != null ? _userEmail!.substring(0, 1).toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_rounded, color: colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            const Text('PhotoSense'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                initials,
                style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userEmail ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'signout',
                onTap: _signOut,
                child: const Row(
                  children: [Icon(Icons.logout_outlined), SizedBox(width: 12), Text('Sign Out')],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Photos
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchPhotos,
                  child: _photos.isEmpty ? _buildEmptyState(colorScheme) : _buildPhotoGrid(),
                ),
          
          // Tab 1: Search
          const SearchScreen(),

          // Tab 2: People
          const PeopleScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_outlined),
            selectedIcon: Icon(Icons.photo),
            label: 'Photos',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 
        ? FloatingActionButton.extended(
            onPressed: _isUploading ? null : _uploadPhoto,
            icon: _isUploading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
          )
        : null,
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No photos yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Upload your first photo to get started', style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return PhotoGridItem(
          photo: photo,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PhotoDetailScreen(photo: photo)),
            );
            _fetchPhotos(); // Refresh after returning from detail
          },
        );
      },
    );
  }
}
