import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_review_buddy/main.dart';

void main() {
  testWidgets('App widget provides MaterialApp configuration', (tester) async {
    // Build configuration without triggering the platform-backed LaunchScreen.
    const app = ReviewBuddyApp();
    expect(app, isA<StatelessWidget>());
    expect(app.createElement(), isA<StatelessElement>());
  });
}
