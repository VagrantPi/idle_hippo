import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/game_clock_service.dart';
import '../services/idle_income_service.dart';
import '../models/game_state.dart';
import '../services/tap_service.dart';
import '../services/daily_mission_service.dart';

class DebugPanel extends StatefulWidget {
  final GameState? gameState;
  final TapService? tapService;
  final DailyMissionService? dailyMissionService;
  final Future<void> Function()? onResetAll;
  final Future<void> Function()? onOfflineSimulate60s;
  final Future<void> Function()? onOfflineClearPending;
  final VoidCallback? onForceCompleteMission;
  final VoidCallback? onSimulateDayReset;
  
  const DebugPanel({
    super.key,
    this.gameState,
    this.tapService,
    this.dailyMissionService,
    this.onResetAll,
    this.onOfflineSimulate60s,
    this.onOfflineClearPending,
    this.onForceCompleteMission,
    this.onSimulateDayReset,
  });

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  final ConfigService _configService = ConfigService();
  final GameClockService _gameClock = GameClockService();
  final IdleIncomeService _idleIncome = IdleIncomeService();
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // 限制最大高度，內容過長時允許滾動
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
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
            
            // Actions
            ElevatedButton(
              onPressed: widget.onResetAll,
              child: const Text('Reset All'),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: widget.onOfflineSimulate60s,
              child: const Text('Offline +60s'),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: widget.onOfflineClearPending,
              child: const Text('Clear Offline'),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: _resetIdleStats,
              child: const Text('Reset Idle Stats'),
            ),
            if (widget.onForceCompleteMission != null) ...[
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: widget.onForceCompleteMission,
                child: const Text('Complete Mission'),
              ),
            ],
            if (widget.onSimulateDayReset != null) ...[
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: widget.onSimulateDayReset,
                child: const Text('Simulate Day Reset'),
              ),
            ],
            
            // Config Section
            if (_configService.isLoaded) ...[
              _buildSectionTitle('Config'),
              _buildConfigRow('tap.base', _configService.getValue('game.tap.base')),
              _buildConfigRow('tap.base_gain', _configService.getValue('game.tap.base_gain')),
              _buildConfigRow('tap.daily_cap_base', _configService.getValue('game.tap.daily_cap_base')),
              _buildConfigRow('idle.base_per_sec', _configService.getValue('game.idle.base_per_sec')),
              const SizedBox(height: 8),
            ],
            
            // Game State Section
            if (widget.gameState != null) ...[
              _buildSectionTitle('Game State'),
              _buildConfigRow('saveVersion', widget.gameState!.saveVersion),
              _buildConfigRow('memePoints', widget.gameState!.memePoints),
              _buildConfigRow('equipments', widget.gameState!.equipments.length),
              _buildConfigRow('lastTs', _formatTimestamp(widget.gameState!.lastTs)),
              const SizedBox(height: 8),
            ],

            // Offline Section
            if (widget.gameState != null) ...[
              _buildSectionTitle('Offline'),
              _buildConfigRow('offline.lastExitUtcMs', widget.gameState!.offline.lastExitUtcMs),
              _buildConfigRow('offline.idle_rate_snapshot', widget.gameState!.offline.idleRateSnapshot),
              _buildConfigRow('offline.pendingReward', widget.gameState!.offline.pendingReward),
              _buildConfigRow('offline.capHours', widget.gameState!.offline.capHours),
              const SizedBox(height: 8),
            ],

            // GameClock Section
            _buildSectionTitle('GameClock'),
            _buildGameClockStats(),
            const SizedBox(height: 8),

            // IdleIncome Section
            _buildSectionTitle('IdleIncome'),
            _buildIdleIncomeStats(),
            const SizedBox(height: 8),

            // Daily Mission Section
            if (widget.dailyMissionService != null && widget.gameState != null) ...[
              _buildSectionTitle('Daily Mission'),
              _buildDailyMissionStats(),
              const SizedBox(height: 8),
            ],
            
            // Actions
            _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConfigRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '$key=$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildGameClockStats() {
    final stats = _gameClock.getStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigRow('fps', stats['currentFps']?.toStringAsFixed(1) ?? '0.0'),
        _buildConfigRow('avgDelta(ms)', stats['averageDeltaMs']?.toStringAsFixed(1) ?? '0.0'),
        _buildConfigRow('state', _gameClock.lifecycleState),
        _buildConfigRow('subscribers', stats['subscribersCount']),
        _buildConfigRow('isRunning', stats['isRunning']),
        _buildConfigRow('fixedStep', stats['isFixedStepMode']),
      ],
    );
  }

  Widget _buildIdleIncomeStats() {
    final stats = _idleIncome.getStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigRow('idlePerSec', stats['currentIdlePerSec']),
        _buildConfigRow('totalTime(s)', stats['totalIdleTime']?.toStringAsFixed(1) ?? '0.0'),
        _buildConfigRow('totalIncome', stats['totalIdleIncome']?.toStringAsFixed(2) ?? '0.0'),
        _buildConfigRow('avgIncome/s', stats['averageIncomePerSec']?.toStringAsFixed(3) ?? '0.0'),
        _buildConfigRow('subscribed', stats['isSubscribed']),
      ],
    );
  }

  Widget _buildTapStats() {
    final stats = widget.tapService!.getStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigRow('basePoints', stats['basePoints']),
        _buildConfigRow('cooldownSeconds', stats['cooldownSeconds']),
        _buildConfigRow('tap.total', stats['totalTapEvents']),
        _buildConfigRow('tap.accepted', stats['acceptedTapEvents']),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Reload Config Button
        GestureDetector(
          onTap: _reloadConfig,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
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
        
        // Toggle Fixed Step Mode Button
        GestureDetector(
          onTap: _toggleFixedStepMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: _gameClock.getStats()['isFixedStepMode'] == true 
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _gameClock.getStats()['isFixedStepMode'] == true 
                  ? 'Disable Fixed Step' 
                  : 'Enable Fixed Step',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Reset Idle Stats Button
        GestureDetector(
          onTap: _resetIdleStats,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Reset Idle Stats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Offline: +60s
        if (widget.onOfflineSimulate60s != null)
          GestureDetector(
            onTap: () async {
              await widget.onOfflineSimulate60s!();
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '+60s Offline',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // Offline: Clear Pending
        if (widget.onOfflineClearPending != null)
          GestureDetector(
            onTap: () async {
              await widget.onOfflineClearPending!();
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Clear Pending',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // Reset All State Button
        GestureDetector(
          onTap: () async {
            if (widget.onResetAll != null) {
              await widget.onResetAll!();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All state reset'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Reset All State',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
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

  void _toggleFixedStepMode() {
    final isCurrentlyFixed = _gameClock.getStats()['isFixedStepMode'] == true;
    _gameClock.setFixedStepMode(!isCurrentlyFixed, fixedDelta: 0.05); // 20fps for testing
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCurrentlyFixed 
              ? 'Fixed step mode disabled' 
              : 'Fixed step mode enabled (20fps)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDailyMissionStats() {
    if (widget.gameState?.dailyMission == null) {
      return const Text(
        'No mission data',
        style: TextStyle(color: Colors.white70, fontSize: 10),
      );
    }

    final mission = widget.gameState!.dailyMission!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigRow('date', mission.date),
        _buildConfigRow('index', mission.index),
        _buildConfigRow('type', mission.type),
        _buildConfigRow('progress', mission.progress.toStringAsFixed(0)),
        _buildConfigRow('target', mission.target.toStringAsFixed(0)),
        _buildConfigRow('snapshot', mission.idlePerSecSnapshot.toStringAsFixed(2)),
        _buildConfigRow('completed', mission.todayCompleted),
      ],
    );
  }

  void _resetIdleStats() {
    _idleIncome.resetStats();
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Idle stats reset'),
          duration: Duration(seconds: 2),
        ),
      );
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
