import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:bridge_wear_os/utils/responsive_utils.dart';
import 'package:bridge_wear_os/widgets/signal_bars.dart';

class DeviceCard extends StatelessWidget {
  final fbp.BluetoothDevice device;
  final int? rssi;
  final bool isConnecting;
  final bool isSelected;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.rssi,
    this.isConnecting = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown';
    final isBridge = name.toLowerCase().contains('bridge') ||
        name.toLowerCase().contains('iphone');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(
        horizontal: context.padding(4),
        vertical: context.padding(3),
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnecting ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(context.padding(10)),
            child: Row(
              children: [
                // Device icon
                Container(
                  width: context.iconSize(32),
                  height: context.iconSize(32),
                  decoration: BoxDecoration(
                    color: isBridge
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBridge ? Icons.phone_iphone : Icons.devices,
                    size: context.iconSize(16),
                    color: isBridge ? Colors.green : Colors.blue,
                  ),
                ),
                SizedBox(width: context.padding(10)),
                // Name + ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isBridge)
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'BRIDGE',
                                style: TextStyle(
                                  fontSize: context.fontSize(7),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: context.fontSize(12),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.padding(2)),
                      Text(
                        device.remoteId.str.substring(0, 8),
                        style: TextStyle(
                          fontSize: context.fontSize(8),
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                // RSSI + connection indicator
                if (rssi != null) ...[
                  SignalBars(rssi: rssi!, size: context.iconSize(10)),
                  SizedBox(width: context.padding(6)),
                ],
                if (isConnecting)
                  SizedBox(
                    width: context.iconSize(14),
                    height: context.iconSize(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    size: context.iconSize(16),
                    color: Colors.white24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
