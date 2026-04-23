import 'package:flutter/material.dart';

class FaceAvatar extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic> boundingBox;
  final double size;
  final String? name;
  final VoidCallback? onTap;

  const FaceAvatar({
    super.key,
    required this.imageUrl,
    required this.boundingBox,
    this.size = 60,
    this.name,
    this.onTap,
    this.showLabel = true,
  });

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    // Check if bounding box is valid/non-empty
    final bool hasValidBox = boundingBox.isNotEmpty && 
                             boundingBox.containsKey('Width') && 
                             boundingBox.containsKey('Height');

    final double bw = hasValidBox ? (boundingBox['Width']?.toDouble() ?? 0.1) : 1.0;
    final double bh = hasValidBox ? (boundingBox['Height']?.toDouble() ?? 0.1) : 1.0;
    final double bl = hasValidBox ? (boundingBox['Left']?.toDouble() ?? 0.0) : 0.0;
    final double bt = hasValidBox ? (boundingBox['Top']?.toDouble() ?? 0.0) : 0.0;
    
    // If no valid box, we render center aligned with scale 1
    final double centerX = hasValidBox ? (bl + bw / 2) * 2 - 1 : 0.0;
    final double centerY = hasValidBox ? (bt + bh / 2) * 2 - 1 : 0.0;


    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: name != null ? Colors.green : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment(centerX, centerY),
              
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return Transform.scale(
                    scale: 1 / (bw > bh ? bw : bh), // Scale so the larger dimension of face matches container
                    alignment: Alignment(centerX, centerY),
                    child: child,
                  );
                }
                return Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              
              errorBuilder: (_, e, st) => const Icon(Icons.person, color: Colors.grey),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            if (name != null)
              Text(
                name!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              )
            else
              const Icon(Icons.add_circle_outline, size: 16, color: Colors.blue),
          ],
        ],
      ),
    );
  }
}
