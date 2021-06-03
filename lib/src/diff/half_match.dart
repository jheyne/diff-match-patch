/**
 * Half Match functions
 *
 * Copyright 2011 Google Inc.
 * Copyright 2014 Boris Kaul <localvoid@gmail.com>
 * http://github.com/localvoid/diff-match-patch
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of diff;

/**
 * Do the two texts share a substring which is at least half the length of
 * the longer text?
 *
 * This speedup can produce non-minimal diffs.
 *
 * * [text1] is the first string.
 * * [text2] is the second string.
 *
 * Returns a five element List of Strings, containing the prefix of [text1],
 * the suffix of [text1], the prefix of [text2], the suffix of [text2] and the
 * common middle.  Or null if there was no match.
 */
List<String>? diffHalfMatch(String text1, String text2, double timeout) {
  if (timeout <= 0) {
    // Don't risk returning a non-optimal diff if we have unlimited time.
    return null;
  }
  final longtext = text1.length > text2.length ? text1 : text2;
  final shorttext = text1.length > text2.length ? text2 : text1;
  if (longtext.length < 4 || shorttext.length * 2 < longtext.length) {
    return null;  // Pointless.
  }

  // First check if the second quarter is the seed for a half-match.
  final hm1 = _diffHalfMatchI(longtext, shorttext,
      ((longtext.length + 3) / 4).ceil().toInt());
  // Check again based on the third quarter.
  final hm2 = _diffHalfMatchI(longtext, shorttext,
      ((longtext.length + 1) / 2).ceil().toInt());
  List<String>? hm;
  if (hm1 == null && hm2 == null) {
    return null;
  } else if (hm2 == null) {
    hm = hm1;
  } else if (hm1 == null) {
    hm = hm2;
  } else {
    // Both matched.  Select the longest.
    hm = hm1[4].length > hm2[4].length ? hm1 : hm2;
  }

  // A half-match was found, sort out the return data.
  if (text1.length > text2.length) {
    return hm;
    //return [hm[0], hm[1], hm[2], hm[3], hm[4]];
  } else {
    return [hm![2], hm[3], hm[0], hm[1], hm[4]];
  }
}

/**
 * Does a substring of [shorttext] exist within [longtext] such that the
 * substring is at least half the length of [longtext]?
 *
 * * [longtext] is the longer string.
 * * [shorttext is the shorter string.
 * * [i] Start index of quarter length substring within longtext.
 *
 * Returns a five element String array, containing the prefix of [longtext],
 * the suffix of [longtext], the prefix of [shorttext], the suffix of
 * [shorttext] and the common middle.  Or null if there was no match.
 */
List<String>? _diffHalfMatchI(String longtext, String shorttext, int i) {
  // Start with a 1/4 length substring at position i as a seed.
  final seed = longtext.substring(i,
      i + (longtext.length / 4).floor().toInt());
  int j = -1;
  String best_common = '';
  String best_longtext_a = '', best_longtext_b = '';
  String best_shorttext_a = '', best_shorttext_b = '';
  while ((j = shorttext.indexOf(seed, j + 1)) != -1) {
    int prefixLength = commonPrefix(longtext.substring(i),
                                         shorttext.substring(j));
    int suffixLength = commonSuffix(longtext.substring(0, i),
                                         shorttext.substring(0, j));
    if (best_common.length < suffixLength + prefixLength) {
      best_common = '${shorttext.substring(j - suffixLength, j)}'
                    '${shorttext.substring(j, j + prefixLength)}';
      best_longtext_a = longtext.substring(0, i - suffixLength);
      best_longtext_b = longtext.substring(i + prefixLength);
      best_shorttext_a = shorttext.substring(0, j - suffixLength);
      best_shorttext_b = shorttext.substring(j + prefixLength);
    }
  }
  if (best_common.length * 2 >= longtext.length) {
    return [best_longtext_a, best_longtext_b,
            best_shorttext_a, best_shorttext_b, best_common];
  } else {
    return null;
  }
}
