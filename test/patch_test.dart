/// Tests for Patch functions
///
/// Copyright 2011 Google Inc.
/// Copyright 2014 Boris Kaul <localvoid@gmail.com>
/// http://github.com/localvoid/diff-match-patch
///
/// Licensed under the Apache License, Version 2.0 (the 'License');
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///   http://www.apache.org/licenses/LICENSE-2.0
///
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an 'AS IS' BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.

import 'package:test/test.dart';
import 'package:diff_match_patch/src/diff.dart';
import 'package:diff_match_patch/src/patch.dart';

void main() {
  group('Patch', () {
    test('toString', () {
      var p = Patch();
      p.start1 = 20;
      p.start2 = 21;
      p.length1 = 18;
      p.length2 = 17;
      p.diffs = [
        Diff(DIFF_EQUAL, 'jump'),
        Diff(DIFF_DELETE, 's'),
        Diff(DIFF_INSERT, 'ed'),
        Diff(DIFF_EQUAL, ' over '),
        Diff(DIFF_DELETE, 'the'),
        Diff(DIFF_INSERT, 'a'),
        Diff(DIFF_EQUAL, '\nlaz')
      ];
      var strp =
          '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n %0Alaz\n';
      expect(p.toString(), equals(strp));
    });

    group('fromText', () {
      test('#0', () {
        expect(patchFromText('').isEmpty, equals(true));
      });
      test('#1', () {
        var strp =
            '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n %0Alaz\n';
        expect(patchFromText(strp)[0].toString(), equals(strp));
      });
      test('#2', () {
        expect(patchFromText('@@ -1 +1 @@\n-a\n+b\n')[0].toString(),
            equals('@@ -1 +1 @@\n-a\n+b\n'));
      });
      test('#3', () {
        expect(patchFromText('@@ -1,3 +0,0 @@\n-abc\n')[0].toString(),
            equals('@@ -1,3 +0,0 @@\n-abc\n'));
      });
      test('#4', () {
        expect(patchFromText('@@ -0,0 +1,3 @@\n+abc\n')[0].toString(),
            equals('@@ -0,0 +1,3 @@\n+abc\n'));
      });
      test('#5', () {
        expect(() => patchFromText('Bad\nPatch\n'), throwsArgumentError);
      });
    });

    group('toText', () {
      test('Single', () {
        var strp =
            '@@ -21,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n';
        var patches = patchFromText(strp);
        expect(patchToText(patches), equals(strp));
      });
      test('Double', () {
        var strp =
            '@@ -1,9 +1,9 @@\n-f\n+F\n oo+fooba\n@@ -7,9 +7,9 @@\n obar\n-,\n+.\n  tes\n';
        var patches = patchFromText(strp);
        expect(patchToText(patches), equals(strp));
      });
    });

    group('AddContext', () {
      const margin = 4;

      test('Simple case', () {
        var p = patchFromText('@@ -21,4 +21,10 @@\n-jump\n+somersault\n')[0];
        patchAddContext(
            p, 'The quick brown fox jumps over the lazy dog.', margin);
        expect(p.toString(),
            equals('@@ -17,12 +17,18 @@\n fox \n-jump\n+somersault\n s ov\n'));
      });
      test('Not enough trailing context', () {
        var p = patchFromText('@@ -21,4 +21,10 @@\n-jump\n+somersault\n')[0];
        patchAddContext(p, 'The quick brown fox jumps.', margin);
        expect(p.toString(),
            equals('@@ -17,10 +17,16 @@\n fox \n-jump\n+somersault\n s.\n'));
      });
      test('Not enough leading context', () {
        var p = patchFromText('@@ -3 +3,2 @@\n-e\n+at\n')[0];
        patchAddContext(p, 'The quick brown fox jumps.', margin);
        expect(p.toString(), equals('@@ -1,7 +1,8 @@\n Th\n-e\n+at\n  qui\n'));
      });
      test('Ambiguity', () {
        var p = patchFromText('@@ -3 +3,2 @@\n-e\n+at\n')[0];
        patchAddContext(p,
            'The quick brown fox jumps.  The quick brown fox crashes.', margin);
        expect(
            p.toString(),
            equals(
                '@@ -1,27 +1,28 @@\n Th\n-e\n+at\n  quick brown fox jumps. \n'));
      });
    });

    group('Make', () {
      const text1 = 'The quick brown fox jumps over the lazy dog.';
      const text2 = 'That quick brown fox jumped over a lazy dog.';
      var diffs = diff(text1, text2, checklines: false);

      test('Null', () {
        var patches = patchMake('', b: '');
        expect(patchToText(patches), equals(''));
      });

      test('Text2+Text1 inputs', () {
        var expectedPatch =
            '@@ -1,8 +1,7 @@\n Th\n-at\n+e\n  qui\n@@ -21,17 +21,18 @@\n jump\n-ed\n+s\n  over \n-a\n+the\n  laz\n';
        // The second patch must be '-21,17 +21,18', not '-22,17 +21,18' due to rolling context.
        var patches = patchMake(text2, b: text1);
        expect(patchToText(patches), equals(expectedPatch));
      });

      test('Text1+Text2 inputs', () {
        var expectedPatch =
            '@@ -1,11 +1,12 @@\n Th\n-e\n+at\n  quick b\n@@ -22,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n';
        var patches = patchMake(text1, b: text2);
        expect(patchToText(patches), equals(expectedPatch));
      });

      test('Diff input', () {
        var expectedPatch =
            '@@ -1,11 +1,12 @@\n Th\n-e\n+at\n  quick b\n@@ -22,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n';
        var patches = patchMake(diffs);
        expect(patchToText(patches), equals(expectedPatch));
      });

      test('Text1+Diff', () {
        var expectedPatch =
            '@@ -1,11 +1,12 @@\n Th\n-e\n+at\n  quick b\n@@ -22,18 +22,17 @@\n jump\n-s\n+ed\n  over \n-the\n+a\n  laz\n';
        var patches = patchMake(text1, b: diffs);
        expect(patchToText(patches), equals(expectedPatch));
      });

      test('Character encoding', () {
        var patches =
            patchMake('`1234567890-=[]\\;\',./', b: '~!@#\$%^&*()_+{}|:"<>?');
        expect(
            patchToText(patches),
            equals(
                '@@ -1,21 +1,21 @@\n-%601234567890-=%5B%5D%5C;\',./\n+~!@#\$%25%5E&*()_+%7B%7D%7C:%22%3C%3E?\n'));
      });

      test('Character decoding', () {
        var diffs = [
          Diff(DIFF_DELETE, '`1234567890-=[]\\;\',./'),
          Diff(DIFF_INSERT, '~!@#\$%^&*()_+{}|:"<>?')
        ];
        expect(
            patchFromText(
                    '@@ -1,21 +1,21 @@\n-%601234567890-=%5B%5D%5C;\',./\n+~!@#\$%25%5E&*()_+%7B%7D%7C:%22%3C%3E?\n')[0]
                .diffs,
            equals(diffs));
      });

      test('Long string with repeats', () {
        final sb = StringBuffer();
        for (var x = 0; x < 100; x++) {
          sb.write('abcdef');
        }
        var text1 = sb.toString();
        var text2 = '${text1}123';
        var expectedPatch =
            '@@ -573,28 +573,31 @@\n cdefabcdefabcdefabcdefabcdef\n+123\n';
        var patches = patchMake(text1, b: text2);
        expect(patchToText(patches), equals(expectedPatch));
      });

      test('Null inputs', () {
        expect(() => patchMake(null), throwsArgumentError);
      });
    });

    group('Split Max', () {
      // Assumes that Match_MaxBits is 32.
      test('#1', () {
        var patches = patchMake('abcdefghijklmnopqrstuvwxyz01234567890',
            b: 'XabXcdXefXghXijXklXmnXopXqrXstXuvXwxXyzX01X23X45X67X89X0');
        patchSplitMax(patches);
        expect(
            patchToText(patches),
            equals(
                '@@ -1,32 +1,46 @@\n+X\n ab\n+X\n cd\n+X\n ef\n+X\n gh\n+X\n ij\n+X\n kl\n+X\n mn\n+X\n op\n+X\n qr\n+X\n st\n+X\n uv\n+X\n wx\n+X\n yz\n+X\n 012345\n@@ -25,13 +39,18 @@\n zX01\n+X\n 23\n+X\n 45\n+X\n 67\n+X\n 89\n+X\n 0\n'));
      });

      test('#2', () {
        var patches = patchMake(
            'abcdef1234567890123456789012345678901234567890123456789012345678901234567890uvwxyz',
            b: 'abcdefuvwxyz');
        var oldToText = patchToText(patches);
        patchSplitMax(patches);
        expect(patchToText(patches), equals(oldToText));
      });

      test('#3', () {
        var patches = patchMake(
            '1234567890123456789012345678901234567890123456789012345678901234567890',
            b: 'abc');
        patchSplitMax(patches);
        expect(
            patchToText(patches),
            equals(
                '@@ -1,32 +1,4 @@\n-1234567890123456789012345678\n 9012\n@@ -29,32 +1,4 @@\n-9012345678901234567890123456\n 7890\n@@ -57,14 +1,3 @@\n-78901234567890\n+abc\n'));
      });

      test('#4', () {
        var patches = patchMake(
            'abcdefghij , h : 0 , t : 1 abcdefghij , h : 0 , t : 1 abcdefghij , h : 0 , t : 1',
            b: 'abcdefghij , h : 1 , t : 1 abcdefghij , h : 1 , t : 1 abcdefghij , h : 0 , t : 1');
        patchSplitMax(patches);
        expect(
            patchToText(patches),
            equals(
                '@@ -2,32 +2,32 @@\n bcdefghij , h : \n-0\n+1\n  , t : 1 abcdef\n@@ -29,32 +29,32 @@\n bcdefghij , h : \n-0\n+1\n  , t : 1 abcdef\n'));
      });
    });

    group('Add padding', () {
      test('Both edges full', () {
        var patches = patchMake('', b: 'test');
        expect(patchToText(patches), equals('@@ -0,0 +1,4 @@\n+test\n'));
        patchAddPadding(patches);
        expect(patchToText(patches),
            equals('@@ -1,8 +1,12 @@\n %01%02%03%04\n+test\n %01%02%03%04\n'));
      });
      test('Both edges partial', () {
        var patches = patchMake('XY', b: 'XtestY');
        expect(
            patchToText(patches), equals('@@ -1,2 +1,6 @@\n X\n+test\n Y\n'));
        patchAddPadding(patches);
        expect(patchToText(patches),
            equals('@@ -2,8 +2,12 @@\n %02%03%04X\n+test\n Y%01%02%03\n'));
      });
      test('Both edges none', () {
        var patches = patchMake('XXXXYYYY', b: 'XXXXtestYYYY');
        expect(patchToText(patches),
            equals('@@ -1,8 +1,12 @@\n XXXX\n+test\n YYYY\n'));
        patchAddPadding(patches);
        expect(patchToText(patches),
            equals('@@ -5,8 +5,12 @@\n XXXX\n+test\n YYYY\n'));
      });
    });

    group('Apply', () {
      test('Null', () {
        var patches = patchMake('', b: '');
        var results = patchApply(patches, 'Hello world.');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray.length}';
        expect(resultStr, equals('Hello world.\t0'));
      });

      test('Exact match', () {
        var patches = patchMake('The quick brown fox jumps over the lazy dog.',
            b: 'That quick brown fox jumped over a lazy dog.');
        var results =
            patchApply(patches, 'The quick brown fox jumps over the lazy dog.');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(resultStr,
            equals('That quick brown fox jumped over a lazy dog.\ttrue\ttrue'));
      });

      test('Partial match', () {
        var patches = patchMake('The quick brown fox jumps over the lazy dog.',
            b: 'That quick brown fox jumped over a lazy dog.');
        var results = patchApply(
            patches, 'The quick red rabbit jumps over the tired tiger.');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(
            resultStr,
            equals(
                'That quick red rabbit jumped over a tired tiger.\ttrue\ttrue'));
      });

      test('Failed match', () {
        var patches = patchMake('The quick brown fox jumps over the lazy dog.',
            b: 'That quick brown fox jumped over a lazy dog.');
        var results = patchApply(
            patches, 'I am the very model of a modern major general.');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(
            resultStr,
            equals(
                'I am the very model of a modern major general.\tfalse\tfalse'));
      });

      test('Big delete, small change', () {
        var patches = patchMake(
            'x1234567890123456789012345678901234567890123456789012345678901234567890y',
            b: 'xabcy');
        var results = patchApply(patches,
            'x123456789012345678901234567890-----++++++++++-----123456789012345678901234567890y');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(resultStr, equals('xabcy\ttrue\ttrue'));
      });

      test('Big delete, big change #1', () {
        var patches = patchMake(
            'x1234567890123456789012345678901234567890123456789012345678901234567890y',
            b: 'xabcy');
        var results = patchApply(patches,
            'x12345678901234567890---------------++++++++++---------------12345678901234567890y');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(resultStr,
            'xabc12345678901234567890---------------++++++++++---------------12345678901234567890y\tfalse\ttrue');
      });

      test('Big delete, big change #2', () {
        var deleteThreshold = 0.6;
        var patches = patchMake(
            'x1234567890123456789012345678901234567890123456789012345678901234567890y',
            b: 'xabcy',
            deleteThreshold: deleteThreshold);
        var results = patchApply(patches,
            'x12345678901234567890---------------++++++++++---------------12345678901234567890y',
            deleteThreshold: deleteThreshold);
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(resultStr, equals('xabcy\ttrue\ttrue'));
      });

      test('Compensate for failed patch', () {
        var matchThreshold = 0.0;
        var matchDistance = 0;
        var patches = patchMake(
            'abcdefghijklmnopqrstuvwxyz--------------------1234567890',
            b: 'abcXXXXXXXXXXdefghijklmnopqrstuvwxyz--------------------1234567YYYYYYYYYY890');
        var results = patchApply(
            patches, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ--------------------1234567890',
            matchThreshold: matchThreshold, matchDistance: matchDistance);
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}\t${boolArray[1]}';
        expect(
            resultStr,
            equals(
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ--------------------1234567YYYYYYYYYY890\tfalse\ttrue'));
      });

      test('No side effects', () {
        var patches = patchMake('', b: 'test');
        var patchStr = patchToText(patches);
        patchApply(patches, '');
        expect(patchToText(patches), equals(patchStr));
      });

      test('No side effects with major delete', () {
        var patches = patchMake('The quick brown fox jumps over the lazy dog.',
            b: 'Woof');
        var patchStr = patchToText(patches);
        patchApply(patches, 'The quick brown fox jumps over the lazy dog.');
        expect(patchToText(patches), equals(patchStr));
      });

      test('Edge exact match', () {
        var patches = patchMake('', b: 'test');
        var results = patchApply(patches, '');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}';
        expect(resultStr, equals('test\ttrue'));
      });

      test('Near edge exact match', () {
        var patches = patchMake('XY', b: 'XtestY');
        var results = patchApply(patches, 'XY');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}';
        expect(resultStr, equals('XtestY\ttrue'));
      });

      test('Edge partial match', () {
        var patches = patchMake('y', b: 'y123');
        var results = patchApply(patches, 'x');
        var boolArray = results[1];
        var resultStr = '${results[0]}\t${boolArray[0]}';
        expect(resultStr, equals('x123\ttrue'));
      });
    });
  });
}
