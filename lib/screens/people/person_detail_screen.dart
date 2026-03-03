import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../models/photo.dart';
import '../../services/person_service.dart';
import '../photo/photo_detail_screen.dart';
import '../../widgets/face_avatar.dart';
import 'name_face_dialog.dart';
import '../search/search_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final Person person;

  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late Person _person;
  List<Photo> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final person = await PersonService.getPerson(_person.id);
      if (mounted) {
        setState(() {
          _person = person;
          _photos = person.photos ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading person photos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMerge() async {
    // 1. Fetch other people for selection
    List<Person> allPeople = [];
    try {
      allPeople = await PersonService.listPersons();
      allPeople = allPeople.where((p) => p.id != _person.id).toList();
    } catch (e) {
      debugPrint("Error fetching people for merge: $e");
      return;
    }

    if (allPeople.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other people to merge with.')));
      return;
    }

    if (!mounted) return;

    // 2. Show Selection Dialog
    final Person? targetPerson = await showDialog<Person>(
      context: context,
      builder: (context) {
        List<Person> filtered = List.from(allPeople);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Merge into...'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          filtered = allPeople.where((p) => p.name.toLowerCase().contains(val.toLowerCase())).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: p.isUnnamed ? const Text('Unnamed') : null,
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );

    if (targetPerson == null) return;

    if (!mounted) return;

    // 3. Confirm Merge
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Merge into ${targetPerson.name}?'),
        content: Text('This will move all photos from "${_person.name}" to "${targetPerson.name}". "${_person.name}" will be deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 4. Execute Merge — single call
    setState(() => _isLoading = true);
    try {
      await PersonService.mergePerson(_person.id, targetPerson.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged into ${targetPerson.name}')));
        Navigator.pop(context); // Return to list
      }
    } catch (e) {
      debugPrint("Error merging: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error merging: $e')));
      }
    }
  }

  Future<void> _handleRename() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => const NameFaceDialog(
        title: "Name this person",
        subtitle: "All these photos will be grouped under this name.",
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        final updatedPerson = await PersonService.renamePerson(_person.id, newName);

        if (mounted) {
          setState(() {
            _person = updatedPerson;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to $newName')),
          );
        }
      } catch (e) {
        debugPrint('Error renaming: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _person.boundingBox ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(autofocus: true),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Text('Refresh'),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'refresh') _loadPhotos();
                    },
                  ),
                ],
              ),
            ),

            // Profile Header
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: FaceAvatar(
                  imageUrl: _person.thumbnailUrl ?? '',
                  boundingBox: box,
                  size: 120,
                  showLabel: false,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              _person.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // Stats
            const SizedBox(height: 8),
            Text(
              '${_photos.length} photos',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // Actions
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Rename',
                  onTap: _handleRename,
                ),
                const SizedBox(width: 32),
                _buildActionButton(
                  icon: Icons.merge_type,
                  label: 'Merge',
                  onTap: _handleMerge,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Photos Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _photos.isEmpty
                      ? Center(child: Text('No photos found', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            final url = photo.url;
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PhotoDetailScreen(photo: photo)),
                                );
                              },
                              child: url != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(url, fit: BoxFit.cover),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(child: Icon(Icons.image)),
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Icon(icon, color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
