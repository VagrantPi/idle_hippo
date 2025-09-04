import 'package:flutter/material.dart';

class KtvSongCard extends StatelessWidget {
  final String title;
  final String imagePath; // 可為 asset
  final int lengthSeconds;
  final int easyStars;
  final int hardStars;
  final VoidCallback onTapEasy;
  final VoidCallback onTapHard;

  const KtvSongCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.lengthSeconds,
    required this.easyStars,
    required this.hardStars,
    required this.onTapEasy,
    required this.onTapHard,
  });

  String _formatLen(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Widget _buildStars(int n) {
    final count = n.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: filled ? Colors.amber : Colors.grey,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imagePath.replaceAll(
                      RegExp(r'[/\\]'),
                      '/',
                    ), // Normalize path separators
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[700],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatLen(lengthSeconds),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTapEasy,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Easy'),
                        const SizedBox(width: 6),
                        _buildStars(easyStars),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTapHard,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Hard'),
                        const SizedBox(width: 6),
                        _buildStars(hardStars),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
