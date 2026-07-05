import 'package:flutter/material.dart';

class RoundClip extends StatelessWidget {
  final Widget child;
  final double padding;

  const RoundClip({
    super.key,
    required this.child,
    this.padding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diameter = size.shortestSide;
    final radius = diameter / 2 - padding;

    return ClipPath(
      clipper: _RoundClipper(
        radius: radius,
        center: Offset(size.width / 2, size.height / 2),
      ),
      child: child,
    );
  }
}

class _RoundClipper extends CustomClipper<Path> {
  final double radius;
  final Offset center;

  _RoundClipper({required this.radius, required this.center});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_RoundClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
