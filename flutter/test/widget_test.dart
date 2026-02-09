import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bluesoundplayer_flutter/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BluesoundControllerApp(),
      ),
    );

    // Verify the app title is present
    expect(find.text('BlueSound Controller'), findsOneWidget);
  });
}
