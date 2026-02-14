import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import '../../models/Photo.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_grid_item.dart';
import '../../widgets/profile_menu_button.dart';
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

  // Grouped photos: Map<DateString, List<Photo>>
  Map<String, List<Photo>> _groupedPhotos = {};
  List<String> _sortedDates = [];

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
        final photos = response.data!.items.whereType<Photo>().toList();
        // Sort by creation date descending
        photos.sort((a, b) {
            final aTime = a.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
            final bTime = b.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
            return bTime.compareTo(aTime); // newest first
        });

        setState(() {
          _photos = photos;
          _groupPhotosByDate(photos);
        });
      } else if (response.errors.isNotEmpty) {
        safePrint('Query errors: ${response.errors}');
      }
    } catch (e) {
      safePrint('Error fetching photos: $e');
    }
  }

  void _groupPhotosByDate(List<Photo> photos) {
    _groupedPhotos = {};
    _sortedDates = [];

    for (var photo in photos) {
      final date = photo.createdAt?.getDateTimeInUtc().toLocal() ?? DateTime.now();
      final dateKey = _formatDate(date);

      if (!_groupedPhotos.containsKey(dateKey)) {
        _groupedPhotos[dateKey] = [];
        _sortedDates.add(dateKey);
      }
      _groupedPhotos[dateKey]!.add(photo);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Future<void> _uploadPhoto() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFiles.isEmpty) return;

    setState(() => _isUploading = true);
    int successCount = 0;
    int failCount = 0;

    try {
      for (final pickedFile in pickedFiles) {
        try {
          // Generate unique S3 key
          final uuid = const Uuid().v4();
          final extension = pickedFile.name.split('.').last;

          // Upload to S3
          final uploadResult = await Amplify.Storage.uploadFile(
            localFile: kIsWeb
                ? AWSFile.fromStream(pickedFile.openRead(), size: await pickedFile.length())
                : AWSFile.fromPath(pickedFile.path),
            path: StoragePath.fromIdentityId(
              (identityId) => 'photos/$identityId/$uuid.$extension',
            ),
          ).result;

          final actualS3Key = uploadResult.uploadedItem.path;

          // Create Photo record
          final newPhoto = Photo(
            id: uuid,
            s3Key: actualS3Key,
            facesCount: 0,
            analyzedAt: TemporalDateTime.now(),
          );
          
          final createResponse = await Amplify.API.mutate(
            request: ModelMutations.create(newPhoto)
          ).response;

          if (createResponse.errors.isNotEmpty) {
             safePrint('Error uploading ${pickedFile.name}: ${createResponse.errors}');
             failCount++;
          } else {
             successCount++;
          }
        } catch (e) {
          safePrint('Exception uploading ${pickedFile.name}: $e');
          failCount++;
        }
      }

      if (mounted) {
        final msg = failCount > 0 
          ? 'Uploaded $successCount photos. Failed: $failCount' 
          : 'Uploaded $successCount photos successfully!';
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: failCount > 0 ? Colors.orange : Theme.of(context).colorScheme.primary,
          ),
        );
        await _fetchPhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Upload process error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Photos
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchPhotos,
                  child: _photos.isEmpty 
                      ? CustomScrollView(
                          slivers: [
                              SliverAppBar(
                                  floating: true,
                                  snap: true,
                                  actions: [
                                      ProfileMenuButton(userEmail: _userEmail),
                                      const SizedBox(width: 8),
                                  ],
                              ),
                              SliverFillRemaining(child: _buildEmptyState(colorScheme)),
                          ],
                        )
                      : CustomScrollView(
                          slivers: [
                              SliverAppBar(
                                  floating: true,
                                  snap: true,
                                  actions: [
                                      ProfileMenuButton(userEmail: _userEmail),
                                      const SizedBox(width: 8),
                                  ],
                              ),
                              // Generate sticky headers for each date group
                              ..._sortedDates.map((dateKey) {
                                final photosForDate = _groupedPhotos[dateKey]!;
                                return SliverStickyHeader(
                                  header: Container(
                                    height: 50,
                                    color: colorScheme.surface.withOpacity(0.95), // Slight transparency for sticky effect
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      dateKey,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  sliver: SliverPadding(
                                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                                    sliver: SliverGrid(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3, // Increased to 3 for better density
                                        crossAxisSpacing: 4, // Reduced gap
                                        mainAxisSpacing: 4, // Reduced gap
                                        childAspectRatio: 1,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final photo = photosForDate[index];
                                          return PhotoGridItem(
                                            photo: photo,
                                            onTap: () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => PhotoDetailScreen(photo: photo)),
                                              );
                                              _fetchPhotos();
                                            },
                                          );
                                        },
                                        childCount: photosForDate.length,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              
                              // Bottom padding
                              const SliverToBoxAdapter(child: SizedBox(height: 80)),
                          ],
                      ),
                ),
          
          // Tab 1: Search
          SearchScreen(userEmail: _userEmail),

          // Tab 2: People
          PeopleScreen(userEmail: _userEmail),
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
}
