import 'package:flutter/material.dart';

class SignalBars extends StatelessWidget {
  final int rssi;
  final double size;

  const SignalBars({
    super.key,
    required this.rssi,
    this.size = 12,
  });

  int get _bars {
    if (rssi >= -50) return 5;
    if (rssi >= -65) return 4;
    if (rssi >= -80) return 3;
    if (rssi >= -90) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isActive = i < bars;
        return Container(
          width: size * 0.35,
          height: size * (0.3 + i * 0.18),
          margin: EdgeInsets.only(right: size * 0.15),
          decoration: BoxDecoration(
            color: isActive
                ? bars > 3
                    ? Colors.green
                    : bars > 1
                        ? Colors.amber
                        : Colors.red
                : Colors.white24,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
