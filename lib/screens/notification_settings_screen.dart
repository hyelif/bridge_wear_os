import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';
import 'package:bridge_wear_os/providers/bluetooth_provider.dart';
import 'package:bridge_wear_os/widgets/wear_chip.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifService = ref.watch(notificationServiceProvider);
    final bluetoothService = ref.watch(bluetoothServiceProvider);

    // Common iPhone apps list
    final commonApps = [
      {'bundleId': 'com.apple.MobileSMS', 'name': 'Messages', 'icon': Icons.message},
      {'bundleId': 'com.apple.mobilemail', 'name': 'Mail', 'icon': Icons.mail},
      {'bundleId': 'com.apple.mobilephone', 'name': 'Phone', 'icon': Icons.phone},
      {'bundleId': 'com.apple.mobilesafari', 'name': 'Safari', 'icon': Icons.language},
      {'bundleId': 'com.apple.mobilecal', 'name': 'Calendar', 'icon': Icons.calendar_today},
      {'bundleId': 'com.apple.reminders', 'name': 'Reminders', 'icon': Icons.check_circle},
      {'bundleId': 'com.apple.mobilenotes', 'name': 'Notes', 'icon': Icons.note},
      {'bundleId': 'com.apple.camera', 'name': 'Camera', 'icon': Icons.camera_alt},
      {'bundleId': 'com.apple.photos', 'name': 'Photos', 'icon': Icons.photo},
      {'bundleId': 'com.apple.weather', 'name': 'Weather', 'icon': Icons.wb_sunny},
      {'bundleId': 'com.apple.mobilemusic', 'name': 'Music', 'icon': Icons.music_note},
      {'bundleId': 'com.apple.Podcasts', 'name': 'Podcasts', 'icon': Icons.podcasts},
      {'bundleId': 'com.apple.news', 'name': 'News', 'icon': Icons.article},
      {'bundleId': 'com.apple.Health', 'name': 'Health', 'icon': Icons.favorite},
      {'bundleId': 'com.apple.mobilemaps', 'name': 'Maps', 'icon': Icons.map},
      {'bundleId': 'com.apple.mobiletimer', 'name': 'Clock', 'icon': Icons.access_time},
      {'bundleId': 'com.apple.mobileme', 'name': 'Find My', 'icon': Icons.location_searching},
      {'bundleId': 'com.apple.Preferences', 'name': 'Settings', 'icon': Icons.settings},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Notification Apps', style: TextStyle(fontSize: context.fontSize(14))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Allow all toggle
            Padding(
              padding: EdgeInsets.all(context.padding(12)),
              child: Container(
                padding: EdgeInsets.all(context.padding(10)),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.padding(8)),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.toggle_on, size: context.iconSize(18), color: Colors.blue),
                    SizedBox(width: context.padding(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allow All Apps',
                            style: TextStyle(
                              fontSize: context.fontSize(11),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            notifService.allowAll
                                ? 'All notifications will be forwarded'
                                : 'Only selected apps will forward',
                            style: TextStyle(
                              fontSize: context.fontSize(8),
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: notifService.allowAll,
                      onChanged: (val) {
                        if (val) {
                          notifService.updateAllowedApps([]);
                        }
                        // If turning off, enable all apps by default
                        if (!val && notifService.allowedApps.isEmpty) {
                          notifService.updateAllowedApps(
                            commonApps.map((a) => a['bundleId'] as String).toList(),
                          );
                        }
                      },
                      activeTrackColor: Colors.blue,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            if (!notifService.allowAll)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.padding(12)),
                child: Text(
                  'Toggle which iPhone apps can send notifications to your watch',
                  style: TextStyle(
                    fontSize: context.fontSize(9),
                    color: Colors.white38,
                  ),
                ),
              ),

            SizedBox(height: context.padding(4)),

            // App list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: context.padding(8)),
                itemCount: commonApps.length,
                itemBuilder: (context, index) {
                  final app = commonApps[index];
                  final bundleId = app['bundleId'] as String;
                  final name = app['name'] as String;
                  final icon = app['icon'] as IconData;
                  final isAllowed = notifService.isAppAllowed(bundleId);

                  return Container(
                    margin: EdgeInsets.symmetric(
                      vertical: context.padding(2),
                      horizontal: context.padding(4),
                    ),
                    decoration: BoxDecoration(
                      color: isAllowed
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAllowed
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => notifService.toggleApp(bundleId),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(context.padding(10)),
                          child: Row(
                            children: [
                              Container(
                                width: context.iconSize(28),
                                height: context.iconSize(28),
                                decoration: BoxDecoration(
                                  color: isAllowed
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  size: context.iconSize(14),
                                  color: isAllowed ? Colors.green : Colors.white38,
                                ),
                              ),
                              SizedBox(width: context.padding(10)),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: context.fontSize(12),
                                    fontWeight: FontWeight.w500,
                                    color: isAllowed ? Colors.white : Colors.white54,
                                  ),
                                ),
                              ),
                              Icon(
                                isAllowed ? Icons.check_circle : Icons.circle_outlined,
                                size: context.iconSize(16),
                                color: isAllowed ? Colors.green : Colors.white24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Sync button
            Padding(
              padding: EdgeInsets.all(context.padding(12)),
              child: WearChip(
                icon: Icons.sync,
                label: 'Sync Settings to iPhone',
                onPressed: () {
                  // Send allowlist to iPhone via BLE
                  bluetoothService.sendMessage('config', {
                    'type': 'notification_allowlist',
                    'apps': notifService.allowedApps,
                    'allowAll': notifService.allowAll,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Settings sent!', style: TextStyle(fontSize: context.fontSize(11))),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
