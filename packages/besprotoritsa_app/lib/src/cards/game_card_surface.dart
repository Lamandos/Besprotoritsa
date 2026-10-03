import 'package:flutter/material.dart';

/// Printed-material backgrounds used by player-facing card faces.
enum GameCardMaterial {
  /// Dark bark used for monster cards.
  monster,

  /// Rust-colored bark used for event cards.
  event,

  /// Rust-colored bark used for story cards.
  story,

  /// Cool bark used for item cards.
  item,
}

/// Resolves the bundled background image for each [GameCardMaterial].
extension GameCardMaterialAsset on GameCardMaterial {
  /// Asset path of this material's background.
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
  /// Creates a clipped card surface with the selected material background.
  const GameCardSurface({
    required this.material,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.borderColor = const Color(0xFF8B683B),
    this.borderWidth = 1.5,
    this.overlayColor = Colors.transparent,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Background material used for this card.
  final GameCardMaterial material;

  /// Card content drawn above the background.
  final Widget child;

  /// Shape applied to the surface.
  final BorderRadius borderRadius;

  /// Color of the outline.
  final Color borderColor;

  /// Width of the outline.
  final double borderWidth;

  /// Optional tint drawn above the background and below the content.
  final Color overlayColor;

  /// Padding around [child].
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
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}
