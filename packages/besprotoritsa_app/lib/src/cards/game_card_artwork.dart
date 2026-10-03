import 'package:flutter/material.dart';

/// Artwork types extracted from the printable card sheets in `materials/`.
enum GameCardArtworkKind {
  item,
  special,
  supply,
  monster,
  condition,
  event,
  quest,
  task,
}

/// Resolves a content ID to its matching scanned card face, when one exists.
String? gameCardArtworkAsset(
  String cardId, {
  GameCardArtworkKind? kind,
}) {
  final resolvedKind = kind ?? gameCardArtworkKindForId(cardId);
  if (resolvedKind == null) return null;
  final prefix = switch (resolvedKind) {
    GameCardArtworkKind.item => 'item',
    GameCardArtworkKind.special => 'special',
    GameCardArtworkKind.supply => 'supply',
    GameCardArtworkKind.monster => 'monster',
    GameCardArtworkKind.condition => 'condition',
    GameCardArtworkKind.event => 'event',
    GameCardArtworkKind.quest => 'quest',
    GameCardArtworkKind.task => 'task',
  };
  return 'assets/images/card-art/$prefix-$cardId.webp';
}

GameCardArtworkKind? gameCardArtworkKindForId(String cardId) {
  if (_itemIds.contains(cardId)) return GameCardArtworkKind.item;
  if (_specialItemIds.contains(cardId)) return GameCardArtworkKind.special;
  if (_supplyIds.contains(cardId)) return GameCardArtworkKind.supply;
  if (_monsterIds.contains(cardId)) return GameCardArtworkKind.monster;
  if (_conditionIds.contains(cardId)) return GameCardArtworkKind.condition;
  return null;
}

/// Resolves the close crop used for circular monster tokens on the board.
String? gameMonsterTokenArtworkAsset(String monsterId) =>
    _monsterIds.contains(monsterId)
    ? 'assets/images/card-art/monster-art-$monsterId.webp'
    : null;

/// Opens a scanned card face at a readable size without cropping its layout.
Future<void> showGameCardScan(
  BuildContext context, {
  required String cardId,
  required String title,
  GameCardArtworkKind? kind,
}) async {
  final asset = gameCardArtworkAsset(cardId, kind: kind);
  if (asset == null) return;
  final screen = MediaQuery.sizeOf(context);
  final maxWidth = screen.width - 48;
  final heightLimitedWidth = (screen.height - 88) * 445 / 619;
  final cardWidth =
      (maxWidth < heightLimitedWidth ? maxWidth : heightLimitedWidth)
          .clamp(160, 430)
          .toDouble();
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF211A15),
      insetPadding: const EdgeInsets.all(20),
      child: Semantics(
        label: title,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: cardWidth,
            child: AspectRatio(
              aspectRatio: 445 / 619,
              child: GameCardArtwork(
                cardId: cardId,
                assetPath: asset,
                width: cardWidth,
                height: cardWidth * 619 / 445,
                fit: BoxFit.contain,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Displays a matching card scan or a themed icon when a scan is unavailable.
class GameCardArtwork extends StatelessWidget {
  const GameCardArtwork({
    required this.cardId,
    this.kind,
    this.width = 52,
    this.height = 72,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.fallbackIcon = Icons.style_outlined,
    this.assetPath,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String cardId;
  final GameCardArtworkKind? kind;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final String? assetPath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = assetPath ?? gameCardArtworkAsset(cardId, kind: kind);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: asset == null
            ? ColoredBox(
                color: const Color(0xFF33271B),
                child: Icon(fallbackIcon, color: const Color(0xFFD0A66D)),
              )
            : Image.asset(asset, fit: fit),
      ),
    );
  }
}

const _itemIds = <String>{
  'circular-saw',
  'laser-cutter',
  'exo-gloves',
  'pneumo-cannon',
  'nailgun',
  'flamethrower',
  'knife',
  'ultrasonic-hammer',
  'spacesuit',
  'frying-pan',
  'last-chance',
  'load-bearing-vest',
  'engineer-coveralls',
  'laser-scalpel',
  'pipe-wrench',
  'guard-suit',
  'tank-top',
  'camouflage',
  'shirt',
  'coveralls',
  'lab-coat',
  't-shirt',
  'shooter-helmet',
  'hauler-uniform',
  'implant-agility',
  'implant-endurance',
  'implant-repair',
  'armor-vest',
  'implant-science',
  'implant-strength',
  'laboratory-suit',
  'ghb-dtn',
  'r69-nic3',
  'gtu-b1c4',
  'c6-car-courier',
  'sc0-u7',
  'prot2-ct',
  'alarm-bot',
  'sc13-nc3',
  'f1t-b07',
  'prot3-ct',
  'h3-al',
  'pipe',
  'brass-knuckles',
  'helmet',
  'makeshift-armor',
  'welding-mask',
  'cleaver',
  'lucky-socks',
  'spacesuit-mk2',
  'gu4-rd',
  'medic-bag',
  'hard-hat',
  'backpack',
  'pistol',
  'smuggler-mark',
};

const _specialItemIds = <String>{
  'old-cloak',
  'assault-rifle',
  'shotgun',
  'drg-4u',
  'swiss-army-knife',
  'exoskeleton',
  'plague-doctor-mask',
};

const _supplyIds = <String>{
  'nanobots',
  'air-canister',
  'adrenaline-supply',
  'credits',
  'defibrillator',
  'stash',
  'dry-rations',
  'tripwire',
  'gas-cylinder',
  'door-remote',
  'proton-shield',
  'water',
  'adrenaline-x',
  'power-cell',
  'science-stimulant',
  'agility-stimulant',
  'endurance-stimulant',
  'repair-stimulant',
  'strength-stimulant',
  'flashlight',
  'medkit',
  'ration',
};

const _monsterIds = <String>{
  'restless',
  'volot',
  'drekovac',
  'vurdalak',
  'plagued',
  'likho',
  'nest',
  'pack',
  'werewolf',
  'ghoul',
  'seeker',
  'mother',
  'viy',
  'swarm',
  'leshy',
  'boil',
};

const _conditionIds = <String>{
  'malaise',
  'concussion',
  'nausea',
  'fracture',
  'shortness-of-breath',
  'adrenaline',
};
