import 'package:flutter/material.dart';
import '../services/config_service.dart';

class DebugPanel extends StatefulWidget {
  const DebugPanel({super.key});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  final ConfigService _configService = ConfigService();
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || !_configService.isLoaded) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Debug Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isVisible = false),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildConfigRow('tap.base', _configService.getValue('game.tap.base')),
            _buildConfigRow('idle.base_per_sec', _configService.getValue('game.idle.base_per_sec')),
            _buildConfigRow('dailyTapCap', _configService.getValue('game.dailyTapCap')),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _reloadConfig,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Reload Config',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$key=$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Future<void> _reloadConfig() async {
    try {
      await _configService.reload();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Config reloaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Config reload failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class DebugToggleButton extends StatefulWidget {
  final VoidCallback onToggle;
  
  const DebugToggleButton({super.key, required this.onToggle});

  @override
  State<DebugToggleButton> createState() => _DebugToggleButtonState();
}

class _DebugToggleButtonState extends State<DebugToggleButton> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 10,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.bug_report,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
