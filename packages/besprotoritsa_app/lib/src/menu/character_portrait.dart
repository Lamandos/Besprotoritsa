// The portrait map is intentionally limited to entries cleared in the asset
// rights register. Add portraits by stable character id when rights allow it.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_app/src/theme/besprotoritsa_theme.dart';
import 'package:flutter/material.dart';

const Map<String, String> characterPortraitAssets = <String, String>{
  'scientist': 'assets/images/character-portraits/scientist.png',
  'guard': 'assets/images/character-portraits/guard.png',
  'mechanic': 'assets/images/character-portraits/worker.png',
  'worker': 'assets/images/character-portraits/mechanic.png',
  'hauler': 'assets/images/character-portraits/hauler.png',
  'healer': 'assets/images/character-portraits/healer.png',
  'engineer': 'assets/images/character-portraits/astronaut.png',
  'astronaut': 'assets/images/character-portraits/engineer.png',
};

class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    required this.characterId,
    required this.size,
    this.circle = false,
    this.borderColor = BesprotoritsaTheme.bronze,
    super.key,
  });

  final String characterId;
  final Size size;
  final bool circle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final asset = characterPortraitAssets[characterId];
    final fallback = ColoredBox(
      color: const Color(0xFF34291F),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: size.shortestSide * .5,
          color: const Color(0xFFD8C7A8),
        ),
      ),
    );
    final image = asset == null
        ? fallback
        : Image.asset(
            asset,
            width: size.width,
            height: size.height,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          );
    return Semantics(
      label: asset == null
          ? '${fullRuntimeCharacterName(characterId)} · '
                '${AppStrings.of(context).portraitUnavailable}'
          : fullRuntimeCharacterName(characterId),
      image: true,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(8),
          color: const Color(0xFF34291F),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: circle
            ? ClipOval(child: image)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: image,
              ),
      ),
    );
  }
}
