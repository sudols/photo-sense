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

class PersonDetailScreen extends StatefulWidget {
  final Person person;

  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  List<Photo> _photos = [];
  bool _isLoading = true;
  final Map<String, String> _photoUrls = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      // 1. Get PhotoPerson links for this person
      final request = ModelQueries.list(
        PhotoPerson.classType,
        where: PhotoPerson.PERSONID.eq(widget.person.id),
      );
      final response = await Amplify.API.query(request: request).response;
      final photoPersons = response.data?.items.whereType<PhotoPerson>().toList() ?? [];

      if (photoPersons.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch Photos
      // Basic approach: Parallel Get requests
      // Note: In production, consider pagination or batch optimization.
      final photoIds = photoPersons.map((pp) => pp.photoId).toSet().toList(); // Dedup just in case
      final List<Photo> loadedPhotos = [];

      for (var photoId in photoIds) {
        try {
          final photoReq = ModelQueries.get(Photo.classType, PhotoModelIdentifier(id: photoId));
          final photoRes = await Amplify.API.query(request: photoReq).response;
          if (photoRes.data != null) {
            loadedPhotos.add(photoRes.data!);
          }
        } catch (e) {
          safePrint('Error loading photo $photoId: $e');
        }
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

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> box = {};
    if (widget.person.boundingBox != null) {
      try {
        box = jsonDecode(widget.person.boundingBox!);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.person.thumbnailS3Key != null) ...[
               FutureBuilder(
                 future: Amplify.Storage.getUrl(path: StoragePath.fromString(widget.person.thumbnailS3Key!)).result,
                 builder: (context, snapshot) {
                   if (snapshot.hasData) {
                     return SizedBox(
                       width: 32,
                       height: 32,
                       child: FaceAvatar(
                         imageUrl: snapshot.data!.url.toString(),
                         boundingBox: box,
                         size: 32,
                         showLabel: false,
                       ),
                     );
                   }
                   return const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16));
                 },
               ),
               const SizedBox(width: 12),
            ],
            Text(widget.person.name),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? const Center(child: Text('No photos found for this person'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
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
                          ? Image.network(url, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.image)),
                            ),
                    );
                  },
                ),
    );
  }
}
