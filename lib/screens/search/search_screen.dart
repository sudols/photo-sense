import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../../models/Photo.dart';
import '../../models/Person.dart';
import '../../models/PhotoPerson.dart';
import '../../widgets/profile_menu_button.dart';
import '../photo/photo_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? userEmail;
  const SearchScreen({super.key, this.userEmail});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Photo> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  final Map<String, String> _photoUrls = {};

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _hasSearched = true;
    });

    try {
      final lowerQuery = query.toLowerCase();
      Set<Photo> distinctPhotos = {};

      // 1. Search by Text (Filter in memory for now as AppSync 'contains' is case-sensitive usually)
      // Ideally we should use OpenSearch for this, but for MVP we scan or rely on basic filters.
      // Let's try to fetch all photos and filter? Or use `contains`.
      // `detectedText` is a list of strings, or a single block? Schema says `detectedText: String`.
      
      final textRequest = ModelQueries.list(Photo.classType); 
      // We list all for now as `contains` might be inefficient or case-sensitive.
      // For MVP with small dataset, list all + client filter is safest for "smart" search.
      
      final photoResponse = await Amplify.API.query(request: textRequest).response;
      final allPhotos = photoResponse.data?.items.whereType<Photo>().toList() ?? [];

      for (var photo in allPhotos) {
        if (photo.detectedText != null && 
            photo.detectedText!.any((t) => t.toLowerCase().contains(lowerQuery))) {
          distinctPhotos.add(photo);
        }
      }

      // 2. Search by Person Name
      final personRequest = ModelQueries.list(Person.classType);
      final personResponse = await Amplify.API.query(request: personRequest).response;
      final allPeople = personResponse.data?.items.whereType<Person>().toList() ?? [];
      
      final matchedPeople = allPeople.where((p) => p.name.toLowerCase().contains(lowerQuery)).toList();

      for (var person in matchedPeople) {
        // Find photos for this person
        final ppRequest = ModelQueries.list(
          PhotoPerson.classType, 
          where: PhotoPerson.PERSONID.eq(person.id)
        );
        final ppResponse = await Amplify.API.query(request: ppRequest).response;
        final photoPersons = ppResponse.data?.items.whereType<PhotoPerson>().toList() ?? [];
        
        for (var pp in photoPersons) {
           // efficient find from already fetched 'allPhotos' if possible, else fetch
           try {
             final photo = allPhotos.firstWhere((p) => p.id == pp.photoId);
             distinctPhotos.add(photo);
           } catch (_) {
             // Not in our initial list? fetch it.
             final indReq = ModelQueries.get(Photo.classType, PhotoModelIdentifier(id: pp.photoId));
             final indRes = await Amplify.API.query(request: indReq).response;
             if (indRes.data != null) distinctPhotos.add(indRes.data!);
           }
        }
      }

      final results = distinctPhotos.toList();
      results.sort((a, b) {
         final dateA = a.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
         final dateB = b.createdAt?.getDateTimeInUtc() ?? DateTime(2000);
         return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        _loadPhotoUrls(results);
      }

    } catch (e) {
      safePrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search photos, people, text...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          autofocus: false, // Don't autofocus to avoid keyboard popping on tab switch
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
          ProfileMenuButton(userEmail: widget.userEmail),
          const SizedBox(width: 8),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasSearched ? Icons.search_off : Icons.search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _hasSearched ? 'No results found' : 'Find photos by text or person',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final photo = _searchResults[index];
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
