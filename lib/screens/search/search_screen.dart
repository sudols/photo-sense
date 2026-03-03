import 'package:flutter/material.dart';
import '../../models/photo.dart';
import '../../services/photo_service.dart';
import '../../widgets/profile_menu_button.dart';
import '../photo/photo_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? userEmail;
  final bool autofocus;

  const SearchScreen({
    super.key,
    this.userEmail,
    this.autofocus = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Photo> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _hasSearched = true;
    });

    try {
      final results = await PhotoService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                autoFocus: widget.autofocus,
                hintText: 'Search photos, people, text...',
                leading: const Icon(Icons.search),
                trailing: [
                  ProfileMenuButton(userEmail: widget.userEmail),
                ],
                onSubmitted: _performSearch,
              ),
            ),
            Expanded(
              child: _isSearching
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final photo = _searchResults[index];
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
}
