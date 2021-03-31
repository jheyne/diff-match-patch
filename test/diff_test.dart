/// Tests for Diff functions
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

Diff deq(String t) => Diff(DIFF_EQUAL, t);
Diff ddel(String t) => Diff(DIFF_DELETE, t);
Diff dins(String t) => Diff(DIFF_INSERT, t);

List<String> _rebuildTexts(List<Diff> diffs) {
  // Construct the two texts which made up the diff originally.
  final text1 = StringBuffer();
  final text2 = StringBuffer();
  for (var x = 0; x < diffs.length; x++) {
    if (diffs[x].operation != DIFF_INSERT) {
      text1.write(diffs[x].text);
    }
    if (diffs[x].operation != DIFF_DELETE) {
      text2.write(diffs[x].text);
    }
  }
  return [text1.toString(), text2.toString()];
}

void main() {
  group('Diff', () {
    group('Common Prefix', () {
      test('Null', () {
        expect(commonPrefix('abc', 'xyz'), equals(0));
      });
      test('Non-null', () {
        expect(commonPrefix('1234abcdef', '1234xyz'), equals(4));
      });
      test('Whole', () {
        expect(commonPrefix('1234', '1234xyz'), equals(4));
      });
    });

    group('Common Suffix', () {
      test('Null', () {
        expect(commonSuffix('abc', 'xyz'), equals(0));
      });
      test('Non-null', () {
        expect(commonSuffix('abcdef1234', 'xyz1234'), equals(4));
      });
      test('Whole', () {
        expect(commonSuffix('1234', 'xyz1234'), equals(4));
      });
    });

    group('Common Overlap', () {
      test('Null', () {
        expect(commonOverlap('', 'abcd'), equals(0));
      });
      test('Whole', () {
        expect(commonOverlap('abc', 'abcd'), equals(3));
      });
      test('No overlap', () {
        expect(commonOverlap('123456', 'abcd'), equals(0));
      });
      test('Overlap', () {
        expect(commonOverlap('123456xxx', 'xxxabcd'), equals(3));
      });
      test('Unicode', () {
        expect(commonOverlap('fi', '\ufb01i'), equals(0));
      });
    });

    group('Half Match', () {
      test('No match #1', () {
        expect(diffHalfMatch('1234567890', 'abcdef', 1.0), isNull);
      });
      test('No match #2', () {
        expect(diffHalfMatch('12345', '23', 1.0), isNull);
      });
      test('Single match #1', () {
        expect(diffHalfMatch('1234567890', 'a345678z', 1.0),
            equals(['12', '90', 'a', 'z', '345678']));
      });
      test('Single match #2', () {
        expect(diffHalfMatch('a345678z', '1234567890', 1.0),
            equals(['a', 'z', '12', '90', '345678']));
      });
      test('Single match #3', () {
        expect(diffHalfMatch('abc56789z', '1234567890', 1.0),
            equals(['abc', 'z', '1234', '0', '56789']));
      });
      test('Single match #4', () {
        expect(diffHalfMatch('a23456xyz', '1234567890', 1.0),
            equals(['a', 'xyz', '1', '7890', '23456']));
      });
      test('Multiple matches #1', () {
        expect(
            diffHalfMatch('121231234123451234123121', 'a1234123451234z', 1.0),
            equals(['12123', '123121', 'a', 'z', '1234123451234']));
      });
      test('Multiple matches #2', () {
        expect(
            diffHalfMatch('x-=-=-=-=-=-=-=-=-=-=-=-=', 'xx-=-=-=-=-=-=-=', 1.0),
            equals(['', '-=-=-=-=-=', 'x', '', 'x-=-=-=-=-=-=-=']));
      });
      test('Multiple matches #3', () {
        expect(
            diffHalfMatch('-=-=-=-=-=-=-=-=-=-=-=-=y', '-=-=-=-=-=-=-=yy', 1.0),
            equals(['-=-=-=-=-=', '', '', 'y', '-=-=-=-=-=-=-=y']));
      });
      test('Non-optimal halfmatch', () {
        // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
        expect(diffHalfMatch('qHilloHelloHew', 'xHelloHeHulloy', 1.0),
            equals(['qHillo', 'w', 'x', 'Hulloy', 'HelloHe']));
      });
      test('Optimal no halfmatch', () {
        expect(diffHalfMatch('qHilloHelloHew', 'xHelloHeHulloy', 0.0), isNull);
      });
    });

    group('Lines To Chars', () {
      void testLinesToCharsResultEquals(
          Map<String, dynamic> a, Map<String, dynamic> b) {
        expect(a['chars1'], equals(b['chars1']));
        expect(a['chars2'], equals(b['chars2']));
        expect(a['lineArray'], equals(b['lineArray']));
      }

      // Convert lines down to characters.
      test('Shared lines', () {
        testLinesToCharsResultEquals({
          'chars1': '\u0001\u0002\u0001',
          'chars2': '\u0002\u0001\u0002',
          'lineArray': ['', 'alpha\n', 'beta\n']
        }, linesToChars('alpha\nbeta\nalpha\n', 'beta\nalpha\nbeta\n'));
      });
      test('Empty string and blank lines', () {
        testLinesToCharsResultEquals({
          'chars1': '',
          'chars2': '\u0001\u0002\u0003\u0003',
          'lineArray': ['', 'alpha\r\n', 'beta\r\n', '\r\n']
        }, linesToChars('', 'alpha\r\nbeta\r\n\r\n\r\n'));
      });
      test('No linebreaks', () {
        testLinesToCharsResultEquals({
          'chars1': '\u0001',
          'chars2': '\u0002',
          'lineArray': ['', 'a', 'b']
        }, linesToChars('a', 'b'));
      });

      test('More than 256', () {
        // More than 256 to reveal any 8-bit limitations.
        var n = 300;
        var lineList = <String>[];
        var charList = StringBuffer();
        for (var x = 1; x < n + 1; x++) {
          lineList.add('$x\n');
          charList.write(String.fromCharCodes([x]));
        }
        expect(lineList.length, equals(n));
        var lines = lineList.join('');
        var chars = charList.toString();
        expect(chars.length, equals(n));
        lineList.insert(0, '');
        testLinesToCharsResultEquals(
            {'chars1': chars, 'chars2': '', 'lineArray': lineList},
            linesToChars(lines, ''));
      });
    });

    group('Chars To Lines', () {
      test('Equality #1', () {
        expect(deq('a') == deq('a'), isTrue);
      });
      test('Equality #2', () {
        expect(deq('a'), equals(deq('a')));
      });

      test('Shared lines', () {
        // Convert chars up to lines.
        var diffs = <Diff>[
          deq('\u0001\u0002\u0001'),
          dins('\u0002\u0001\u0002')
        ];
        charsToLines(diffs, ['', 'alpha\n', 'beta\n']);
        expect(diffs,
            equals([deq('alpha\nbeta\nalpha\n'), dins('beta\nalpha\nbeta\n')]));
      });

      test('More than 256', () {
        // More than 256 to reveal any 8-bit limitations.
        var n = 300;
        var lineList = <String>[];
        var charList = StringBuffer();
        for (var x = 1; x < n + 1; x++) {
          lineList.add('$x\n');
          charList.write(String.fromCharCodes([x]));
        }
        expect(lineList.length, equals(n));
        var lines = lineList.join('');
        var chars = charList.toString();
        expect(chars.length, equals(n));
        lineList.insert(0, '');
        var diffs = [ddel(chars)];
        charsToLines(diffs, lineList);
        expect(diffs, equals([ddel(lines)]));
      });
    });

    group('CleanupMerge', () {
      test('Null', () {
        var diffs = <Diff>[];
        cleanupMerge(diffs);
        expect(diffs, equals([]));
      });
      test('No change case', () {
        var diffs = <Diff>[deq('a'), ddel('b'), dins('c')];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('a'), ddel('b'), dins('c')]));
      });
      test('Merge equalities', () {
        var diffs = <Diff>[deq('a'), deq('b'), deq('c')];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('abc')]));
      });
      test('Merge deletions', () {
        var diffs = <Diff>[ddel('a'), ddel('b'), ddel('c')];
        cleanupMerge(diffs);
        expect(diffs, equals([ddel('abc')]));
      });
      test('Merge insertions', () {
        var diffs = <Diff>[dins('a'), dins('b'), dins('c')];
        cleanupMerge(diffs);
        expect(diffs, equals([dins('abc')]));
      });
      test('Merge interweave', () {
        var diffs = <Diff>[
          ddel('a'),
          dins('b'),
          ddel('c'),
          dins('d'),
          deq('e'),
          deq('f')
        ];
        cleanupMerge(diffs);
        expect(diffs, equals([ddel('ac'), dins('bd'), deq('ef')]));
      });
      test('Prefix and suffix detection', () {
        var diffs = <Diff>[ddel('a'), dins('abc'), ddel('dc')];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('a'), ddel('d'), dins('b'), deq('c')]));
      });
      test('Prefix and suffix detection with equalities', () {
        var diffs = <Diff>[
          deq('x'),
          ddel('a'),
          dins('abc'),
          ddel('dc'),
          deq('y')
        ];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('xa'), ddel('d'), dins('b'), deq('cy')]));
      });
      test('Slide edit left', () {
        var diffs = <Diff>[deq('a'), dins('ba'), deq('c')];
        cleanupMerge(diffs);
        expect(diffs, equals([dins('ab'), deq('ac')]));
      });
      test('Slide edit right', () {
        var diffs = <Diff>[deq('c'), dins('ab'), deq('a')];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('ca'), dins('ba')]));
      });
      test('Slide edit left recursive', () {
        var diffs = <Diff>[deq('a'), ddel('b'), deq('c'), ddel('ac'), deq('x')];
        cleanupMerge(diffs);
        expect(diffs, equals([ddel('abc'), deq('acx')]));
      });
      test('diff_cleanupMerge: Slide edit right recursive', () {
        var diffs = <Diff>[deq('x'), ddel('ca'), deq('c'), ddel('b'), deq('a')];
        cleanupMerge(diffs);
        expect(diffs, equals([deq('xca'), ddel('cba')]));
      });
    });

    group('Cleanup Semantic Lossless', () {
      // Slide diffs to match logical boundaries.
      test('Null case', () {
        var diffs = <Diff>[];
        cleanupSemanticLossless(diffs);
        expect(diffs, equals([]));
      });
      test('Blank lines', () {
        var diffs = <Diff>[
          deq('AAA\r\n\r\nBBB'),
          dins('\r\nDDD\r\n\r\nBBB'),
          deq('\r\nEEE')
        ];
        cleanupSemanticLossless(diffs);
        expect(
            diffs,
            equals([
              deq('AAA\r\n\r\n'),
              dins('BBB\r\nDDD\r\n\r\n'),
              deq('BBB\r\nEEE')
            ]));
      });
      test('Line boundaries', () {
        var diffs = <Diff>[deq('AAA\r\nBBB'), dins(' DDD\r\nBBB'), deq(' EEE')];
        cleanupSemanticLossless(diffs);
        expect(diffs,
            equals([deq('AAA\r\n'), dins('BBB DDD\r\n'), deq('BBB EEE')]));
      });
      test('Word boundaries', () {
        var diffs = <Diff>[deq('The c'), dins('ow and the c'), deq('at.')];
        cleanupSemanticLossless(diffs);
        expect(diffs, equals([deq('The '), dins('cow and the '), deq('cat.')]));
      });
      test('Alphanumeric boundaries', () {
        var diffs = <Diff>[deq('The-c'), dins('ow-and-the-c'), deq('at.')];
        cleanupSemanticLossless(diffs);
        expect(diffs, equals([deq('The-'), dins('cow-and-the-'), deq('cat.')]));
      });
      test('Hitting the start', () {
        var diffs = <Diff>[deq('a'), ddel('a'), deq('ax')];
        cleanupSemanticLossless(diffs);
        expect(diffs, equals([ddel('a'), deq('aax')]));
      });
      test('Hitting the end', () {
        var diffs = <Diff>[deq('xa'), ddel('a'), deq('a')];
        cleanupSemanticLossless(diffs);
        expect(diffs, equals([deq('xaa'), ddel('a')]));
      });
      test('Sentence boundaries', () {
        var diffs = <Diff>[
          deq('The xxx. The '),
          dins('zzz. The '),
          deq('yyy.')
        ];
        cleanupSemanticLossless(diffs);
        expect(diffs,
            equals([deq('The xxx.'), dins(' The zzz.'), deq(' The yyy.')]));
      });
    });

    group('Cleanup Semantic', () {
      // Cleanup semantically trivial equalities.
      test('Null case', () {
        var diffs = <Diff>[];
        cleanupSemantic(diffs);
        expect(diffs, equals([]));
      });
      test('No elimination #1', () {
        var diffs = <Diff>[ddel('ab'), dins('cd'), deq('12'), ddel('e')];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('ab'), dins('cd'), deq('12'), ddel('e')]));
      });
      test('No elimination #2', () {
        var diffs = <Diff>[ddel('abc'), dins('ABC'), deq('1234'), ddel('wxyz')];
        cleanupSemantic(diffs);
        expect(diffs,
            equals([ddel('abc'), dins('ABC'), deq('1234'), ddel('wxyz')]));
      });
      test('Simple elimination', () {
        var diffs = <Diff>[ddel('a'), deq('b'), ddel('c')];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('abc'), dins('b')]));
      });
      test('Backpass elimination', () {
        var diffs = <Diff>[
          ddel('ab'),
          deq('cd'),
          ddel('e'),
          deq('f'),
          dins('g')
        ];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('abcdef'), dins('cdfg')]));
      });
      test('Multiple elimination', () {
        var diffs = <Diff>[
          dins('1'),
          deq('A'),
          ddel('B'),
          dins('2'),
          deq('_'),
          dins('1'),
          deq('A'),
          ddel('B'),
          dins('2')
        ];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('AB_AB'), dins('1A2_1A2')]));
      });
      test('Word boundaries', () {
        var diffs = <Diff>[deq('The c'), ddel('ow and the c'), deq('at.')];
        cleanupSemantic(diffs);
        expect(diffs, equals([deq('The '), ddel('cow and the '), deq('cat.')]));
      });
      test('No overlap elimination', () {
        var diffs = <Diff>[ddel('abcxx'), dins('xxdef')];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('abcxx'), dins('xxdef')]));
      });
      test('Overlap elimination', () {
        var diffs = <Diff>[ddel('abcxxx'), dins('xxxdef')];
        cleanupSemantic(diffs);
        expect(diffs, equals([ddel('abc'), deq('xxx'), dins('def')]));
      });
      test('Reverse overlap elimination', () {
        var diffs = <Diff>[ddel('xxxabc'), dins('defxxx')];
        cleanupSemantic(diffs);
        expect(diffs, equals([dins('def'), deq('xxx'), ddel('abc')]));
      });
      test('Two overlap eliminations', () {
        var diffs = <Diff>[
          ddel('abcd1212'),
          dins('1212efghi'),
          deq('----'),
          ddel('A3'),
          dins('3BC')
        ];
        cleanupSemantic(diffs);
        expect(
            diffs,
            equals([
              ddel('abcd'),
              deq('1212'),
              dins('efghi'),
              deq('----'),
              ddel('A'),
              deq('3'),
              dins('BC')
            ]));
      });
    });

    group('Cleanup Efficiency', () {
      // Cleanup operationally trivial equalities.
      test('Null case', () {
        var diffs = <Diff>[];
        cleanupEfficiency(diffs, 4);
        expect(diffs, equals([]));
      });
      test('No elimination', () {
        var diffs = [
          ddel('ab'),
          dins('12'),
          deq('wxyz'),
          ddel('cd'),
          dins('34')
        ];
        cleanupEfficiency(diffs, 4);
        expect(
            diffs,
            equals(
                [ddel('ab'), dins('12'), deq('wxyz'), ddel('cd'), dins('34')]));
      });
      test('Four-edit elimination', () {
        var diffs = [
          ddel('ab'),
          dins('12'),
          deq('xyz'),
          ddel('cd'),
          dins('34')
        ];
        cleanupEfficiency(diffs, 4);
        expect(diffs, equals([ddel('abxyzcd'), dins('12xyz34')]));
      });
      test('Three-edit elimination', () {
        var diffs = [dins('12'), deq('x'), ddel('cd'), dins('34')];
        cleanupEfficiency(diffs, 4);
        expect(diffs, equals([ddel('xcd'), dins('12x34')]));
      });
      test('Backpass elimination', () {
        var diffs = [
          ddel('ab'),
          dins('12'),
          deq('xy'),
          dins('34'),
          deq('z'),
          ddel('cd'),
          dins('56')
        ];
        cleanupEfficiency(diffs, 4);
        expect(diffs, equals([ddel('abxyzcd'), dins('12xy34z56')]));
      });
      test('High cost elimination', () {
        var diffs = [
          ddel('ab'),
          dins('12'),
          deq('wxyz'),
          ddel('cd'),
          dins('34')
        ];
        cleanupEfficiency(diffs, 5);
        expect(diffs, equals([ddel('abwxyzcd'), dins('12wxyz34')]));
      });
    });

    group('Text', () {
      var diffs = [
        deq('jump'),
        ddel('s'),
        dins('ed'),
        deq(' over '),
        ddel('the'),
        dins('a'),
        deq(' lazy')
      ];

      test('#1', () {
        expect(diffText1(diffs), equals('jumps over the lazy'));
      });
      test('#2', () {
        expect(diffText2(diffs), equals('jumped over a lazy'));
      });
    });

    group('Delta', () {
      var diffs = [
        deq('jump'),
        ddel('s'),
        dins('ed'),
        deq(' over '),
        ddel('the'),
        dins('a'),
        deq(' lazy'),
        dins('old dog')
      ];
      test('Base text', () {
        expect(diffText1(diffs), equals('jumps over the lazy'));
      });
      test('Normal', () {
        var delta = toDelta(diffs);
        expect(delta, equals('=4\t-1\t+ed\t=6\t-3\t+a\t=5\t+old dog'));
      });
      test('Too long', () {
        // Generates error (19 < 20)
        var text = diffText1(diffs);
        var delta = toDelta(diffs);
        expect(() => fromDelta('${text}x', delta), throwsArgumentError);
      });
      test('Too short', () {
        // Generates error (19 > 18).
        var text = diffText1(diffs);
        var delta = toDelta(diffs);
        expect(() => fromDelta(text.substring(1), delta), throwsArgumentError);
      });
      test('Too short', () {
        // Generates error (%c3%xy invalid Unicode).
        expect(() => fromDelta('', '+%c3%xy'), throwsArgumentError);
      });
      test('Unicode text', () {
        // Test deltas with special characters.
        var diffs = [
          deq('\u0680 \x00 \t %'),
          ddel('\u0681 \x01 \n ^'),
          dins('\u0682 \x02 \\ |')
        ];
        var text = diffText1(diffs);
        expect(text, equals('\u0680 \x00 \t %\u0681 \x01 \n ^'));
      });
      test('Unicode', () {
        var diffs = [
          deq('\u0680 \x00 \t %'),
          ddel('\u0681 \x01 \n ^'),
          dins('\u0682 \x02 \\ |')
        ];
        var text = diffText1(diffs);
        var delta = toDelta(diffs);
        expect(delta, equals('=7\t-7\t+%DA%82 %02 %5C %7C'));
        expect(fromDelta(text, delta), unorderedEquals(diffs));
      });
      test('Unchanged characters', () {
        // Verify pool of unchanged characters.
        var diffs = [
          dins('A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? : @ & = + \$ , # ')
        ];
        var text2 = diffText2(diffs);
        expect(text2,
            equals('A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? : @ & = + \$ , # '));

        var delta = toDelta(diffs);
        expect(delta,
            equals('+A-Z a-z 0-9 - _ . ! ~ * \' ( ) ; / ? : @ & = + \$ , # '));

        // Convert delta string into a diff.
        expect(fromDelta('', delta), unorderedEquals(diffs));
      });
    });

    group('XIndex', () {
      test('Translation on equality', () {
        expect(diffXIndex([ddel('a'), dins('1234'), deq('xyz')], 2), equals(5));
      });
      test('Translation on deletion', () {
        expect(diffXIndex([deq('a'), ddel('1234'), deq('xyz')], 3), equals(1));
      });
    });

    group('Levenshtein', () {
      test('Trailing equality', () {
        expect(levenshtein([ddel('abc'), dins('1234'), deq('xyz')]), equals(4));
      });
      test('Leading equality', () {
        expect(levenshtein([deq('xyz'), ddel('abc'), dins('1234')]), equals(4));
      });
      test('Middle equality', () {
        expect(levenshtein([ddel('abc'), deq('xyz'), dins('1234')]), equals(7));
      });
    });

    group('Bisect', () {
      test('Normal', () {
        // Since the resulting diff hasn't been normalized, it would be ok if
        // the insertion and deletion pairs are swapped.
        // If the order changes, tweak this test as required.
        var diffs = [ddel('c'), dins('m'), deq('a'), ddel('t'), dins('p')];
        // One year should be sufficient.
        var deadline = DateTime.now().add(Duration(days: 365));
        expect(diffBisect('cat', 'map', 1.0, deadline), equals(diffs));
      });

      test('Timeout', () {
        var diffs = [ddel('cat'), dins('map')];
        // Set deadline to one year ago.
        var deadline = DateTime.now().subtract(Duration(days: 365));
        expect(diffBisect('cat', 'map', 1.0, deadline), equals(diffs));
      });
    });

    group('Main', () {
      test('Null', () {
        expect(diff('', '', checklines: false), equals([]));
      });
      test('Equality', () {
        expect(diff('abc', 'abc', checklines: false), equals([deq('abc')]));
      });
      test('Simple insertion', () {
        expect(diff('abc', 'ab123c', checklines: false),
            equals([deq('ab'), dins('123'), deq('c')]));
      });
      test('Simple deletion', () {
        expect(diff('a123bc', 'abc', checklines: false),
            equals([deq('a'), ddel('123'), deq('bc')]));
      });
      test('Two insertions', () {
        expect(diff('abc', 'a123b456c', checklines: false),
            equals([deq('a'), dins('123'), deq('b'), dins('456'), deq('c')]));
      });
      test('Two deletions', () {
        expect(diff('a123b456c', 'abc', checklines: false),
            equals([deq('a'), ddel('123'), deq('b'), ddel('456'), deq('c')]));
      });
      test('Simple case #1', () {
        expect(diff('a', 'b', checklines: false, timeout: 0.0),
            equals([ddel('a'), dins('b')]));
      });

      test('Simple case #2', () {
        expect(
            diff('Apples are a fruit.', 'Bananas are also fruit.',
                checklines: false, timeout: 0.0),
            equals([
              ddel('Apple'),
              dins('Banana'),
              deq('s are a'),
              dins('lso'),
              deq(' fruit.')
            ]));
      });

      test('Simple case #3', () {
        expect(
            diff('ax\t', '\u0680x\000', checklines: false, timeout: 0.0),
            equals([
              ddel('a'),
              dins('\u0680'),
              deq('x'),
              ddel('\t'),
              dins('\000')
            ]));
      });
      test('Overlap #1', () {
        expect(
            diff('1ayb2', 'abxab', checklines: false, timeout: 0.0),
            equals([
              ddel('1'),
              deq('a'),
              ddel('y'),
              deq('b'),
              ddel('2'),
              dins('xab')
            ]));
      });
      test('Overlap #2', () {
        expect(diff('abcy', 'xaxcxabc', checklines: false, timeout: 0.0),
            equals([dins('xaxcx'), deq('abc'), ddel('y')]));
      });
      test('Overlap #3', () {
        expect(
            diff('ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg',
                'a-bcd-efghijklmnopqrs',
                checklines: false, timeout: 0.0),
            equals([
              ddel('ABCD'),
              deq('a'),
              ddel('='),
              dins('-'),
              deq('bcd'),
              ddel('='),
              dins('-'),
              deq('efghijklmnopqrs'),
              ddel('EFGHIJKLMNOefg')
            ]));
      });
      test('Large equality', () {
        expect(
            diff('a [[Pennsylvania]] and [[New', ' and [[Pennsylvania]]',
                checklines: false, timeout: 0.0),
            equals([
              dins(' '),
              deq('a'),
              dins('nd'),
              deq(' [[Pennsylvania]]'),
              ddel(' and [[New')
            ]));
      });

      // Test the linemode speedup.
      // Must be long to pass the 100 char cutoff.
      test('Simple line-mode', () {
        var a =
            '1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n';
        var b =
            'abcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\n';
        expect(diff(a, b, timeout: 0.0), equals(diff(a, b, checklines: false)));
      });

      test('Single line-mode', () {
        var a =
            '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890';
        var b =
            'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij';
        expect(diff(a, b, timeout: 0.0), equals(diff(a, b, checklines: false)));
      });

      test('Overlap line-mode', () {
        var a =
            '1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n';
        var b =
            'abcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n';
        var texts_linemode = _rebuildTexts(diff(a, b));
        var texts_textmode = _rebuildTexts(diff(a, b, checklines: false));
        expect(texts_textmode, equals(texts_linemode));
      });

      test('Timeout min', () {
        var a =
            '`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n';
        var b =
            'I am the very model of a modern major general,\nI\'ve information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n';
        // Increase the text lengths by 1024 times to ensure a timeout.
        for (var x = 0; x < 10; x++) {
          a = '$a$a';
          b = '$b$b';
        }
        var startTime = DateTime.now();
        diff(a, b, timeout: 0.1);
        var endTime = DateTime.now();
        var elapsedSeconds =
            endTime.difference(startTime).inMilliseconds / 1000;
        // Test that we took at least the timeout period.
        expect(0.1, lessThanOrEqualTo(elapsedSeconds));
      });

      test('Null', () {
        expect(() => diff(null, null), throwsArgumentError);
      });
    });
  });
}
