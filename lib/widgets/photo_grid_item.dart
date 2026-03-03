import 'package:flutter/material.dart';
import '../models/photo.dart';

/// Grid item displaying a photo thumbnail.
/// URL comes from photo.url (presigned, from Django serializer).
class PhotoGridItem extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo.url != null)
            Image.network(
              photo.url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant, size: 40),
              ),
            )
          else
            Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: colorScheme.onSurfaceVariant, size: 40),
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
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  if (photo.facesCount > 0) ...[
                    const Icon(Icons.face, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('${photo.facesCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                    const SizedBox(width: 8),
                  ],
                  if (photo.detectedText.isNotEmpty)
                    const Icon(Icons.text_fields,
                        color: Colors.white, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
