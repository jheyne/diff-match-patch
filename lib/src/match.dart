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

library match;

import 'dart:collection';
import 'dart:math';
import 'package:diff_match_patch/src/common.dart';

/// Locate the best instance of [pattern] in [text] near [loc].
/// Returns -1 if no match found.
///
/// * [text] is the text to search.
/// * [pattern] is the pattern to search for.
/// * [loc] is the location to search around.
/// * [threshold] At what point is no match declared (0.0 = perfection,
///   1.0 = very loose).
/// * [distance] How far to search for a match (0 = exact location, 1000+ = broad
///   match). A match this many characters away from the expected location will
///   add 1.0 to the score (0.0 is a perfect match).
///
/// Returns the best match index or -1.
int match(String text, String pattern, int loc,
    {double threshold = 0.5, int distance = 1000}) {
  // Check for null inputs.
  if (text == null || pattern == null) {
    throw ArgumentError('Null inputs. (match_main)');
  }

  loc = max(0, min(loc, text.length));
  if (text == pattern) {
    // Shortcut (potentially not guaranteed by the algorithm)
    return 0;
  } else if (text.isEmpty) {
    // Nothing to match.
    return -1;
  } else if (loc + pattern.length <= text.length &&
      text.substring(loc, loc + pattern.length) == pattern) {
    // Perfect match at the perfect spot!  (Includes case of null pattern)
    return loc;
  } else {
    // Do a fuzzy compare.
    return matchBitap(text, pattern, loc, threshold, distance);
  }
}

/// Compute and return the score for a match with [e] errors and [x] location.
///
/// * [e] is the number of errors in match.
/// * [x] is the location of match.
/// * [loc] is the expected location of match.
/// * [pattern] is the pattern being sought.
/// * [distance] How far to search for a match (0 = exact location, 1000+ = broad
///   match). A match this many characters away from the expected location will
///   add 1.0 to the score (0.0 is a perfect match).
///
/// Returns the overall score for match (0.0 = good, 1.0 = bad).
double _bitapScore(int e, int x, int loc, String pattern, int distance) {
  final accuracy = e / pattern.length;
  final proximity = (loc - x).abs();
  if (distance == 0) {
    // Dodge divide by zero error.
    return proximity == 0 ? accuracy : 1.0;
  }
  return accuracy + proximity / distance;
}

/// Locate the best instance of [pattern] in [text] near [loc] using the
/// Bitap algorithm.  Returns -1 if no match found.
///
/// * [text] is the the text to search.
/// * [pattern] is the pattern to search for.
/// * [loc] is the location to search around.
/// * [threshold] At what point is no match declared (0.0 = perfection,
///   1.0 = very loose).
/// * [distance] How far to search for a match (0 = exact location, 1000+ = broad
///   match). A match this many characters away from the expected location will
///   add 1.0 to the score (0.0 is a perfect match).
///
/// Returns the best match index or -1.
int matchBitap(
    String text, String pattern, int loc, double threshold, int distance) {
  // Pattern too long for this application.
  assert(BITS_PER_INT == 0 || pattern.length <= BITS_PER_INT);

  // Initialise the alphabet.
  var s = matchAlphabet(pattern);

  // Highest score beyond which we give up.
  var score_threshold = threshold;
  // Is there a nearby exact match? (speedup)
  var best_loc = text.indexOf(pattern, loc);
  if (best_loc != -1) {
    score_threshold =
        min(_bitapScore(0, best_loc, loc, pattern, distance), score_threshold);
    // What about in the other direction? (speedup)
    best_loc = text.lastIndexOf(pattern, loc + pattern.length);
    if (best_loc != -1) {
      score_threshold = min(
          _bitapScore(0, best_loc, loc, pattern, distance), score_threshold);
    }
  }

  // Initialise the bit arrays.
  final match_mask = 1 << (pattern.length - 1);
  best_loc = -1;

  int bin_min, bin_mid;
  var bin_max = pattern.length + text.length;
  List<int> last_rd;
  for (var d = 0; d < pattern.length; d++) {
    // Scan for the best match; each iteration allows for one more error.
    // Run a binary search to determine how far from 'loc' we can stray at
    // this error level.
    bin_min = 0;
    bin_mid = bin_max;
    while (bin_min < bin_mid) {
      if (_bitapScore(d, loc + bin_mid, loc, pattern, distance) <=
          score_threshold) {
        bin_min = bin_mid;
      } else {
        bin_max = bin_mid;
      }
      bin_mid = ((bin_max - bin_min) / 2 + bin_min).toInt();
    }
    // Use the result from this iteration as the maximum for the next.
    bin_max = bin_mid;
    var start = max(1, loc - bin_mid + 1);
    var finish = min(loc + bin_mid, text.length) + pattern.length;

    final rd = List<int>.filled(finish + 2, null);
    rd[finish + 1] = (1 << d) - 1;
    for (var j = finish; j >= start; j--) {
      int charMatch;
      if (text.length <= j - 1 || !s.containsKey(text[j - 1])) {
        // Out of range.
        charMatch = 0;
      } else {
        charMatch = s[text[j - 1]];
      }
      if (d == 0) {
        // First pass: exact match.
        rd[j] = ((rd[j + 1] << 1) | 1) & charMatch;
      } else {
        // Subsequent passes: fuzzy match.
        rd[j] = ((rd[j + 1] << 1) | 1) & charMatch |
            (((last_rd[j + 1] | last_rd[j]) << 1) | 1) |
            last_rd[j + 1];
      }
      if ((rd[j] & match_mask) != 0) {
        var score = _bitapScore(d, j - 1, loc, pattern, distance);
        // This match will almost certainly be better than any existing
        // match.  But check anyway.
        if (score <= score_threshold) {
          // Told you so.
          score_threshold = score;
          best_loc = j - 1;
          if (best_loc > loc) {
            // When passing loc, don't exceed our current distance from loc.
            start = max(1, 2 * loc - best_loc);
          } else {
            // Already passed loc, downhill from here on in.
            break;
          }
        }
      }
    }
    if (_bitapScore(d + 1, loc, loc, pattern, distance) > score_threshold) {
      // No hope for a (better) match at greater error levels.
      break;
    }
    last_rd = rd;
  }
  return best_loc;
}

/// Initialise the alphabet for the Bitap algorithm.
///
/// [pattern] is the the text to encode.
/// Returns a Map of character locations.
Map<String, int> matchAlphabet(String pattern) {
  final s = HashMap<String, int>();
  for (var i = 0; i < pattern.length; i++) {
    s[pattern[i]] = 0;
  }
  for (var i = 0; i < pattern.length; i++) {
    s[pattern[i]] = s[pattern[i]] | (1 << (pattern.length - i - 1));
  }
  return s;
}
