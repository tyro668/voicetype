import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceTypeApp());
    expect(find.text('VoiceType'), findsOneWidget);
  });
}
