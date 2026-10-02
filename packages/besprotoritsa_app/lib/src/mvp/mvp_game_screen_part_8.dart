// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

/// Decorative motion placed between the ship backdrop and the playable UI.
class _SleepingCatBackdrop extends StatelessWidget {
  const _SleepingCatBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final breath = (1 - math.cos(progress * math.pi * 2)) / 2;
    return Positioned(
      left: 358,
      right: 452,
      top: 192,
      bottom: 296,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Opacity(
                opacity: .82,
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    final candlePulse = _candleFlicker(progress);
                    final warmGlow = Color.fromRGBO(
                      255,
                      162,
                      82,
                      (.08 + candlePulse * .2) * .8,
                    );
                    return RadialGradient(
                      center: const Alignment(.92, .05),
                      radius: 1.1,
                      colors: [
                        warmGlow,
                        warmGlow.withValues(alpha: .035 * .8),
                        warmGlow.withValues(alpha: 0),
                      ],
                      stops: const [0, .52, 1],
                    ).createShader(bounds);
                  },
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: .55, sigmaY: .55),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/sleeping_black_cat_dark_room/cat_darkroom_04_burgundy_blanket.png',
                          fit: BoxFit.fill,
                        ),
                        ClipPath(
                          clipper: const _SleepingCatBackClipper(),
                          child: Transform.translate(
                            offset: Offset(0, -breath * 3),
                            child: Image.asset(
                              'assets/images/sleeping_black_cat_dark_room/cat_darkroom_04_burgundy_blanket.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepingCatBackClipper extends CustomClipper<Path> {
  const _SleepingCatBackClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .06, size.height * .5)
    ..cubicTo(
      size.width * .1,
      size.height * .33,
      size.width * .21,
      size.height * .18,
      size.width * .37,
      size.height * .16,
    )
    ..cubicTo(
      size.width * .54,
      size.height * .13,
      size.width * .68,
      size.height * .2,
      size.width * .81,
      size.height * .36,
    )
    ..cubicTo(
      size.width * .7,
      size.height * .3,
      size.width * .58,
      size.height * .25,
      size.width * .46,
      size.height * .25,
    )
    ..cubicTo(
      size.width * .3,
      size.height * .25,
      size.width * .17,
      size.height * .35,
      size.width * .06,
      size.height * .5,
    )
    ..close();

  @override
  bool shouldReclip(_SleepingCatBackClipper oldClipper) => false;
}

/// Lets the synchronized table glow spill visibly over the cat/board edge.
class _TablePulseSpillPainter extends CustomPainter {
  const _TablePulseSpillPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = _candleFlicker(progress);
    final opacity = .09 + pulse * .11;
    final rect = Rect.fromCenter(
      center: Offset(size.width * .712, size.height * .405),
      width: size.width * .8,
      height: size.height * 1.6,
    );
    final glow = const Color(0xFFFFA64D).withValues(alpha: opacity);
    final shader = RadialGradient(
      colors: [
        glow,
        glow.withValues(alpha: opacity * .35),
        glow.withValues(alpha: 0),
      ],
      stops: const [0, .42, 1],
    ).createShader(rect);

    canvas.drawOval(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_TablePulseSpillPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Low intensity radial light moving across the window and candle on the ship.
class _ShipAmbientLightPainter extends CustomPainter {
  const _ShipAmbientLightPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final candleFlicker = _candleFlicker(progress);
    _paintGlow(
      canvas,
      center: Offset(size.width * .97, size.height * .145),
      width: size.width * .16,
      height: size.height * .36,
      color: const Color(0xFFFFA64D),
      opacity: .08 + candleFlicker * .18,
    );

    final windowPulse = .5 + .5 * math.sin(phase + .8);
    _paintGlow(
      canvas,
      center: Offset(size.width * .51, size.height * .035),
      width: size.width * .48,
      height: size.height * .29,
      color: const Color(0xFF79BCEB),
      opacity: .035 + windowPulse * .035,
    );
  }

  void _paintGlow(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final glowColor = color.withValues(alpha: opacity);
    final shader = RadialGradient(
      colors: [
        glowColor,
        glowColor.withValues(alpha: opacity * .35),
        glowColor.withValues(alpha: 0),
      ],
      stops: const [0, .42, 1],
    ).createShader(rect);
    canvas.drawOval(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShipAmbientLightPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

double _candleFlicker(double progress) {
  final phase = progress * math.pi * 2;
  return .5 + .25 * math.sin(phase * 10.1) + .12 * math.sin(phase * 18.3 + .7);
}
