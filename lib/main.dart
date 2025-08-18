import 'package:flutter/material.dart';
import 'services/config_service.dart';
import 'ui/debug_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化配置服務
  final configService = ConfigService();
  await configService.loadConfig();
  
  runApp(const IdleHippoApp());
}

class IdleHippoApp extends StatelessWidget {
  const IdleHippoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Hippo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const IdleHippoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IdleHippoScreen extends StatefulWidget {
  const IdleHippoScreen({super.key});

  @override
  State<IdleHippoScreen> createState() => _IdleHippoScreenState();
}

class _IdleHippoScreenState extends State<IdleHippoScreen> {
  final ConfigService _configService = ConfigService();
  int _currentValue = 0;
  bool _showDebugPanel = true;

  @override
  void initState() {
    super.initState();
    _initializeFromConfig();
  }

  void _initializeFromConfig() {
    if (_configService.isLoaded) {
      // 從配置檔讀取初始值
      final initialValue = _configService.getValue('game.initial_value', defaultValue: 0);
      setState(() {
        _currentValue = initialValue;
      });
      
      // 檢查是否顯示 debug 面板
      final showDebug = _configService.getValue('game.ui.showDebugPanel', defaultValue: true);
      setState(() {
        _showDebugPanel = showDebug;
      });
    }
  }

  void _toggleDebugPanel() {
    setState(() {
      _showDebugPanel = !_showDebugPanel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[50],
      body: Stack(
        children: [
          // 主要內容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game Title
                Text(
                  'Idle Hippo',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 60),
                // Current Value Display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_currentValue',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Config Status
                if (_configService.isLoaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Config Loaded ✓',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Debug Toggle Button
          DebugToggleButton(onToggle: _toggleDebugPanel),
          // Debug Panel
          if (_showDebugPanel) const DebugPanel(),
        ],
      ),
    );
  }
}
