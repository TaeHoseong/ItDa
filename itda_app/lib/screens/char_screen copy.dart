import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CharacterPage extends StatelessWidget {
  const CharacterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // This centers a fixed-size artboard (Figma size: 393x852) on any device
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: FittedBox(
            // Keeps the design proportional if the screen is smaller/larger
            child: SizedBox(
              width: 393,
              height: 852,
              child: Stack(
                children: [
                  /// Background white full-frame layer from your last Positioned
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),

                  /// Small home indicator (bottom handle)
                  Positioned(
                    top: 838,
                    left: 130,
                    child: Container(
                      width: 134,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),

                  /// Question text block
                  Positioned(
                    top: 162,
                    left: 35,
                    child: SizedBox(
                      width: 323,
                      height: 210.573,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 33,
                            left: 29,
                            child: Text(
                              '태희 님은 잘 못 먹는 음식이 있나요?',
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                // If the custom font isn't available, fallback to default.
                                fontFamily: 'Ownglyph ryuttung',
                                fontSize: 18,
                                height: 1,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// Input pill "페르소나에게 말하기···"
                  Positioned(
                    top: 663,
                    left: 24,
                    child: SizedBox(
                      width: 346,
                      height: 45,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(227, 227, 227, 1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 10,
                            left: 30,
                            child: Text(
                              '페르소나에게 말하기···',
                              style: TextStyle(
                                fontFamily: 'SUIT',
                                fontSize: 18,
                                height: 1,
                                color: Color.fromRGBO(99, 59, 72, 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// Top-right icons row (two icons with 16px gap)
                  Positioned(
                    top: 61,
                    left: 276,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // First icon container (34x29)
                          SizedBox(
                            width: 34,
                            height: 29,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0.2657443285,
                                  left: 0,
                                  child: SizedBox(
                                    width: 34,
                                    height: 28.4685096741,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          child: SvgPicture.asset(
                                            'vector(1).svg',
                                            width: 34,
                                            height: 28.4685,
                                            fit: BoxFit.contain,
                                            semanticsLabel: 'vector',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Second icon container (29x31)
                          Container(
                            width: 29,
                            height: 31,
                            color: Colors.white,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0.5438602567,
                                  left: 0.6349848509,
                                  child: SvgPicture.asset(
                                    'assets/images/vector.svg',
                                    width: 28, // approximate
                                    height: 30,
                                    fit: BoxFit.contain,
                                    semanticsLabel: 'vector',
                                  ),
                                ),
                                Positioned(
                                  top: 11.0131578445,
                                  left: 10.0694446564,
                                  child: SvgPicture.asset(
                                    'assets/images/vector.svg',
                                    width: 9, // approximate
                                    height: 9,
                                    fit: BoxFit.contain,
                                    semanticsLabel: 'vector',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// (Center figure) — shadow ellipse + white ellipse “avatar” shape
                  Positioned(
                    top: 373,
                    left: 120,
                    child: SizedBox(
                      width: 154,
                      height: 219,
                      child: Stack(
                        children: [
                          // shadow ellipse
                          Positioned(
                            top: 200,
                            left: 25,
                            child: Container(
                              width: 103,
                              height: 19,
                              decoration: const BoxDecoration(
                                color: Color.fromRGBO(0, 0, 0, 0.25),
                                borderRadius: BorderRadius.all(
                                  // Using elliptical radius: Rx=103, Ry=19
                                  Radius.elliptical(103, 19),
                                ),
                              ),
                            ),
                          ),
                          // white ellipse (avatar/body)
                          Positioned(
                            top: 80,
                            left: 25,
                            child: Container(
                              width: 103,
                              height: 95,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.elliptical(103, 95),
                                ),
                              ),
                            ),
                          ),
                          // (Note: the original had two `null` Positioned nodes here)
                        ],
                      ),
                    ),
                  ),

                  /// Bottom sheet / navigation bar area
                  Positioned(
                    top: 762,
                    left: 0,
                    child: SizedBox(
                      width: 393,
                      height: 90,
                      child: Stack(
                        children: [
                          // Round-top white bar
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(25),
                                  topRight: Radius.circular(25),
                                ),
                              ),
                            ),
                          ),

                          // Left tab (placeholder gray box 65x49)
                          Positioned(
                            top: 7,
                            left: 24,
                            child: Container(
                              width: 65,
                              height: 49,
                              color: const Color(0xFFD9D9D9),
                            ),
                          ),

                          // Middle-left tab (white bg + SVG)
                          Positioned(
                            top: 7,
                            left: 117,
                            child: Container(
                              width: 65,
                              height: 49,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 135,
                            child: SizedBox(
                              width: 29.85,
                              height: 27.136,
                              child: SvgPicture.asset(
                                'assets/images/vector.svg',
                                fit: BoxFit.contain,
                                semanticsLabel: 'vector',
                              ),
                            ),
                          ),

                          // Middle-right tab (white bg + SVG)
                          Positioned(
                            top: 7,
                            left: 210,
                            child: Container(
                              width: 65,
                              height: 49,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 227,
                            child: SizedBox(
                              width: 31.009,
                              height: 26.992,
                              child: SvgPicture.asset(
                                'assets/images/vector.svg',
                                fit: BoxFit.contain,
                                semanticsLabel: 'vector',
                              ),
                            ),
                          ),

                          // Right tab (gray bg + two SVGs)
                          Positioned(
                            top: 7,
                            left: 303,
                            child: Container(
                              width: 65,
                              height: 49,
                              color: const Color(0xFFD9D9D9),
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 321,
                            child: SizedBox(
                              width: 30.043,
                              height: 26.962,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 9.00919,
                                    left: 6.8685,
                                    child: SvgPicture.asset(
                                      'assets/images/vector.svg',
                                      width: 16,
                                      height: 16,
                                      fit: BoxFit.contain,
                                      semanticsLabel: 'vector',
                                    ),
                                  ),
                                  Positioned(
                                    top: 1.15549,
                                    left: 1.28388,
                                    child: SvgPicture.asset(
                                      'assets/images/vector.svg',
                                      width: 12,
                                      height: 12,
                                      fit: BoxFit.contain,
                                      semanticsLabel: 'vector',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// (The Figma dump had another large full-screen white container at [0,0],
                  /// which would hide everything. We keep only one background fill at the top
                  /// so your content stays visible.)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
