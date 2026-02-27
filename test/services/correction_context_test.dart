import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/services/correction_context.dart';

void main() {
  group('CorrectionContext', () {
    late CorrectionContext context;

    setUp(() {
      context = CorrectionContext(maxSegments: 3);
    });

    test('initial state is empty', () {
      expect(context.hasContext, isFalse);
      expect(context.segmentCount, 0);
      expect(context.getContextString(), '');
    });

    test('addSegment adds text', () {
      context.addSegment('第一段文本');
      expect(context.hasContext, isTrue);
      expect(context.segmentCount, 1);
      expect(context.getContextString(), '第一段文本');
    });

    test('addSegment trims empty text', () {
      context.addSegment('   ');
      expect(context.hasContext, isFalse);
      expect(context.segmentCount, 0);
    });

    test('multiple segments joined by newline', () {
      context.addSegment('第一段');
      context.addSegment('第二段');
      expect(context.segmentCount, 2);
      expect(context.getContextString(), '第一段\n第二段');
    });

    test('window size is maintained', () {
      context.addSegment('段1');
      context.addSegment('段2');
      context.addSegment('段3');
      context.addSegment('段4'); // 段1 should be evicted

      expect(context.segmentCount, 3);
      expect(context.getContextString(), '段2\n段3\n段4');
    });

    test('reset clears all segments', () {
      context.addSegment('段1');
      context.addSegment('段2');
      context.reset();

      expect(context.hasContext, isFalse);
      expect(context.segmentCount, 0);
      expect(context.getContextString(), '');
    });

    test('default maxSegments is 5', () {
      final defaultContext = CorrectionContext();
      for (var i = 1; i <= 7; i++) {
        defaultContext.addSegment('段$i');
      }
      expect(defaultContext.segmentCount, 5);
      expect(defaultContext.getContextString(), '段3\n段4\n段5\n段6\n段7');
    });
  });
}
