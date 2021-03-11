/**
 * Cleanup functions
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

// Define some regex patterns for matching boundaries.
RegExp _nonAlphaNumericRegex = new RegExp(r'[^a-zA-Z0-9]');
RegExp _whitespaceRegex = new RegExp(r'\s');
RegExp _linebreakRegex = new RegExp(r'[\r\n]');
RegExp _blanklineEndRegex = new RegExp(r'\n\r?\n$');
RegExp _blanklineStartRegex = new RegExp(r'^\r?\n\r?\n');

/**
 * Reduce the number of edits by eliminating semantically trivial equalities.
 *
 * [diffs] is a List of Diff objects.
 */
void cleanupSemantic(List<Diff> diffs) {
  bool changes = false;
  // Stack of indices where equalities are found.
  final equalities = <int>[];
  // Always equal to diffs[equalities.last()].text
  String? lastequality = null;
  int pointer = 0;  // Index of current position.
  // Number of characters that changed prior to the equality.
  int length_insertions1 = 0;
  int length_deletions1 = 0;
  // Number of characters that changed after the equality.
  int length_insertions2 = 0;
  int length_deletions2 = 0;
  while (pointer < diffs.length) {
    if (diffs[pointer].operation == DIFF_EQUAL) {  // Equality found.
      equalities.add(pointer);
      length_insertions1 = length_insertions2;
      length_deletions1 = length_deletions2;
      length_insertions2 = 0;
      length_deletions2 = 0;
      lastequality = diffs[pointer].text;
    } else {  // An insertion or deletion.
      if (diffs[pointer].operation == DIFF_INSERT) {
        length_insertions2 += diffs[pointer].text!.length;
      } else {
        length_deletions2 += diffs[pointer].text!.length;
      }
      // Eliminate an equality that is smaller or equal to the edits on both
      // sides of it.
      if (lastequality != null
          && (lastequality.length
              <= max(length_insertions1, length_deletions1))
          && (lastequality.length
              <= max(length_insertions2, length_deletions2))) {
        // Duplicate record.
        diffs.insert(equalities.last, new Diff(DIFF_DELETE, lastequality));
        // Change second copy to insert.
        diffs[equalities.last + 1].operation = DIFF_INSERT;
        // Throw away the equality we just deleted.
        equalities.removeLast();
        // Throw away the previous equality (it needs to be reevaluated).
        if (!equalities.isEmpty) {
          equalities.removeLast();
        }
        pointer = equalities.isEmpty ? -1 : equalities.last;
        length_insertions1 = 0;  // Reset the counters.
        length_deletions1 = 0;
        length_insertions2 = 0;
        length_deletions2 = 0;
        lastequality = null;
        changes = true;
      }
    }
    pointer++;
  }

  // Normalize the diff.
  if (changes) {
    cleanupMerge(diffs);
  }
  cleanupSemanticLossless(diffs);

  // Find any overlaps between deletions and insertions.
  // e.g: <del>abcxxx</del><ins>xxxdef</ins>
  //   -> <del>abc</del>xxx<ins>def</ins>
  // e.g: <del>xxxabc</del><ins>defxxx</ins>
  //   -> <ins>def</ins>xxx<del>abc</del>
  // Only extract an overlap if it is as big as the edit ahead or behind it.
  pointer = 1;
  while (pointer < diffs.length) {
    if (diffs[pointer - 1].operation == DIFF_DELETE
        && diffs[pointer].operation == DIFF_INSERT) {
      String deletion = diffs[pointer - 1].text!;
      String insertion = diffs[pointer].text!;
      int overlap_length1 = commonOverlap(deletion, insertion);
      int overlap_length2 = commonOverlap(insertion, deletion);
      if (overlap_length1 >= overlap_length2) {
        if (overlap_length1 >= deletion.length / 2 ||
            overlap_length1 >= insertion.length / 2) {
          // Overlap found.
          // Insert an equality and trim the surrounding edits.
          diffs.insert(pointer,
              new Diff(DIFF_EQUAL, insertion.substring(0, overlap_length1)));
          diffs[pointer - 1].text =
              deletion.substring(0, deletion.length - overlap_length1);
          diffs[pointer + 1].text = insertion.substring(overlap_length1);
          pointer++;
        }
      } else {
        if (overlap_length2 >= deletion.length / 2 ||
            overlap_length2 >= insertion.length / 2) {
          // Reverse overlap found.
          // Insert an equality and swap and trim the surrounding edits.
          diffs.insert(pointer,
              new Diff(DIFF_EQUAL, deletion.substring(0, overlap_length2)));
          diffs[pointer - 1] = new Diff(DIFF_INSERT,
              insertion.substring(0, insertion.length - overlap_length2));
          diffs[pointer + 1] = new Diff(DIFF_DELETE,
              deletion.substring(overlap_length2));
          pointer++;
        }
      }
      pointer++;
    }
    pointer++;
  }
}

/**
 * Look for single edits surrounded on both sides by equalities
 * which can be shifted sideways to align the edit to a word boundary.
 *
 * e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
 *
 * [diffs] is a List of Diff objects.
 */
void cleanupSemanticLossless(List<Diff> diffs) {
  /**
   * Given two strings, compute a score representing whether the internal
   * boundary falls on logical boundaries.
   * Scores range from 6 (best) to 0 (worst).
   * Closure, but does not reference any external variables.
   * [one] the first string.
   * [two] the second string.
   * Returns the score.
   */
  int _cleanupSemanticScore(String one, String? two) {
    if (one.isEmpty || two!.isEmpty) {
      // Edges are the best.
      return 6;
    }

    // Each port of this function behaves slightly differently due to
    // subtle differences in each language's definition of things like
    // 'whitespace'.  Since this function's purpose is largely cosmetic,
    // the choice has been made to use each language's native features
    // rather than force total conformity.
    String char1 = one[one.length - 1];
    String char2 = two[0];
    bool nonAlphaNumeric1 = char1.contains(_nonAlphaNumericRegex);
    bool nonAlphaNumeric2 = char2.contains(_nonAlphaNumericRegex);
    bool whitespace1 = nonAlphaNumeric1 && char1.contains(_whitespaceRegex);
    bool whitespace2 = nonAlphaNumeric2 && char2.contains(_whitespaceRegex);
    bool lineBreak1 = whitespace1 && char1.contains(_linebreakRegex);
    bool lineBreak2 = whitespace2 && char2.contains(_linebreakRegex);
    bool blankLine1 = lineBreak1 && one.contains(_blanklineEndRegex);
    bool blankLine2 = lineBreak2 && two.contains(_blanklineStartRegex);

    if (blankLine1 || blankLine2) {
      // Five points for blank lines.
      return 5;
    } else if (lineBreak1 || lineBreak2) {
      // Four points for line breaks.
      return 4;
    } else if (nonAlphaNumeric1 && !whitespace1 && whitespace2) {
      // Three points for end of sentences.
      return 3;
    } else if (whitespace1 || whitespace2) {
      // Two points for whitespace.
      return 2;
    } else if (nonAlphaNumeric1 || nonAlphaNumeric2) {
      // One point for non-alphanumeric.
      return 1;
    }
    return 0;
  }

  int pointer = 1;
  // Intentionally ignore the first and last element (don't need checking).
  while (pointer < diffs.length - 1) {
    if (diffs[pointer - 1].operation == DIFF_EQUAL
        && diffs[pointer + 1].operation == DIFF_EQUAL) {
      // This is a single edit surrounded by equalities.
      String equality1 = diffs[pointer - 1].text!;
      String edit = diffs[pointer].text!;
      String? equality2 = diffs[pointer + 1].text;

      // First, shift the edit as far left as possible.
      int commonOffset = commonSuffix(equality1, edit);
      if (commonOffset != 0) {
        String commonString = edit.substring(edit.length - commonOffset);
        equality1 = equality1.substring(0, equality1.length - commonOffset);
        edit =
            '$commonString${edit.substring(0, edit.length - commonOffset)}';
        equality2 = '$commonString$equality2';
      }

      // Second, step character by character right, looking for the best fit.
      String bestEquality1 = equality1;
      String bestEdit = edit;
      String? bestEquality2 = equality2;
      int bestScore = _cleanupSemanticScore(equality1, edit)
          + _cleanupSemanticScore(edit, equality2);
      while (!edit.isEmpty && !equality2!.isEmpty
          && edit[0] == equality2[0]) {
        equality1 = '$equality1${edit[0]}';
        edit = '${edit.substring(1)}${equality2[0]}';
        equality2 = equality2.substring(1);
        int score = _cleanupSemanticScore(equality1, edit)
            + _cleanupSemanticScore(edit, equality2);
        // The >= encourages trailing rather than leading whitespace on edits.
        if (score >= bestScore) {
          bestScore = score;
          bestEquality1 = equality1;
          bestEdit = edit;
          bestEquality2 = equality2;
        }
      }

      if (diffs[pointer - 1].text != bestEquality1) {
        // We have an improvement, save it back to the diff.
        if (!bestEquality1.isEmpty) {
          diffs[pointer - 1].text = bestEquality1;
        } else {
          diffs.removeRange(pointer - 1, pointer);
          pointer--;
        }
        diffs[pointer].text = bestEdit;
        if (!bestEquality2!.isEmpty) {
          diffs[pointer + 1].text = bestEquality2;
        } else {
          diffs.removeRange(pointer + 1, pointer + 2);
          pointer--;
        }
      }
    }
    pointer++;
  }
}

/**
 * Reduce the number of edits by eliminating operationally trivial equalities.
 *
 * [diffs] is a List of Diff objects.
 */
void cleanupEfficiency(List<Diff> diffs, int diffEditCost) {
  bool changes = false;
  // Stack of indices where equalities are found.
  final equalities = <int>[];
  // Always equal to diffs[equalities.last()].text
  String? lastequality = null;
  int pointer = 0;  // Index of current position.
  // Is there an insertion operation before the last equality.
  bool pre_ins = false;
  // Is there a deletion operation before the last equality.
  bool pre_del = false;
  // Is there an insertion operation after the last equality.
  bool post_ins = false;
  // Is there a deletion operation after the last equality.
  bool post_del = false;
  while (pointer < diffs.length) {
    if (diffs[pointer].operation == DIFF_EQUAL) {  // Equality found.
      if (diffs[pointer].text!.length < diffEditCost
          && (post_ins || post_del)) {
        // Candidate found.
        equalities.add(pointer);
        pre_ins = post_ins;
        pre_del = post_del;
        lastequality = diffs[pointer].text;
      } else {
        // Not a candidate, and can never become one.
        equalities.clear();
        lastequality = null;
      }
      post_ins = post_del = false;
    } else {  // An insertion or deletion.
      if (diffs[pointer].operation == DIFF_DELETE) {
        post_del = true;
      } else {
        post_ins = true;
      }
      /*
       * Five types to be split:
       * <ins>A</ins><del>B</del>XY<ins>C</ins><del>D</del>
       * <ins>A</ins>X<ins>C</ins><del>D</del>
       * <ins>A</ins><del>B</del>X<ins>C</ins>
       * <ins>A</del>X<ins>C</ins><del>D</del>
       * <ins>A</ins><del>B</del>X<del>C</del>
       */
      if (lastequality != null
          && ((pre_ins && pre_del && post_ins && post_del)
          || ((lastequality.length < diffEditCost / 2)
          && ((pre_ins ? 1 : 0) + (pre_del ? 1 : 0) + (post_ins ? 1 : 0)
              + (post_del ? 1 : 0)) == 3))) {
        // Duplicate record.
        diffs.insert(equalities.last, new Diff(DIFF_DELETE, lastequality));
        // Change second copy to insert.
        diffs[equalities.last + 1].operation = DIFF_INSERT;
        equalities.removeLast();  // Throw away the equality we just deleted.
        lastequality = null;
        if (pre_ins && pre_del) {
          // No changes made which could affect previous entry, keep going.
          post_ins = post_del = true;
          equalities.clear();
        } else {
          if (!equalities.isEmpty) {
            equalities.removeLast();
          }
          pointer = equalities.isEmpty ? -1 : equalities.last;
          post_ins = post_del = false;
        }
        changes = true;
      }
    }
    pointer++;
  }

  if (changes) {
    cleanupMerge(diffs);
  }
}


/**
 * Reorder and merge like edit sections.  Merge equalities.
 * Any edit section can move as long as it doesn't cross an equality.
 *
 * [diffs] is a List of Diff objects.
 */
void cleanupMerge(List<Diff> diffs) {
  diffs.add(new Diff(DIFF_EQUAL, ''));  // Add a dummy entry at the end.
  int pointer = 0;
  int count_delete = 0;
  int count_insert = 0;
  String text_delete = '';
  String text_insert = '';
  int commonlength;
  while (pointer < diffs.length) {
    switch (diffs[pointer].operation) {
      case DIFF_INSERT:
        count_insert++;
        text_insert = '$text_insert${diffs[pointer].text}';
        pointer++;
        break;
      case DIFF_DELETE:
        count_delete++;
        text_delete = '$text_delete${diffs[pointer].text}';
        pointer++;
        break;
      case DIFF_EQUAL:
        // Upon reaching an equality, check for prior redundancies.
        if (count_delete + count_insert > 1) {
          if (count_delete != 0 && count_insert != 0) {
            // Factor out any common prefixies.
            commonlength = commonPrefix(text_insert, text_delete);
            if (commonlength != 0) {
              if ((pointer - count_delete - count_insert) > 0
                  && diffs[pointer - count_delete - count_insert - 1]
                  .operation == DIFF_EQUAL) {
                final i = pointer - count_delete - count_insert - 1;
                diffs[i].text = '${diffs[i].text}'
                    '${text_insert.substring(0, commonlength)}';
              } else {
                diffs.insert(0, new Diff(DIFF_EQUAL,
                             text_insert.substring(0, commonlength)));
                pointer++;
              }
              text_insert = text_insert.substring(commonlength);
              text_delete = text_delete.substring(commonlength);
            }
            // Factor out any common suffixies.
            commonlength = commonSuffix(text_insert, text_delete);
            if (commonlength != 0) {
              diffs[pointer].text =
                  '${text_insert.substring(text_insert.length
                  - commonlength)}${diffs[pointer].text}';
              text_insert = text_insert.substring(0, text_insert.length
                  - commonlength);
              text_delete = text_delete.substring(0, text_delete.length
                  - commonlength);
            }
          }
          // Delete the offending records and add the merged ones.
          if (count_delete == 0) {
            diffs.removeRange(pointer - count_insert, pointer);
            diffs.insert(pointer - count_insert,
                new Diff(DIFF_INSERT, text_insert));
          } else if (count_insert == 0) {
            diffs.removeRange(pointer - count_delete, pointer);
            diffs.insert(pointer - count_delete,
                new Diff(DIFF_DELETE, text_delete));
          } else {
            diffs.removeRange(pointer - count_delete - count_insert, pointer);
            diffs.insert(pointer - count_delete - count_insert,
                new Diff(DIFF_INSERT, text_insert));
            diffs.insert(pointer - count_delete - count_insert,
                new Diff(DIFF_DELETE, text_delete));
          }
          pointer = pointer - count_delete - count_insert
                    + (count_delete == 0 ? 0 : 1)
                    + (count_insert == 0 ? 0 : 1) + 1;
        } else if (pointer != 0 && diffs[pointer - 1].operation
            == DIFF_EQUAL) {
          // Merge this equality with the previous one.
          diffs[pointer - 1].text =
              '${diffs[pointer - 1].text}${diffs[pointer].text}';
          diffs.removeRange(pointer, pointer+1);
        } else {
          pointer++;
        }
        count_insert = 0;
        count_delete = 0;
        text_delete = '';
        text_insert = '';
        break;
    }
  }
  if (diffs.last.text!.isEmpty) {
    diffs.removeLast();  // Remove the dummy entry at the end.
  }

  // Second pass: look for single edits surrounded on both sides by equalities
  // which can be shifted sideways to eliminate an equality.
  // e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
  bool changes = false;
  pointer = 1;
  // Intentionally ignore the first and last element (don't need checking).
  while (pointer < diffs.length - 1) {
    if (diffs[pointer - 1].operation == DIFF_EQUAL
        && diffs[pointer + 1].operation == DIFF_EQUAL) {
      // This is a single edit surrounded by equalities.
      if (diffs[pointer].text!.endsWith(diffs[pointer - 1].text!)) {
        // Shift the edit over the previous equality.
        diffs[pointer].text = '${diffs[pointer - 1].text}'
            '${diffs[pointer].text!.substring(0,
            diffs[pointer].text!.length - diffs[pointer - 1].text!.length)}';
        diffs[pointer + 1].text =
            '${diffs[pointer - 1].text}${diffs[pointer + 1].text}';
        diffs.removeRange(pointer - 1, pointer);
        changes = true;
      } else if (diffs[pointer].text!.startsWith(diffs[pointer + 1].text!)) {
        // Shift the edit over the next equality.
        diffs[pointer - 1].text =
            '${diffs[pointer - 1].text}${diffs[pointer + 1].text}';
        diffs[pointer].text =
            '${diffs[pointer].text!.substring(diffs[pointer + 1].text!.length)}'
            '${diffs[pointer + 1].text}';
        diffs.removeRange(pointer + 1, pointer + 2);
        changes = true;
      }
    }
    pointer++;
  }
  // If shifts were made, the diff needs reordering and another shift sweep.
  if (changes) {
    cleanupMerge(diffs);
  }
}
