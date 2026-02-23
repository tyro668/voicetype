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
    expect(find.text('VoiceType'), findsOneWidget);
  });
}
