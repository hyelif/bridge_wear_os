import 'package:flutter_test/flutter_test.dart';

import 'package:bridge_wear_os/main.dart';

void main() {
  testWidgets('shows device discovery screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Discover Bridge Devices'), findsOneWidget);
    expect(find.text('Scanning for devices...'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });
}
