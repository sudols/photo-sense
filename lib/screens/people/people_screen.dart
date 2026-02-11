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
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _people.isEmpty
              ? const Center(child: Text('No people tagged yet'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _people.length,
                  itemBuilder: (context, index) {
                    final person = _people[index];
                    final imageUrl = _thumbnailUrls[person.id];
                    Map<String, dynamic> box = {};
                    
                    if (person.boundingBox != null) {
                      try {
                        box = jsonDecode(person.boundingBox!);
                      } catch (_) {}
                    }

                    return GestureDetector(
                      onTap: () {
                         Navigator.of(context).push(
                           MaterialPageRoute(builder: (_) => PersonDetailScreen(person: person)),
                         );
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: imageUrl != null
                                ? FaceAvatar(
                                    imageUrl: imageUrl,
                                    boundingBox: box,
                                    size: 100, // Large avatar
                                    showLabel: false,
                                  )
                                : const CircleAvatar(
                                    radius: 40,
                                    child: Icon(Icons.person, size: 40),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            person.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
