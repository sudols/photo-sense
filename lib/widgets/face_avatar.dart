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

    // To crop strictly to the face, we need to scale the image so that the face
    // fills the 'size'.
    // Scale factor = size / (imageSize * boxWidth)
    // But we don't know imageSize. 
    // Trick: We assume the container is 'size' wide.
    // The full image width would be (size / bw).
    // The full image height would be (size / bh) -- assuming square crop?
    // Actually box might not be square.
    // Let's force a square crop based on the largest dimension of the face?
    // Or simpler: Scale the image so the face width matches 'size'.
    // widthScale = 1 / bw.
    
    // We use a Stack/Positioned approach inside a clipped container.
    // The Image widget needs to be scaled up.
    // Alignment is crucial.
    
    // Actually, simpler math:
    // If we want the face to be 'size' pixels wide:
    // The image must be rendered at width: size / bw.
    // The image must be positioned at left: -bl * (size / bw).
    // This assumes the aspect ratio of the original image is preserved.
    // But we don't know the aspect ratio of the original image here.
    // NetworkImage doesn't give us dimensions synchronously.
    
    // Flutter's `FittedBox` with `Alignment` can help if we knew the center.
    // Alignment x = (left + width/2) * 2 - 1
    // Alignment y = (top + height/2) * 2 - 1
    // And `BoxFit.cover` on a container that matches the face aspect ratio?
    // But we want a CIRCLE.
    // Let's use `Alignment` approach which is robust against unknown aspect ratios.
    // We calculate the center of the face in -1.0 to 1.0 coordinate space.
    

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
                  color: Colors.black.withOpacity(0.1),
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
              // We need to zoom in so the face fills the circle.
              // By default BoxFit.cover fills the circle with the WHOLE image? No.
              // BoxFit.cover scales the image to cover the circle.
              // If we use Alignment, it centers on the face.
              // BUT it doesn't zoom in enough if the face is small.
              // We need a custom implementation for zooming.
              
              // Alternative: LayoutBuilder in the list parent to know face ratio? No.
              // Let's try a custom Painter or `flow`? Too complex.
              // Let's stick to the "Scale" trick.
              // We accept we might need the image dimensions for perfect pixel cropping.
              // BUT `Alignment` + a high scale factor?
              // How much to scale? scale = 1 / max(bw, bh).
              // We can transform the image.
              
              // Let's use a `FittedBox` inside a `SizedBox` with a specific transform.
              // Actually, `PhotoView` does this but that's a package.
              
              // Simple approach that works surprisingly well:
              // Use `Image.network` details to set `scale`. No, `scale` property is pixel density.
              
              // Let's try `OverflowBox`.
              // Container(size, size, Clip.oval)
              //  -> OverflowBox(maxWidth: size/bw, maxHeight: size/bh (approx))
              //    -> Image.network
              //      -> Alignment(-1 to 1 based on left/top)
              
              // Wait, removing 'approx'. We don't know aspect ratio, so we can't set both width/height strictly.
              // If we set width = size/bw, height = null -> It maintains aspect ratio.
              // Then we need to offset it correctly.
              
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  // The image is loaded, we can try to render it.
                  // But standard Image widget doesn't let us apply the "Crop" easily without dimensions.
                  
                  // Let's return a LayoutBuilder which helps? No.
                  
                  // Correct Robust Solution without knowing image dimensions upfront:
                  // Use `CustomClipper`? No.
                  
                  // Let's fallback to `Alignment` with `BoxFit.none` and `scale`?
                  // No, `BoxFit.cover` + `Alignment` centers the face, but if the face is 10% of image,
                  // it will show the whole image (cropped to circle) centered on face.
                  
                  // We need to ZOOM.
                  // We can wrap Image in `Transform.scale`.
                  // scale = 1 / bw (roughly).
                  return Transform.scale(
                    scale: 1 / (bw > bh ? bw : bh), // Scale so the larger dimension of face matches container
                    alignment: Alignment(centerX, centerY),
                    child: child,
                  );
                }
                return Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              
              errorBuilder: (_,__,___) => const Icon(Icons.person, color: Colors.grey),
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
