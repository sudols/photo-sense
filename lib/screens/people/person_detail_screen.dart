import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../../models/Person.dart';
import '../../models/Photo.dart';
import '../../models/PhotoPerson.dart';
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
  final Map<String, String> _photoUrls = {};
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _loadPhotos();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_person.thumbnailS3Key != null) {
      try {
        final result = await Amplify.Storage.getUrl(
          path: StoragePath.fromString(_person.thumbnailS3Key!),
        ).result;
        if (mounted) {
           setState(() {
             _thumbnailUrl = result.url.toString();
           });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadPhotos() async {
    try {
      // 1. Get PhotoPerson links for this person
      final request = ModelQueries.list(
        PhotoPerson.classType,
        where: PhotoPerson.PERSONID.eq(_person.id),
      );
      final response = await Amplify.API.query(request: request).response;
      final photoPersons = response.data?.items.whereType<PhotoPerson>().toList() ?? [];

      if (photoPersons.isEmpty) {
        if (mounted) {
             // Cleanup if no links at all
             await Amplify.API.mutate(request: ModelMutations.delete(_person));
             if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This person has no photos and has been removed.')));
                 Navigator.pop(context);
             }
        }
        return;
      }

      // 2. Fetch Photos and Cleanup broken links
      final photoIds = photoPersons.map((pp) => pp.photoId).toSet().toList();
      final List<Photo> loadedPhotos = [];

      for (var photoId in photoIds) {
        try {
          final photoReq = ModelQueries.get(Photo.classType, PhotoModelIdentifier(id: photoId));
          final photoRes = await Amplify.API.query(request: photoReq).response;
          
          if (photoRes.data != null) {
            loadedPhotos.add(photoRes.data!);
          } else {
            // Photo missing! Identify broken links.
            final brokenLinks = photoPersons.where((pp) => pp.photoId == photoId).toList();
            for (var link in brokenLinks) {
                await Amplify.API.mutate(request: ModelMutations.delete(link));
                safePrint('Deleted broken PhotoPerson link: ${link.id}');
            }
          }
        } catch (e) {
          safePrint('Error loading photo $photoId: $e');
        }
      }

      // Check if any photos remain
      if (loadedPhotos.isEmpty) {
          // All photos were broken/missing
          await Amplify.API.mutate(request: ModelMutations.delete(_person));
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Person removed (no valid photos found).')));
              Navigator.pop(context);
          }
          return;
      }

      // Sort by createdAt desc
      loadedPhotos.sort((a, b) {
        final dateA = a.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
        final dateB = b.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _photos = loadedPhotos;
          _isLoading = false;
        });
        _loadPhotoUrls(loadedPhotos);
      }
      
    } catch (e) {
      safePrint('Error loading person photos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPhotoUrls(List<Photo> photos) async {
    for (var photo in photos) {
      if (!_photoUrls.containsKey(photo.id)) {
        try {
          final result = await Amplify.Storage.getUrl(
            path: StoragePath.fromString(photo.s3Key),
          ).result;
          if (mounted) {
            setState(() {
              _photoUrls[photo.id] = result.url.toString();
            });
          }
        } catch (e) {
          safePrint('Error loading URL for photo ${photo.id}: $e');
        }
      }
    }
  }

  Future<void> _handleMerge() async {
      // 1. Fetch other people for selection
      List<Person> allPeople = [];
      try {
          final req = ModelQueries.list(Person.classType);
          final res = await Amplify.API.query(request: req).response;
          allPeople = res.data?.items.whereType<Person>().where((p) => p.id != _person.id).toList() ?? [];
      } catch (e) {
          safePrint("Error fetching people for merge: $e");
          return;
      }
      
      if (allPeople.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other people to merge with.')));
          return;
      }
      
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
                                                      subtitle: p.isUnnamed == true ? const Text('Unnamed') : null,
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
                  }
              );
          }
      );
      
      if (targetPerson == null) return;
      
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
      
      // 4. Execute Merge
      setState(() => _isLoading = true);
      try {
          // A. Update Target Person FaceIDs
          final oldFaces = _person.faceIds ?? [];
          final targetFaces = targetPerson.faceIds ?? [];
          final newFaces = {...targetFaces, ...oldFaces}.toList();
          
          await Amplify.API.mutate(request: ModelMutations.update(targetPerson.copyWith(faceIds: newFaces)));
          
          // B. Move Links
          // Get links for Source
          final linksReq = ModelQueries.list(PhotoPerson.classType, where: PhotoPerson.PERSONID.eq(_person.id));
          final linksRes = await Amplify.API.query(request: linksReq).response;
          final sourceLinks = linksRes.data?.items.whereType<PhotoPerson>().toList() ?? [];
          
          // Get links for Target (to avoid duplicates)
          final targetLinksReq = ModelQueries.list(PhotoPerson.classType, where: PhotoPerson.PERSONID.eq(targetPerson.id));
          final targetLinksRes = await Amplify.API.query(request: targetLinksReq).response;
          final targetLinks = targetLinksRes.data?.items.whereType<PhotoPerson>().toList() ?? [];
          final targetPhotoIds = targetLinks.map((tp) => tp.photoId).toSet();
          
          for (var link in sourceLinks) {
              if (!targetPhotoIds.contains(link.photoId)) {
                  // Create new link
                  await Amplify.API.mutate(request: ModelMutations.create(
                      PhotoPerson(photoId: link.photoId, personId: targetPerson.id)
                  ));
              }
              // Delete old link
              await Amplify.API.mutate(request: ModelMutations.delete(link));
          }
          
          // C. Delete Source Person
          await Amplify.API.mutate(request: ModelMutations.delete(_person));
          
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged into ${targetPerson.name}')));
              Navigator.pop(context); // Return to list
          }
          
      } catch (e) {
          safePrint("Error merging: $e");
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
        )
      );

      if (newName != null && newName.isNotEmpty) {
          // Check if name exists
          try {
             final req = ModelQueries.list(Person.classType, where: Person.NAME.eq(newName));
             final res = await Amplify.API.query(request: req).response;
             final existingPeople = res.data?.items.whereType<Person>().toList() ?? [];
             
             if (existingPeople.isNotEmpty) {
                 final target = existingPeople.first;
                 // Prompt to merge
                 if (mounted) {
                     final doMerge = await showDialog<bool>(
                         context: context,
                         builder: (context) => AlertDialog(
                             title: const Text('Person already exists'),
                             content: Text('"$newName" already exists. Do you want to merge these photos into "$newName"?'),
                             actions: [
                                 TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                 FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Merge')),
                             ],
                         ),
                     );
                     
                     if (doMerge == true) {
                         // Reuse merge logic (simplified version or inline)
                         // For now, let's call a manual merge flow or just replicate logic
                         // Actually, we can just trigger _handleMerge with pre-selection if we refactor,
                         // but for simplicity, let's just do the merge here quickly or fail gracefully.
                         
                         // Better: Show error and suggest using proper Merge button for safety, 
                         // OR implement full merge here. Let's do full merge for UX.
                         
                        setState(() => _isLoading = true);
                        try {
                             final oldFaces = _person.faceIds ?? [];
                             final targetFaces = target.faceIds ?? [];
                             final newFaces = {...targetFaces, ...oldFaces}.toList();
                             
                             await Amplify.API.mutate(request: ModelMutations.update(target.copyWith(faceIds: newFaces)));
                             
                             final linksReq = ModelQueries.list(PhotoPerson.classType, where: PhotoPerson.PERSONID.eq(_person.id));
                             final linksRes = await Amplify.API.query(request: linksReq).response;
                             final sourceLinks = linksRes.data?.items.whereType<PhotoPerson>().toList() ?? [];
                             
                             final targetLinksReq = ModelQueries.list(PhotoPerson.classType, where: PhotoPerson.PERSONID.eq(target.id));
                             final targetLinksRes = await Amplify.API.query(request: targetLinksReq).response;
                             final targetLinks = targetLinksRes.data?.items.whereType<PhotoPerson>().toList() ?? [];
                             final targetPhotoIds = targetLinks.map((tp) => tp.photoId).toSet();
                             
                             for (var link in sourceLinks) {
                                  if (!targetPhotoIds.contains(link.photoId)) {
                                      await Amplify.API.mutate(request: ModelMutations.create(
                                          PhotoPerson(photoId: link.photoId, personId: target.id)
                                      ));
                                  }
                                  await Amplify.API.mutate(request: ModelMutations.delete(link));
                             }
                             
                             await Amplify.API.mutate(request: ModelMutations.delete(_person));
                             
                             if (mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged into ${target.name}')));
                                 Navigator.pop(context);
                             }
                        } catch(e) {
                             safePrint("Error merging: $e");
                             if (mounted) setState(() => _isLoading = false);
                        }
                     }
                 }
                 return;
             }

             // Rename
             final updatedPerson = _person.copyWith(
                 name: newName,
                 isUnnamed: false,
             );
             await Amplify.API.mutate(request: ModelMutations.update(updatedPerson));
             
             if (mounted) {
                 setState(() {
                     _person = updatedPerson;
                 });
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed to $newName'))
                 );
             }

          } catch (e) {
             safePrint(e);
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> box = {};
    if (_person.boundingBox != null) {
      try {
        box = jsonDecode(_person.boundingBox!);
      } catch (_) {}
    }
    
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
                            builder: (_) => const SearchScreen(autofocus: true)
                          )
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
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                          )
                      ]
                  ),
                  child: FaceAvatar(
                    imageUrl: _thumbnailUrl ?? '',
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
                        onTap: _handleRename
                    ),
                    const SizedBox(width: 32),
                    _buildActionButton(
                        icon: Icons.merge_type, 
                        label: 'Merge', 
                        onTap: _handleMerge
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
                         final url = _photoUrls[photo.id];
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
