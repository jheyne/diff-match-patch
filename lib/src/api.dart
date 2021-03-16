/**
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

library api;

import 'package:diff_match_patch/src/diff.dart' as d;
import 'package:diff_match_patch/src/match.dart' as m;
import 'package:diff_match_patch/src/patch.dart' as p;

/**
 * Class containing the [diff], [match] and [patch] methods.
 * Also contains the behaviour settings.
 */
class DiffMatchPatch {

  // Defaults.
  // Set these on your diff_match_patch instance to override the defaults.

  /**
   * Number of seconds to map a diff before giving up (0 for infinity).
   */
  double diffTimeout = 1.0;

  /**
   * Cost of an empty edit operation in terms of edit characters.
   */
  int diffEditCost = 4;

  /**
   * At what point is no match declared (0.0 = perfection, 1.0 = very loose).
   */
  double matchThreshold = 0.5;

  /**
   * How far to search for a match (0 = exact location, 1000+ = broad match).
   * A match this many characters away from the expected location will add
   * 1.0 to the score (0.0 is a perfect match).
   */
  int matchDistance = 1000;

  /**
   * When deleting a large block of text (over ~64 characters), how close do
   * the contents have to be to match the expected contents. (0.0 = perfection,
   * 1.0 = very loose).  Note that [matchThreshold] controls how closely the
   * end points of a delete need to match.
   */
  double patchDeleteThreshold = 0.5;

  /**
   * Chunk size for context length.
   */
  int patchMargin = 4;

  /**
   * Find the differences between two texts.  Simplifies the problem by
   * stripping any common prefix or suffix off the texts before diffing.
   *
   * * [text1] is the old string to be diffed.
   * * [text2] is the new string to be diffed.
   * * [checklines] is an optional speedup flag.  If false, then don't
   *   run a line-level diff first to identify the changed areas.
   *   Defaults to true, which does a faster, slightly less optimal diff.
   * * [deadline] is an optional time when the diff should be complete by.  Used
   *   internally for recursive calls.  Users should set [diffTimeout] instead.
   *
   * Returns a List of [Diff] objects.
   */
  List<d.Diff> diff(String text1, String text2,
                    [bool checklines = true, DateTime? deadline]) {
    return d.diff(text1, text2, checklines: checklines, deadline: deadline,
        timeout: diffTimeout);
  }

  /**
   * Reduce the number of edits by eliminating semantically trivial equalities.
   *
   * [diffs] is a List of Diff objects.
   */
  void diffCleanupSemantic(List<d.Diff> diffs) {
    d.cleanupSemantic(diffs);
  }

  /**
   * Reduce the number of edits by eliminating operationally trivial equalities.
   *
   * [diffs] is a List of Diff objects.
   */
  void diffCleanupEfficiency(List<d.Diff> diffs) {
    d.cleanupEfficiency(diffs, diffEditCost);
  }

  /**
   * Compute the Levenshtein distance; the number of inserted, deleted or
   * substituted characters.
   *
   * [diffs] is a List of Diff objects.
   *
   * Returns the number of changes.
   */
  int diff_levenshtein(List<d.Diff> diffs) {
    return d.levenshtein(diffs);
  }

  /**
   * Locate the best instance of [pattern] in [text] near [loc].
   * Returns -1 if no match found.
   *
   * * [text] is the text to search.
   * * [pattern] is the pattern to search for.
   * * [loc] is the location to search around.
   *
   * Returns the best match index or -1.
   */
  int match(String text, String pattern, int loc) {
    return m.match(text, pattern, loc, threshold: matchThreshold,
        distance: matchDistance);
  }

  /**
   * Compute a list of patches to turn text1 into text2.
   * Use diffs if provided, otherwise compute it ourselves.
   *
   * There are four ways to call this function, depending on what data is
   * available to the caller:
   *
   * * Method 1:
   *   [a] = text1, [opt_b] = text2
   * * Method 2:
   *   [a] = diffs
   * * Method 3 (optimal):
   *   [a] = text1, [opt_b] = diffs
   * * Method 4 (deprecated, use method 3):
   *   [a] = text1, [opt_b] = text2, [opt_c] = diffs
   *
   * Returns a List of Patch objects.
   */
  List<p.Patch> patch(Object a, [Object? opt_b, Object? opt_c]) {
    return p.patchMake(a, b: opt_b, c: opt_c, diffTimeout: diffTimeout,
        diffEditCost: diffEditCost, deleteThreshold: patchDeleteThreshold,
        margin: patchMargin);
  }

  /**
   * Merge a set of patches onto the text.  Return a patched text, as well
   * as an array of true/false values indicating which patches were applied.
   *
   * * [patches] is a List of Patch objects
   * * [text] is the old text.
   *
   * Returns a two element List, containing the new text and a List of
   *      bool values.
   */
  List patch_apply(List<p.Patch> patches, String text) {
    return p.patchApply(patches, text, diffTimeout: diffTimeout,
        deleteThreshold: patchDeleteThreshold, margin: patchMargin);
  }
}
