// This is a basic Flutter widget test.
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/main.dart';

void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/firebase_core');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'Firebase#initializeCore') {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          },
          'isAutomaticDataCollectionEnabled': true,
        }
      ];
    }
    if (methodCall.method == 'Firebase#initializeApp') {
      return {
        'name': methodCall.arguments['appName'],
        'options': methodCall.arguments['options'],
        'isAutomaticDataCollectionEnabled': true,
      };
    }
    return null;
  });

  const MethodChannel authChannel = MethodChannel('plugins.flutter.io/firebase_auth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(authChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'Auth#registerIdTokenListener' ||
        methodCall.method == 'Auth#registerAuthStateListener') {
      return null;
    }
    return null;
  });
}

void main() {
  setupFirebaseMocks();

  testWidgets('SplashScreen shows title and subtitle', (WidgetTester tester) async {
    // Initialize Mock Firebase
    await Firebase.initializeApp();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const StudyMateApp());

    // Verify that the SplashScreen shows the app title and subtitle.
    expect(find.text('StudyMate'), findsOneWidget);
    expect(find.text('Your Educational Companion'), findsOneWidget);

    // Let the splash screen timer expire so the test finishes cleanly
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
