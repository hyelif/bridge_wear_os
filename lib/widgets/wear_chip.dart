import 'package:flutter/material.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';

class WearChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;

  const WearChip({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: context.buttonHeight(40),
      child: Material(
        color: chipColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: chipColor.withValues(alpha: 0.3),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.padding(12),
              vertical: context.padding(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: context.iconSize(14),
                    height: context.iconSize(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: chipColor,
                    ),
                  )
                else
                  Icon(icon, size: context.iconSize(16), color: chipColor),
                SizedBox(width: context.padding(6)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: context.fontSize(12),
                    fontWeight: FontWeight.w600,
                    color: chipColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
