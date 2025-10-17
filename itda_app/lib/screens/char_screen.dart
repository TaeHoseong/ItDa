import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key, required this.bubbleText, this.onSpeakTap});

  final String bubbleText;
  final VoidCallback? onSpeakTap;

  @override
  Widget build(BuildContext context) {
    // (optional) remove this if unused to avoid warning
    // final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final bubbleMaxWidth = size.width * 0.82; // responsive max width for bubble

    return SafeArea(
          // Main content
          child: Column(
            children: [
              const SizedBox(height: 8),
              // _TopBar(),
              const SizedBox(height: 16),

              // Speech bubble
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: bubbleMaxWidth,
                    ),
                    child: _SpeechBubble(
                      text: bubbleText,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Mascot (placeholder circle — replace with your SVG/PNG if available)
              const _Mascot(),

              const SizedBox(height: 28),

              // Input pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SpeakPill(
                  hint: "페르소나에게 말하기 · · ·",
                  onTap: onSpeakTap,
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          const Spacer(),
          // Hanger icon
          _IconButtonSvg(
            assetPath: 'assets/icons/hanger.svg',
            semanticLabel: 'Wardrobe',
            onTap: () {},
          ),
          const SizedBox(width: 20),
          // Gear icon
          _IconButtonSvg(
            assetPath: 'assets/icons/gear.svg',
            semanticLabel: 'Settings',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _IconButtonSvg extends StatelessWidget {
  const _IconButtonSvg({
    required this.assetPath,
    required this.semanticLabel,
    this.onTap,
  });

  final String assetPath;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: SvgPicture.asset(
        assetPath,
        width: 28,
        height: 28,
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
        semanticsLabel: semanticLabel,
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Shadow
        Container(
          margin: const EdgeInsets.only(top: 8, left: 4, right: 4),
          height: 0,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        // Bubble body
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: _BubbleBorder(radius: 28),
            shadows: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),
        // Tail (outside bottom-left)
        Positioned(
          left: 40,
          bottom: -20,
          child: CustomPaint(
            size: const Size(36, 28),
            painter: _TailPainter(color: Colors.white, shadow: false),
          ),
        ),
      ],
    );
  }
}

/// Rounded rectangle with a small inward rounding so the custom tail can attach nicely.
class _BubbleBorder extends RoundedRectangleBorder {
  _BubbleBorder({required double radius})
      : super(borderRadius: BorderRadius.all(Radius.circular(radius)));
}

class _TailPainter extends CustomPainter {
  _TailPainter({required this.color, this.shadow = false});

  final Color color;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.40, size.height * 0.25, size.width * 0.55, size.height * 0.02)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.35, size.width * 0.98, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.70, size.width * 0.22, size.height * 0.98)
      ..close();

    if (shadow) {
       final blurPaint = Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6); // sigma
      canvas.save();
      canvas.translate(0, 2); // drop-shadow offset
      canvas.drawPath(path, blurPaint);
      canvas.restore();
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    // You can replace this with your SVG: SvgPicture.asset('assets/mascot.svg', width: 180)
    return Column(
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBEADB), Color(0xFFF1A396)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 128,
              height: 106,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(64),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  // Eyes
                  Positioned(
                    left: 42,
                    child: _Dot(size: 6),
                  ),
                  Positioned(
                    right: 42,
                    child: _Dot(size: 6),
                  ),
                  // Nose
                  Positioned(
                    bottom: 42,
                    child: _Nose(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Subtle ground shadow ellipse
        Container(
          width: 190,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Nose extends StatelessWidget {
  const _Nose();
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45 degrees
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFFF8A80),
        ),
      ),
    );
  }
}

class _SpeakPill extends StatelessWidget {
  const _SpeakPill({required this.hint, this.onTap});
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          hint,
          style: const TextStyle(
            color: Color(0xFF6F6A6A),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}