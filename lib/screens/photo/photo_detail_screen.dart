import 'package:flutter/material.dart';
import '../../models/photo.dart';
import '../../models/person.dart';
import '../../services/photo_service.dart';
import '../../services/person_service.dart';
import '../people/name_face_dialog.dart';
import '../../widgets/face_avatar.dart';

/// Detail screen for viewing a single photo and its analysis results
class PhotoDetailScreen extends StatefulWidget {
  final Photo photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool _isDeleting = false;
  Map<String, Person> _facePersons = {}; // Map faceId -> Person

  @override
  void initState() {
    super.initState();
    _loadFaceData();
  }

  Future<void> _loadFaceData() async {
    if (widget.photo.detectedFaces.isEmpty) return;

    try {
      final faceIds = widget.photo.detectedFaces
          .map((f) => f['face_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (faceIds.isEmpty) return;

      final persons = await PersonService.listPersons();

      final newMap = <String, Person>{};
      for (var person in persons) {
        for (var faceId in faceIds) {
          if (person.faceIds.contains(faceId)) {
            newMap[faceId] = person;
          }
        }
      }

      if (mounted) {
        setState(() {
          _facePersons = newMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading face data: $e');
    }
  }

  Future<void> _handleFaceTap(String faceId, String? existingName, Map<String, dynamic> boundingBox) async {
    Person? knownPerson = _facePersons[faceId];

    if (knownPerson != null && !knownPerson.isUnnamed) {
      // Already named — just show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This is ${knownPerson.name}')),
      );
      return;
    }

    // Unnamed or unknown — let user name them
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NameFaceDialog(
        initialName: "",
        title: knownPerson != null ? 'Name this person' : 'Who is this?',
        subtitle: knownPerson != null ? 'This face was auto-grouped. Give it a name.' : null,
      ),
    );

    if (name != null && name.isNotEmpty && knownPerson != null) {
      try {
        await PersonService.renamePerson(knownPerson.id, name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to $name')),
          );
          _loadFaceData(); // Refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('This will permanently delete this photo. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await PhotoService.deletePhoto(widget.photo.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo deleted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop(); // Go back to home
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = widget.photo.url;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Details'),
        actions: [
          IconButton(
            icon: _isDeleting
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.error))
                : Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: _isDeleting ? null : _deletePhoto,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo
            AspectRatio(
              aspectRatio: 1,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                    ),
            ),

            // Analysis results
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Identified Faces List
                  if (widget.photo.detectedFaces.isNotEmpty) ...[
                    Text('Identified Faces', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.photo.detectedFaces.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final face = widget.photo.detectedFaces[index];
                          final faceId = face['face_id'] as String? ?? '';
                          final box = face['bounding_box'] as Map<String, dynamic>? ?? {};
                          final personName = _facePersons[faceId]?.name;

                          if (faceId.isEmpty || imageUrl == null) return const SizedBox();

                          return FaceAvatar(
                            imageUrl: imageUrl,
                            boundingBox: box,
                            name: personName,
                            onTap: () => _handleFaceTap(faceId, personName, box),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  Text('Metadata', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Face count
                  _buildInfoCard(
                    icon: Icons.face,
                    title: 'Faces Detected',
                    value: '${widget.photo.facesCount}',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Detected text
                  _buildInfoCard(
                    icon: Icons.text_fields,
                    title: 'Detected Text',
                    value: widget.photo.detectedText.isNotEmpty
                        ? widget.photo.detectedText.join(', ')
                        : 'No text detected',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Analyzed at
                  _buildInfoCard(
                    icon: Icons.schedule,
                    title: 'Analyzed At',
                    value: widget.photo.analyzedAt != null
                        ? widget.photo.analyzedAt.toString()
                        : 'Pending analysis',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Created at
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Uploaded',
                    value: widget.photo.createdAt.toString(),
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(value),
      ),
    );
  }
}
