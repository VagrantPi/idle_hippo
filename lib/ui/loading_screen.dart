import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idle_hippo/services/collect_sync_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/karaoke_service.dart';
import 'package:idle_hippo/services/offline_reward_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final GameStateService _gs = GameStateService();
  final ConfigService _config = ConfigService();
  final KaraokeService _karaoke = KaraokeService();
  final OfflineRewardService _offline = OfflineRewardService();

  late final AnimationController _dots;
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _boot();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final started = DateTime.now();

    // 1) 準備 Config 與 GameState
    try {
      await _config.loadConfig();
    } catch (_) {}
    try {
      await _gs.initialize();
    } catch (_) {}
    await _karaoke.ensureKaraokeBlock();
    final firstOpen = (_gs.currentState.karaoke?.collectVersion ?? 0) == 0
        ? true
        : false;

    // 2) 啟動離線獎勵檢查（在 Loading 期間）
    try {
      _offline.init(
        getIdlePerSec: () => 0.0, // 啟動時計算獎勵不使用此值
        getGameState: () => _gs.currentState,
        onPersist: (updated) async {
          await _gs.updateGameState(updated);
        },
        onOfflineReward: (_, _, {required bool canDouble}) {
          // 彈窗交由 Main 畫面處理；此處只是提前計算入帳，避免主畫面前又等待
        },
      );
      await _offline.checkNow();
    } catch (_) {}

    // 3) SWR 檢查與更新
    // 注意：ConfigService 的根是 'game' -> 'ktv'
    final url =
        _config.getValue('game.ktv.collectUrl', defaultValue: '') as String?;
    final verUrl =
        _config.getValue('game.ktv.versionUrl', defaultValue: '') as String?;
    if ((url ?? '').isNotEmpty) {
      if (firstOpen) {
        setState(() => _status = 'Checking updates…');
        try {
          await CollectSyncService(
            remoteUrl: url!,
            versionUrl: verUrl,
          ).checkAndUpdate();
        } catch (_) {}
      } else {
        // 非首次：背景更新（非阻塞）
        // 提醒狀態，但不等待
        setState(() => _status = 'Updating songs…');
        unawaited(
          CollectSyncService(
            remoteUrl: url!,
            versionUrl: verUrl,
          ).checkAndUpdate(),
        );
      }
    }

    // 4) 最小顯示 1 秒
    final elapsed = DateTime.now().difference(started);
    if (elapsed < const Duration(seconds: 1)) {
      await Future.delayed(const Duration(seconds: 1)).catchError((_) => null);
    }

    if (!mounted) return;
    // 5) 進入主畫面
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景圖
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.black),
              child: Center(
                child: Image.asset(
                  'assets/images/background/Loading.png',
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Container(),
                ),
              ),
            ),
          ),
          // 前景 Loading 文案
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FadeTransition(
                    opacity: _dots.drive(CurveTween(curve: Curves.easeIn)),
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
