import 'package:flutter/material.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';

class AnimatedStatus extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const AnimatedStatus({
    super.key,
    required this.text,
    required this.icon,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey('$text$icon'),
        children: [
          Icon(icon, size: context.iconSize(14), color: color),
          SizedBox(width: context.padding(6)),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: context.fontSize(11),
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
