import 'package:flutter/material.dart';

/// Small tappable thumbnail of the customer's registered house/building
/// photo. Riders use this to visually confirm the exact address, since a map
/// pin alone can be off by tens of metres. Renders nothing when the customer
/// never uploaded one (older accounts, or they skipped it at registration).
class HousePhotoThumbnail extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const HousePhotoThumbnail({super.key, required this.photoUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openFullscreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _placeholder(loading: true),
        ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) => Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.home_outlined, color: Colors.grey.shade400),
      );

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('House Photo'),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
