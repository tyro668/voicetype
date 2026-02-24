import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:voicetype/app.dart';
import 'package:voicetype/database/app_database.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDatabase.resetForTest();
  });

  tearDownAll(() async {
    await AppDatabase.resetForTest();
  });

  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceTypeApp());
    // Drain the 10-second sqflite transaction lock timer
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('VoiceType'), findsOneWidget);
  });
}
