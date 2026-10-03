import 'package:flutter/material.dart';

/// Printed-material backgrounds used by player-facing card faces.
enum GameCardMaterial { monster, event, story, item }

extension GameCardMaterialAsset on GameCardMaterial {
  String get assetPath => switch (this) {
    GameCardMaterial.monster =>
      'assets/images/card-backgrounds/beresta-smoked.png',
    GameCardMaterial.event ||
    GameCardMaterial.story => 'assets/images/card-backgrounds/beresta-rust.png',
    GameCardMaterial.item => 'assets/images/card-backgrounds/beresta-cold.png',
  };
}

/// A clipped card surface with its assigned birch-bark background.
class GameCardSurface extends StatelessWidget {
  const GameCardSurface({
    required this.material,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.borderColor = const Color(0xFF8B683B),
    this.borderWidth = 1.5,
    this.overlayColor = Colors.transparent,
    this.padding = EdgeInsets.zero,
  });

  final GameCardMaterial material;
  final Widget child;
  final BorderRadius borderRadius;
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage(material.assetPath),
        fit: BoxFit.cover,
      ),
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: ColoredBox(
      color: overlayColor,
      child: Padding(padding: padding, child: child),
    ),
  );
}
