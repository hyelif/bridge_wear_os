import 'package:flutter/material.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';

class MessageBubble extends StatelessWidget {
  final BridgeMessage message;
  final bool isOutgoing;

  const MessageBubble({
    super.key,
    required this.message,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final payload = message.payload;
    final text = payload.containsKey('title') && payload.containsKey('body')
        ? '${payload['title']}: ${payload['body']}'
        : payload.toString();
    final time =
        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.padding(2),
        horizontal: context.padding(4),
      ),
      child: Row(
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOutgoing) ...[
            Container(
              width: context.iconSize(20),
              height: context.iconSize(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_iphone,
                  size: context.iconSize(10), color: Colors.blue),
            ),
            SizedBox(width: context.padding(4)),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(context.padding(8)),
              decoration: BoxDecoration(
                color: isOutgoing
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomLeft: isOutgoing ? null : Radius.zero,
                  bottomRight: isOutgoing ? Radius.zero : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(fontSize: context.fontSize(10)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.padding(2)),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: context.fontSize(7),
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOutgoing) SizedBox(width: context.padding(4)),
        ],
      ),
    );
  }
}
