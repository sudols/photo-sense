import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../services/person_service.dart';
import '../../widgets/face_avatar.dart';
import '../../widgets/profile_menu_button.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatefulWidget {
  final String? userEmail;
  const PeopleScreen({super.key, this.userEmail});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<Person> _people = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final people = await PersonService.listPersons();

      // Sort by name
      people.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _people = people;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading people: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final namedPeople = _people.where((p) => !p.isUnnamed).toList();
    final unnamedPeople = _people.where((p) => p.isUnnamed).toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          ProfileMenuButton(userEmail: widget.userEmail),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPeople,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_people.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No people tagged yet')),
                    )
                  else ...[
                    if (unnamedPeople.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 16),
                        sliver: SliverToBoxAdapter(
                          child: Text("Who's this?", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 140,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: unnamedPeople.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 16),
                            itemBuilder: (context, index) => SizedBox(
                              width: 100,
                              child: _buildPersonItem(unnamedPeople[index], showName: false),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: Divider(height: 32)),
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
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildPersonItem(Person person, {bool showName = true}) {
    final imageUrl = person.thumbnailUrl;
    final box = person.boundingBox ?? {};

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
            child: Center(
              child: Stack(
                children: [
                  imageUrl != null && box.isNotEmpty
                      ? FaceAvatar(
                          imageUrl: imageUrl,
                          boundingBox: box,
                          size: 100,
                          showLabel: false,
                        )
                      : CircleAvatar(
                          radius: 40,
                          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                          child: imageUrl == null ? const Icon(Icons.person, size: 40) : null,
                        ),
                  if (person.isUnnamed)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showName) ...[
            const SizedBox(height: 8),
            Text(
              person.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: person.isUnnamed ? FontWeight.normal : FontWeight.bold,
                fontStyle: person.isUnnamed ? FontStyle.italic : FontStyle.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}
