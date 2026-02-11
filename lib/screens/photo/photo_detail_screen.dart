import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
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
  Map<String, Person> _facePersons = {}; // Map faceId -> Person
    
  @override
  void initState() {
    super.initState();
    _loadImageUrl();
    _loadFaceData();
  }

  Future<void> _loadFaceData() async {
    if (widget.photo.detectedFaces == null) return;
    
    try {
       final faceIds = widget.photo.detectedFaces!.map((f) {
          try {
            return jsonDecode(f)['faceId'] as String;
          } catch(_) {
            return "";
          }
       }).where((id) => id.isNotEmpty).toList();

       if (faceIds.isEmpty) return;
       
       // Ideally query by list of IDs. For now list all.
       final request = ModelQueries.list(Person.classType);
       final response = await Amplify.API.query(request: request).response;
       final persons = response.data?.items.whereType<Person>().toList() ?? [];

       final newMap = <String, Person>{};
       for (var person in persons) {
         if (person.faceIds != null) {
           for (var faceId in faceIds) {
             if (person.faceIds!.contains(faceId)) {
               newMap[faceId] = person;
             }
           }
         }
       }

       if (mounted) {
         setState(() {
           _facePersons = newMap;
         });
       }
    } catch (e) {
      safePrint('Error loading face data: $e');
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
    Person? knownPerson = _facePersons[faceId];
    
    if (knownPerson != null && knownPerson.isUnnamed != true) {
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

    if (name != null && name.isNotEmpty) {
       await _savePersonDocs([faceId], [widget.photo], name, jsonEncode(boundingBox), existingPerson: knownPerson);
    }
  }

  Future<void> _savePersonDocs(List<String> faceIds, List<Photo> photos, String name, String boundingBoxString, {Person? existingPerson}) async {
    setState(() => _isLoading = true);
    try {
      // Check if target name exists
      final request = ModelQueries.list(Person.classType);
      final response = await Amplify.API.query(request: request).response;
      final persons = response.data?.items.where((p) => p != null).cast<Person>() ?? [];
      
      Person? targetPerson;
      try {
        targetPerson = persons.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase());
      } catch (_) {}

      // LOGIC:
      // 1. If existingPerson (Source) is Unnamed:
      //    a. If targetPerson (Target) exists: MERGE Source -> Target.
      //    b. If targetPerson does not exist: RENAME Source -> Name.
      // 2. If existingPerson is null (New):
      //    a. If targetPerson exists: ADD faces to Target.
      //    b. If targetPerson does not exist: CREATE new Person.

      if (existingPerson != null && existingPerson.isUnnamed == true) {
         // Case 1: Renaming/Merging an Unnamed Person
         if (targetPerson != null) {
            // 1a. Merge
            safePrint("Merging ${existingPerson.name} into ${targetPerson.name}");
            
            // Move faces
            final combinedFaces = {...(targetPerson.faceIds ?? []), ...(existingPerson.faceIds ?? []), ...faceIds}.toList();
            
            // Move Photo links
            // We need to find all PhotoPerson links for existingPerson and update them to targetPerson
            final linksReq = ModelQueries.list(PhotoPerson.classType, where: PhotoPerson.PERSONID.eq(existingPerson.id));
            final linksRes = await Amplify.API.query(request: linksReq).response;
            final links = linksRes.data?.items.whereType<PhotoPerson>().toList() ?? [];
            
            for (var link in links) {
                // Delete old, create new (cannot update PK fields usually, or relationship fields might be restricted)
                // Actually PhotoPerson IDs are independent. We can probably just update personId?
                // Amplify Gen 2: fields are immutable if they are PK. PhotoPerson ID is primary. personId is not PK, but it is a connection.
                // Safest: Delete and Create.
                await Amplify.API.mutate(request: ModelMutations.delete(link));
                await Amplify.API.mutate(request: ModelMutations.create(
                    PhotoPerson(photoId: link.photoId, personId: targetPerson.id)
                ));
            }
            
            // Update Target
            await Amplify.API.mutate(request: ModelMutations.update(targetPerson.copyWith(faceIds: combinedFaces)));
            
            // Delete Source
            await Amplify.API.mutate(request: ModelMutations.delete(existingPerson));
            
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged into ${targetPerson.name}')));
            
         } else {
           // 1b. Rename
           final updated = existingPerson.copyWith(name: name, isUnnamed: false);
           await Amplify.API.mutate(request: ModelMutations.update(updated));
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renamed to $name')));
         }
      } else {
         // Case 2: Standard matching
         if (targetPerson != null) {
            // 2a. Update existing
            final currentFaceIds = targetPerson.faceIds ?? [];
            final newFaceIds = {...currentFaceIds, ...faceIds}.toList();
            if (newFaceIds.length > currentFaceIds.length) {
                await Amplify.API.mutate(request: ModelMutations.update(targetPerson.copyWith(faceIds: newFaceIds)));
            }
         } else {
             // 2b. Create new
            targetPerson = Person(
                name: name,
                faceId: faceIds.first,
                faceIds: faceIds,
                boundingBox: boundingBoxString,
                thumbnailS3Key: photos.first.s3Key,
            );
            final res = await Amplify.API.mutate(request: ModelMutations.create(targetPerson)).response;
            targetPerson = res.data;
         }
         
         // Link photos (if not already linked)
         if (targetPerson != null) {
            for (var photo in photos) {
                 final link = PhotoPerson(photoId: photo.id, personId: targetPerson!.id);
                 try {
                     await Amplify.API.mutate(request: ModelMutations.create(link));
                 } catch (_) {}
            }
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tagged ${photos.length} photos')));
         }
      }

      if (mounted) _loadFaceData(); // Refresh

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
                             final personName = _facePersons[faceId]?.name;
                             
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
