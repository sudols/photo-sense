import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import '../../models/photo.dart';
import '../../services/auth_service.dart';
import '../../services/photo_service.dart';
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
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final photos = await PhotoService.listPhotos();
      if (mounted) {
        setState(() {
          _photos = photos;
          _groupPhotosByDate(photos);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _groupPhotosByDate(List<Photo> photos) {
    _groupedPhotos = {};
    _sortedDates = [];

    for (var photo in photos) {
      final date = photo.createdAt.toLocal();
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
          await PhotoService.uploadPhoto(pickedFile.path);
          successCount++;
        } catch (e) {
          debugPrint('Exception uploading ${pickedFile.name}: $e');
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
        await _loadPhotos();
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
                  onRefresh: _loadPhotos,
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
                                  color: colorScheme.surface.withOpacity(0.95),
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
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4,
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
                                            _loadPhotos();
                                          },
                                        );
                                      },
                                      childCount: photosForDate.length,
                                    ),
                                  ),
                                ),
                              );
                            }),

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
          ? SpeedDial(
              icon: Icons.add,
              activeIcon: Icons.close,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              activeBackgroundColor: colorScheme.error,
              activeForegroundColor: colorScheme.onError,
              spacing: 12,
              spaceBetweenChildren: 8,
              visible: true,
              curve: Curves.easeIn,
              overlayColor: Colors.black,
              overlayOpacity: 0.5,
              direction: SpeedDialDirection.up,
              elevation: 8.0,
              isOpenOnStart: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.folder_open),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  label: 'Add collection',
                  labelStyle: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                  labelBackgroundColor: colorScheme.surfaceContainerHighest,
                  onTap: _uploadCollection,
                ),
                SpeedDialChild(
                  child: const Icon(Icons.photo),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  label: 'Add photos',
                  labelStyle: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                  labelBackgroundColor: colorScheme.surfaceContainerHighest,
                  onTap: _uploadPhoto,
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _uploadCollection() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);
      int successCount = 0;
      int failCount = 0;

      for (final platformFile in result.files) {
        try {
          final path = platformFile.path;
          if (path == null) {
            debugPrint('Skipping ${platformFile.name}: No valid path');
            continue;
          }

          await PhotoService.uploadPhoto(path);
          successCount++;
        } catch (e) {
          debugPrint('Error uploading ${platformFile.name}: $e');
          failCount++;
        }
      }

      if (mounted) {
        final msg = failCount > 0
            ? 'Uploaded $successCount photos. Failed: $failCount'
            : 'Uploaded $successCount photos from collection!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: failCount > 0 ? Colors.orange : Theme.of(context).colorScheme.primary,
          ),
        );
        await _loadPhotos();
      }
    } catch (e) {
      debugPrint('Collection upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
