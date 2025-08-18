import 'package:flutter/material.dart';

void main() {
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
  int currentValue = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[50],
      body: Center(
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
                '$currentValue',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
