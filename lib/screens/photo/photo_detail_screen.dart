import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../../models/Photo.dart';
import '../../models/Person.dart';
import '../../models/PhotoPerson.dart';
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
  String? _imageUrl;
  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, String> _faceNames = {}; // Map faceId -> Person Name

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
    _loadFaceNames();
  }

  Future<void> _loadFaceNames() async {
    if (widget.photo.detectedFaces == null) return;
    
    try {
       // Get all faceIds in this photo
       final faceIds = widget.photo.detectedFaces!.map((f) {
          try {
            return jsonDecode(f)['faceId'] as String;
          } catch(_) {
            return "";
          }
       }).where((id) => id.isNotEmpty).toList();

       if (faceIds.isEmpty) return;

       // Query People who have these faceIds
       // Current schema limitations: List Person and filter locally. 
       // Ideal: Query Person where faceIds contains X. (Not supported in standard list without search index)
       final request = ModelQueries.list(Person.classType);
       final response = await Amplify.API.query(request: request).response;
       final persons = response.data?.items.whereType<Person>().toList() ?? [];

       final newMap = <String, String>{};
       for (var person in persons) {
         if (person.faceIds != null) {
           for (var faceId in faceIds) {
             if (person.faceIds!.contains(faceId)) {
               newMap[faceId] = person.name;
             }
           }
         }
       }

       if (mounted) {
         setState(() {
           _faceNames = newMap;
         });
       }
    } catch (e) {
      safePrint('Error loading face names: $e');
    }
  }

  Future<void> _loadImageUrl() async {
    try {
      final result = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(widget.photo.s3Key),
      ).result;
      if (mounted) {
        setState(() {
          _imageUrl = result.url.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error loading image URL: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFaceTap(String faceId, String? existingName, Map<String, dynamic> boundingBox) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NameFaceDialog(initialName: existingName),
    );

    if (name != null && name.isNotEmpty) {
       await _savePersonDocs(faceId, name, jsonEncode(boundingBox));
    }
  }

  Future<void> _savePersonDocs(String faceId, String name, String boundingBoxString) async {
    setState(() => _isLoading = true);
    try {
      // 1. Check if Person exists by name
      final request = ModelQueries.list(Person.classType);
      final response = await Amplify.API.query(request: request).response;
      
      Person? person;
      final persons = response.data?.items.where((p) => p != null).cast<Person>() ?? [];
      
      try {
        person = persons.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase());
      } catch (_) {
        person = null;
      }

      if (person != null) {
        if (person.faceIds == null || !person.faceIds!.contains(faceId)) {
          final List<String> updatedFaceIds = [...(person.faceIds ?? []), faceId];
          // Determine if we should update the thumbnail/boundingBox to this new face if the current one is broken?
          // For now, keep the original unless it's null.
          final updatedPerson = person.copyWith(
            faceIds: updatedFaceIds,
            boundingBox: person.boundingBox ?? boundingBoxString,
            thumbnailS3Key: person.thumbnailS3Key ?? widget.photo.s3Key,
          );
          await Amplify.API.mutate(request: ModelMutations.update(updatedPerson)).response;
          safePrint('Updated Person ${person.name} with new faceId');
        }
      } else {
        person = Person(
          name: name,
          faceId: faceId,
          faceIds: [faceId],
          boundingBox: boundingBoxString,
          thumbnailS3Key: widget.photo.s3Key,
        );
        final createRes = await Amplify.API.mutate(request: ModelMutations.create(person)).response;
        person = createRes.data;
        safePrint('Created Person ${person?.name}');
      }

      if (person != null) {
        final link = PhotoPerson(
          photoId: widget.photo.id,
          personId: person.id,
        );
        await Amplify.API.mutate(request: ModelMutations.create(link)).response;
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tagged as ${person.name}')));
           _loadFaceNames(); 
        }
      }
      
    } catch (e) {
      safePrint('Error saving person: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      // Delete from S3
      await Amplify.Storage.remove(
        path: StoragePath.fromString(widget.photo.s3Key),
      ).result;

      // Delete from AppSync
      final deleteRequest = ModelMutations.delete(widget.photo);
      await Amplify.API.mutate(request: deleteRequest).response;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.toString().replaceFirst("Exception: ", "")}'),
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
            // Photo with Bounding Boxes
            AspectRatio(
              aspectRatio: 1,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : _imageUrl != null
                      ? Image.network(
                          _imageUrl!,
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
                  if (widget.photo.detectedFaces != null && widget.photo.detectedFaces!.isNotEmpty) ...[
                     Text('Identified Faces', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 12),
                     SizedBox(
                       height: 90, // Enough for avatar + text
                       child: ListView.separated(
                         scrollDirection: Axis.horizontal,
                         itemCount: widget.photo.detectedFaces!.length,
                         separatorBuilder: (context, index) => const SizedBox(width: 16),
                         itemBuilder: (context, index) {
                           try {
                             final face = jsonDecode(widget.photo.detectedFaces![index]);
                             final faceId = face['faceId'] as String;
                             final box = face['boundingBox'];
                             final personName = _faceNames[faceId];
                             
                             return FaceAvatar(
                               imageUrl: _imageUrl!,
                               boundingBox: box,
                               name: personName,
                               onTap: () => _handleFaceTap(faceId, personName, box),
                             );
                           } catch (e) {
                             return const SizedBox();
                           }
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
                    value: widget.photo.facesCount != null ? '${widget.photo.facesCount}' : 'Not analyzed',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Detected text
                  _buildInfoCard(
                    icon: Icons.text_fields,
                    title: 'Detected Text',
                    value: widget.photo.detectedText != null && widget.photo.detectedText!.isNotEmpty
                        ? widget.photo.detectedText!.join(', ')
                        : 'No text detected',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Analyzed at
                  _buildInfoCard(
                    icon: Icons.schedule,
                    title: 'Analyzed At',
                    value: widget.photo.analyzedAt != null
                        ? widget.photo.analyzedAt!.format()
                        : 'Pending analysis',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),

                  // Created at
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Uploaded',
                    value: widget.photo.createdAt != null
                        ? widget.photo.createdAt!.format()
                        : 'Unknown',
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
