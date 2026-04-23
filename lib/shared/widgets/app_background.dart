import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // orb1: top-right
        Positioned(
          top: -170,
          right: -130,
          child: Container(
            width: 400,
            height: 400,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.24, -0.24),
                radius: 0.7,
                colors: [
                  Color(0x2FFFAC33),
                  Color(0x0FFF9500),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // orb2: bottom-left
        Positioned(
          bottom: 30,
          left: -130,
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0.24, 0.24),
                radius: 0.7,
                colors: [
                  Color(0x21FF9500),
                  Color(0x0AFFAC33),
                  Colors.transparent,
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
