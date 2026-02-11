import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import '../../models/Person.dart';
import '../../widgets/face_avatar.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<Person> _people = [];
  bool _isLoading = true;
  final Map<String, String> _thumbnailUrls = {};

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final request = ModelQueries.list(Person.classType);
      final response = await Amplify.API.query(request: request).response;
      final people = response.data?.items.whereType<Person>().toList() ?? [];

      // Sort by name
      people.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _people = people;
          _isLoading = false;
        });
        _loadThumbnails(people);
      }
    } catch (e) {
      safePrint('Error loading people: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadThumbnails(List<Person> people) async {
    for (var person in people) {
      if (person.thumbnailS3Key != null && !_thumbnailUrls.containsKey(person.id)) {
        try {
          final result = await Amplify.Storage.getUrl(
            path: StoragePath.fromString(person.thumbnailS3Key!),
          ).result;
          if (mounted) {
            setState(() {
              _thumbnailUrls[person.id] = result.url.toString();
            });
          }
        } catch (e) {
          safePrint('Error loading thumbnail for ${person.name}: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final namedPeople = _people.where((p) => p.isUnnamed != true).toList();
    final unnamedPeople = _people.where((p) => p.isUnnamed == true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _people.isEmpty
              ? const Center(child: Text('No people tagged yet'))
              : CustomScrollView(
                  slivers: [
                    if (unnamedPeople.isNotEmpty) ...[
                       SliverPadding(
                         padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                         sliver: SliverToBoxAdapter(
                           child: Text("New Faces", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         ),
                       ),
                       SliverPadding(
                         padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                         sliver: SliverGrid(
                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                           ),
                           delegate: SliverChildBuilderDelegate(
                             (context, index) => _buildPersonItem(unnamedPeople[index]),
                             childCount: unnamedPeople.length,
                           ),
                         ),
                       ),
                       const SliverToBoxAdapter(child: SizedBox(height: 16)),
                       const SliverToBoxAdapter(child: Divider()),
                    ],
                    
                    if (namedPeople.isNotEmpty) ...[
                       SliverPadding(
                         padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                         sliver: SliverToBoxAdapter(
                           child: Text("People", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         ),
                       ),
                       SliverPadding(
                         padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                         sliver: SliverGrid(
                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                           ),
                           delegate: SliverChildBuilderDelegate(
                             (context, index) => _buildPersonItem(namedPeople[index]),
                             childCount: namedPeople.length,
                           ),
                         ),
                       ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildPersonItem(Person person) {
    final imageUrl = _thumbnailUrls[person.id];
    Map<String, dynamic> box = {};
    
    if (person.boundingBox != null) {
      try {
        box = jsonDecode(person.boundingBox!);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () async {
         await Navigator.of(context).push(
           MaterialPageRoute(builder: (_) => PersonDetailScreen(person: person)),
         );
         _loadPeople(); // Refresh on return (in case of rename/merge)
      },
      child: Column(
        children: [
          Expanded(
            child: imageUrl != null && box.isNotEmpty
                ? FaceAvatar( // Use FaceAvatar if we have box
                    imageUrl: imageUrl,
                    boundingBox: box,
                    size: 100, 
                    showLabel: false,
                  )
                : CircleAvatar( // Fallback
                    radius: 40,
                    backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                    child: imageUrl == null ? const Icon(Icons.person, size: 40) : null,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            person.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: person.isUnnamed == true ? FontWeight.normal : FontWeight.bold,
              fontStyle: person.isUnnamed == true ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
