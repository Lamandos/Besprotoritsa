// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/game/multiplayer_game_controller.dart';
import 'package:besprotoritsa_app/src/game/multiplayer_lobby_client.dart';
import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/mvp/mvp_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry screen for creating a room or joining one with its five-letter code.
class MultiplayerEntryScreen extends StatefulWidget {
  const MultiplayerEntryScreen({super.key});

  @override
  State<MultiplayerEntryScreen> createState() => _MultiplayerEntryScreenState();
}

class _MultiplayerEntryScreenState extends State<MultiplayerEntryScreen> {
  final _server = TextEditingController(text: 'http://localhost:8080');
  final _room = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _server.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сетевая игра')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const ValueKey<String>('multiplayer-server-url'),
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Адрес сервера',
              hintText: 'http://localhost:8080',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey<String>('create-room-button'),
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Создать комнату'),
          ),
          const SizedBox(height: 32),
          const Text('Присоединиться по коду'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('join-room-code'),
            controller: _room,
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
            decoration: const InputDecoration(labelText: 'Код комнаты'),
          ),
          FilledButton.tonal(
            key: const ValueKey<String>('join-room-button'),
            onPressed: _busy ? null : _join,
            child: const Text('Присоединиться'),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),
  );

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final serverUri = _serverUri();
      final code = await MultiplayerLobbyClient.createRoom(
        serverUri: serverUri,
        initialState: createMvpGameState(),
      );
      if (mounted) _openLobby(serverUri, code);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _join() {
    final code = _room.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}$').hasMatch(code)) {
      _showError(const FormatException('Введите пятибуквенный код комнаты.'));
      return;
    }
    _openLobby(_serverUri(), code);
  }

  Uri _serverUri() {
    final uri = Uri.tryParse(_server.text.trim());
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Укажите полный адрес сервера.');
    }
    return uri;
  }

  void _openLobby(Uri serverUri, String roomCode) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MultiplayerLobbyScreen(
        serverUri: serverUri,
        roomCode: roomCode,
        participantId: _newParticipantId(),
      ),
    ),
  );

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }
}

/// Synchronised lobby with free-character selection and readiness state.
class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({
    required this.serverUri,
    required this.roomCode,
    required this.participantId,
    super.key,
  });

  final Uri serverUri;
  final String roomCode;
  final String participantId;

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late final MultiplayerLobbyClient _client;
  LobbySnapshot? _snapshot;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _client = MultiplayerLobbyClient(
      serverUri: widget.serverUri,
      roomCode: widget.roomCode,
      participantId: widget.participantId,
    );
    _client.snapshots.listen(
      (snapshot) => mounted ? setState(() => _snapshot = snapshot) : null,
      onError: (Object error) =>
          mounted ? setState(() => _error = error) : null,
    );
    _client.connect().catchError((Object error) {
      if (mounted) setState(() => _error = error);
    });
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Лобби комнаты')),
      body: SafeArea(
        child: snapshot == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text('$_error'),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Код комнаты: ${snapshot.roomCode}',
                    key: const ValueKey<String>('room-code'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Передайте этот код другим игрокам. Готовы: '
                    '${snapshot.participants.where((member) => member.ready).length}/${snapshot.participants.length}',
                  ),
                  const SizedBox(height: 20),
                  const Text('Свободные персонажи'),
                  const SizedBox(height: 8),
                  for (final hero in snapshot.heroes)
                    _HeroChoice(
                      hero: hero,
                      owner: _owner(snapshot, hero.id),
                      selfId: widget.participantId,
                      onSelect: () => _client.selectHero(hero.id),
                    ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    key: const ValueKey<String>('lobby-ready-switch'),
                    value: _self(snapshot)?.ready ?? false,
                    onChanged: (ready) => _client.setReady(ready),
                    title: const Text('Я готов'),
                  ),
                  if (snapshot.started)
                    FilledButton(
                      key: const ValueKey<String>('start-network-game-button'),
                      onPressed: _startGame,
                      child: const Text('Начать игру'),
                    )
                  else
                    const Text('Нужно минимум два игрока, готовых к старту.'),
                ],
              ),
      ),
    );
  }

  LobbyParticipant? _owner(LobbySnapshot snapshot, String heroId) => snapshot
      .participants
      .where((member) => member.heroId == heroId)
      .firstOrNull;

  LobbyParticipant? _self(LobbySnapshot snapshot) => snapshot.participants
      .where((member) => member.participantId == widget.participantId)
      .firstOrNull;

  Future<void> _startGame() async {
    await _client.close();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiplayerGameSessionScreen(
          serverUri: widget.serverUri,
          roomCode: widget.roomCode,
          participantId: widget.participantId,
        ),
      ),
    );
  }
}

class _HeroChoice extends StatelessWidget {
  const _HeroChoice({
    required this.hero,
    required this.owner,
    required this.selfId,
    required this.onSelect,
  });

  final LobbyHero hero;
  final LobbyParticipant? owner;
  final String selfId;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final mine = owner?.participantId == selfId;
    return Card(
      child: ListTile(
        title: Text(hero.characterId),
        subtitle: Text(
          owner == null
              ? 'Свободен'
              : mine
              ? 'Вы выбрали'
              : 'Занят',
        ),
        trailing: mine ? const Icon(Icons.check_circle) : null,
        enabled: owner == null || mine,
        onTap: owner == null || mine ? onSelect : null,
      ),
    );
  }
}

/// Game route that installs a network controller while reusing all game UI.
class MultiplayerGameSessionScreen extends StatelessWidget {
  const MultiplayerGameSessionScreen({
    required this.serverUri,
    required this.roomCode,
    required this.participantId,
    super.key,
  });

  final Uri serverUri;
  final String roomCode;
  final String participantId;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      gameControllerProvider.overrideWith(
        () => MultiplayerGameController(
          serverUri: serverUri,
          roomCode: roomCode,
          participantId: participantId,
        ),
      ),
    ],
    child: const MvpGameScreen(),
  );
}

String _newParticipantId() =>
    'player-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
