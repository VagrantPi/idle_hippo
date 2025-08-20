import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';

class TitlesPage extends StatelessWidget {
  const TitlesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            localization.getPageName('titles'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Title system coming soon...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
