import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import '../../models/Photo.dart';

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

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
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
                  Text('Analysis Results', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
