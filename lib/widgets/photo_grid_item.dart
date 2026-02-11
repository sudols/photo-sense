import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Photo.dart';

/// Grid item displaying a photo thumbnail from S3
class PhotoGridItem extends StatefulWidget {
  final Photo photo;
  final VoidCallback onTap;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  String? _imageUrl;
  bool _isLoading = true;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else if (_imageUrl != null)
              Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant, size: 40),
                ),
              )
            else
              Center(
                child: Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurfaceVariant, size: 40),
              ),

            // Bottom overlay with info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    if (widget.photo.facesCount != null && widget.photo.facesCount! > 0) ...[
                      const Icon(Icons.face, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.photo.facesCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.photo.detectedText != null && widget.photo.detectedText!.isNotEmpty) ...[
                      const Icon(Icons.text_fields, color: Colors.white, size: 14),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
