import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/services/session_glossary.dart';

void main() {
  group('SessionGlossary', () {
    late SessionGlossary glossary;

    setUp(() {
      glossary = SessionGlossary();
    });

    test('starts empty', () {
      expect(glossary.length, 0);
      expect(glossary.entries, isEmpty);
      expect(glossary.strongEntries, isEmpty);
      expect(glossary.hasStrongEntries, isFalse);
    });

    group('pin', () {
      test('adds weak entry on first pin', () {
        glossary.pin('反软', '帆软');
        expect(glossary.length, 1);
        expect(glossary.entries['反软']!.corrected, '帆软');
        expect(glossary.entries['反软']!.hitCount, 1);
        expect(glossary.hasStrongEntries, isFalse);
      });

      test('promotes to strong on second pin', () {
        glossary.pin('反软', '帆软');
        glossary.pin('反软', '帆软');
        expect(glossary.length, 1);
        expect(glossary.entries['反软']!.hitCount, 2);
        expect(glossary.hasStrongEntries, isTrue);
        expect(glossary.strongEntries, hasLength(1));
      });

      test('ignores empty original or corrected', () {
        glossary.pin('', '帆软');
        glossary.pin('反软', '');
        glossary.pin('  ', '帆软');
        expect(glossary.length, 0);
      });

      test('ignores identical original and corrected', () {
        glossary.pin('帆软', '帆软');
        expect(glossary.length, 0);
      });

      test('normalizes key to lowercase', () {
        glossary.pin('ABC', 'abc-corrected');
        glossary.pin('abc', 'abc-corrected');
        expect(glossary.length, 1);
        expect(glossary.entries['abc']!.hitCount, 2);
      });

      test('records segmentIndex', () {
        glossary.pin('反软', '帆软', segmentIndex: 5);
        expect(glossary.entries['反软']!.firstSeenSegment, 5);
      });
    });

    group('strongEntries', () {
      test('excludes weak entries', () {
        glossary.pin('反软', '帆软');
        glossary.pin('星阔', '兴阔');
        glossary.pin('星阔', '兴阔'); // promote

        expect(glossary.length, 2);
        expect(glossary.strongEntries, hasLength(1));
        expect(glossary.strongEntries.containsKey('星阔'), isTrue);
      });
    });

    group('override', () {
      test('creates strong entry directly', () {
        glossary.override('反软', '帆软');
        expect(glossary.entries['反软']!.hitCount, 2);
        expect(glossary.hasStrongEntries, isTrue);
      });

      test('replaces existing entry', () {
        glossary.pin('反软', '帆软');
        glossary.override('反软', '帆软Pro');
        expect(glossary.entries['反软']!.corrected, '帆软Pro');
        expect(glossary.entries['反软']!.hitCount, 2);
      });

      test('removes entry when corrected is empty', () {
        glossary.pin('反软', '帆软');
        glossary.override('反软', '');
        expect(glossary.length, 0);
      });

      test('ignores empty original', () {
        glossary.override('', '帆软');
        expect(glossary.length, 0);
      });
    });

    group('buildReferenceAppend', () {
      test('returns empty for no entries', () {
        expect(glossary.buildReferenceAppend(), '');
      });

      test('returns empty when only weak entries', () {
        glossary.pin('反软', '帆软');
        expect(glossary.buildReferenceAppend(), '');
      });

      test('returns strong entries formatted', () {
        glossary.pin('反软', '帆软');
        glossary.pin('反软', '帆软');
        expect(glossary.buildReferenceAppend(), '反软->帆软');
      });

      test('joins multiple strong entries with pipe', () {
        glossary.override('反软', '帆软');
        glossary.override('星阔', '兴阔');

        final result = glossary.buildReferenceAppend();
        expect(result, contains('反软->帆软'));
        expect(result, contains('星阔->兴阔'));
        expect(result.split('|').length, 2);
      });
    });

    group('extractAndPin', () {
      test('does nothing when input equals corrected', () {
        glossary.extractAndPin('今天天气不错', '今天天气不错');
        expect(glossary.length, 0);
      });

      test('extracts Chinese word differences', () {
        // Add non-Chinese separator so _extractChineseWords splits them
        glossary.extractAndPin('使用 反软 产品', '使用 帆软 产品');
        expect(glossary.length, 1);
        expect(glossary.entries['反软']!.corrected, '帆软');
      });

      test('pins whole contiguous Chinese block as key', () {
        // Without separators, entire Chinese block is one "word"
        glossary.extractAndPin('使用反软产品', '使用帆软产品');
        expect(glossary.length, 1);
        expect(glossary.entries.keys.first, '使用反软产品');
      });

      test('ignores single-char differences', () {
        // Single char words are filtered (length < 2)
        glossary.extractAndPin('a 大 b', 'a 小 b');
        expect(glossary.length, 0);
      });

      test('records segmentIndex', () {
        glossary.extractAndPin('使用 反软 产品', '使用 帆软 产品', segmentIndex: 3);
        expect(glossary.entries['反软']!.firstSeenSegment, 3);
      });

      test('accumulates hits across calls', () {
        glossary.extractAndPin('使用 反软 产品', '使用 帆软 产品', segmentIndex: 0);
        glossary.extractAndPin('看看 反软 报表', '看看 帆软 报表', segmentIndex: 1);
        expect(glossary.entries['反软']!.hitCount, 2);
        expect(glossary.hasStrongEntries, isTrue);
      });
    });

    group('reset', () {
      test('clears all entries', () {
        glossary.pin('反软', '帆软');
        glossary.pin('星阔', '兴阔');
        glossary.reset();
        expect(glossary.length, 0);
        expect(glossary.entries, isEmpty);
      });
    });
  });

  group('TermPin', () {
    test('copyWithHit increments hitCount', () {
      const pin = TermPin(
        original: '反软',
        corrected: '帆软',
        hitCount: 1,
        firstSeenSegment: 0,
      );
      final promoted = pin.copyWithHit();
      expect(promoted.hitCount, 2);
      expect(promoted.original, '反软');
      expect(promoted.corrected, '帆软');
      expect(promoted.firstSeenSegment, 0);
    });

    test('toString formats correctly', () {
      const pin = TermPin(
        original: '反软',
        corrected: '帆软',
        hitCount: 3,
        firstSeenSegment: 1,
      );
      expect(pin.toString(), 'TermPin(反软->帆软, hits=3, seg=1)');
    });
  });
}
