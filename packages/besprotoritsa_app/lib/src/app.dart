import 'package:besprotoritsa_app/src/content/content_review_screen.dart';
import 'package:besprotoritsa_app/src/mvp/mvp_game_screen.dart';
import 'package:flutter/material.dart';

/// Root widget for the Besprotoritsa application.
class BesprotoritsaApp extends StatelessWidget {
  /// Creates the application root.
  const BesprotoritsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Беспроторица',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

/// First screen shown while the MVP is being assembled.
class StartScreen extends StatelessWidget {
  /// Creates the MVP start screen.
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Беспроторица',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '0.1.0-dev',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Align(
                  child: Chip(
                    avatar: Icon(Icons.person),
                    label: Text('Одиночная игра / Локально'),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const MvpGameScreen(),
                    ),
                  ),
                  child: const Text('Запуск MVP (Демо)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const InternalDevMenuScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Внутреннее dev-меню'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal-only utilities that are intentionally separate from the game UI.
class InternalDevMenuScreen extends StatelessWidget {
  /// Creates the internal development menu.
  const InternalDevMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Внутреннее dev-меню')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Аудит контента'),
            subtitle: const Text(
              'Изображение, JSON, локализация, behaviorId и тесты',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (context) => const ContentReviewScreen(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
