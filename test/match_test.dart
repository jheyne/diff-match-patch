/// Tests for Match functions
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
import 'package:diff_match_patch/src/match.dart';

void main() {
  group('Match', () {
    group('Alphabet', () {
      void testMapEquals(Map a, Map b, String error_msg) {
        test(error_msg, () {
          expect(a.keys, unorderedEquals(b.keys));
        });
        for (var x in a.keys) {
          test('$error_msg [Key: $x]', () {
            expect(a[x], equals(b[x]));
          });
        }
      }

      // Initialise the bitmasks for Bitap.
      var bitmask = <String, int>{'a': 4, 'b': 2, 'c': 1};
      testMapEquals(bitmask, matchAlphabet('abc'), 'Unique.');

      bitmask = {'a': 37, 'b': 18, 'c': 8};
      testMapEquals(bitmask, matchAlphabet('abcaba'), 'Duplicates.');
    });

    group('Bitap', () {
      test('Exact match #1', () {
        expect(matchBitap('abcdefghijk', 'fgh', 5, 0.5, 100), equals(5));
      });
      test('Exact match #2', () {
        expect(matchBitap('abcdefghijk', 'fgh', 0, 0.5, 100), equals(5));
      });
      test('Fuzzy match #1', () {
        expect(matchBitap('abcdefghijk', 'efxhi', 0, 0.5, 100), equals(4));
      });
      test('Fuzzy match #2', () {
        expect(matchBitap('abcdefghijk', 'cdefxyhijk', 5, 0.5, 100), equals(2));
      });
      test('Fuzzy match #3', () {
        expect(matchBitap('abcdefghijk', 'bxy', 1, 0.5, 100), equals(-1));
      });
      test('Overflow', () {
        expect(matchBitap('123456789xx0', '3456789x0', 2, 0.5, 100), equals(2));
      });
      test('Before start match', () {
        expect(matchBitap('abcdef', 'xxabc', 4, 0.5, 100), equals(0));
      });
      test('Beyond end match', () {
        expect(matchBitap('abcdef', 'defyy', 4, 0.5, 100), equals(3));
      });
      test('Oversized pattern', () {
        expect(matchBitap('abcdef', 'xabcdefy', 0, 0.5, 100), equals(0));
      });
      test('Threshold #1', () {
        expect(matchBitap('abcdefghijk', 'efxyhi', 1, 0.4, 100), equals(4));
      });
      test('Threshold #2', () {
        expect(matchBitap('abcdefghijk', 'efxyhi', 1, 0.3, 100), equals(-1));
      });
      test('Threshold #3', () {
        expect(matchBitap('abcdefghijk', 'bcdef', 1, 0.0, 100), equals(1));
      });
      test('Multiple select #1', () {
        expect(matchBitap('abcdexyzabcde', 'abccde', 3, 0.5, 100), equals(0));
      });
      test('Multiple select #2', () {
        expect(matchBitap('abcdexyzabcde', 'abccde', 5, 0.5, 100), equals(8));
      });
      test('Distance test #1', () {
        expect(matchBitap('abcdefghijklmnopqrstuvwxyz', 'abcdefg', 24, 0.5, 10),
            equals(-1));
      });
      test('Distance test #2', () {
        expect(
            matchBitap('abcdefghijklmnopqrstuvwxyz', 'abcdxxefg', 1, 0.5, 10),
            equals(0));
      });
      test('Distance test #3', () {
        expect(
            matchBitap('abcdefghijklmnopqrstuvwxyz', 'abcdefg', 24, 0.5, 1000),
            equals(0));
      });
    });

    group('Main', () {
      test('Equality', () {
        expect(match('abcdef', 'abcdef', 1000), equals(0));
      });
      test('Null text', () {
        expect(match('', 'abcdef', 1), equals(-1));
      });
      test('Null pattern', () {
        expect(match('abcdef', '', 3), equals(3));
      });
      test('Exact match', () {
        expect(match('abcdef', 'de', 3), equals(3));
      });
      test('Beyond end match', () {
        expect(match('abcdef', 'defy', 4), equals(3));
      });
      test('Oversized pattern', () {
        expect(match('abcdef', 'abcdefy', 0), equals(0));
      });
      test('Complex match', () {
        expect(
            match('I am the very model of a modern major general.',
                ' that berry ', 5,
                threshold: 0.7),
            equals(4));
      });
      test('Null inputs', () {
        expect(() => match(null, null, 0), throwsArgumentError);
      });
    });
  });
}
