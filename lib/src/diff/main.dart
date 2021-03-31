/// Main functions
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

part of diff;

/// Find the differences between two texts.  Simplifies the problem by
/// stripping any common prefix or suffix off the texts before diffing.
///
/// * [text1] is the old string to be diffed.
/// * [text2] is the new string to be diffed.
/// * [timeout]  is an optional number of seconds to map a diff before giving up
///   (0 for infinity).
/// * [checklines] is an optional speedup flag.  If false, then don't
///   run a line-level diff first to identify the changed areas.
///   Defaults to true, which does a faster, slightly less optimal diff.
/// * [deadline] is an optional time when the diff should be complete by.  Used
///   internally for recursive calls.  Users should set [diffTimeout] instead.
///
/// Returns a List of Diff objects.
List<Diff> diff(String text1, String text2,
    {double timeout = 1.0, bool checklines = true, DateTime deadline}) {
  // Set a deadline by which time the diff must be complete.
  if (deadline == null) {
    deadline = DateTime.now();
    if (timeout <= 0) {
      // One year should be sufficient for 'infinity'.
      deadline = deadline.add(Duration(days: 365));
    } else {
      deadline = deadline.add(Duration(milliseconds: (timeout * 1000).toInt()));
    }
  }
  // Check for null inputs.
  if (text1 == null || text2 == null) {
    throw ArgumentError('Null inputs. (diff_main)');
  }

  // Check for equality (speedup).
  List<Diff> diffs;
  if (text1 == text2) {
    diffs = [];
    if (text1.isNotEmpty) {
      diffs.add(Diff(DIFF_EQUAL, text1));
    }
    return diffs;
  }

  // Trim off common prefix (speedup).
  var commonlength = commonPrefix(text1, text2);
  var commonprefix = text1.substring(0, commonlength);
  text1 = text1.substring(commonlength);
  text2 = text2.substring(commonlength);

  // Trim off common suffix (speedup).
  commonlength = commonSuffix(text1, text2);
  var commonsuffix = text1.substring(text1.length - commonlength);
  text1 = text1.substring(0, text1.length - commonlength);
  text2 = text2.substring(0, text2.length - commonlength);

  // Compute the diff on the middle block.
  diffs = _diffCompute(text1, text2, timeout, checklines, deadline);

  // Restore the prefix and suffix.
  if (commonprefix.isNotEmpty) {
    diffs.insert(0, Diff(DIFF_EQUAL, commonprefix));
  }
  if (commonsuffix.isNotEmpty) {
    diffs.add(Diff(DIFF_EQUAL, commonsuffix));
  }

  cleanupMerge(diffs);
  return diffs;
}

/// Find the differences between two texts.  Assumes that the texts do not
/// have any common prefix or suffix.
///
/// * [text1] is the old string to be diffed.
/// * [text2] is the new string to be diffed.
/// * [timeout]  is a number of seconds to map a diff before giving up
///   (0 for infinity).
/// * [checklines] is a speedup flag.  If false, then don't run a
///   line-level diff first to identify the changed areas.
///   If true, then run a faster slightly less optimal diff.
/// * [deadline] is the time when the diff should be complete by.
///
/// Returns a List of Diff objects.
List<Diff> _diffCompute(String text1, String text2, double timeout,
    bool checklines, DateTime deadline) {
  var diffs = <Diff>[];

  if (text1.isEmpty) {
    // Just add some text (speedup).
    diffs.add(Diff(DIFF_INSERT, text2));
    return diffs;
  }

  if (text2.isEmpty) {
    // Just delete some text (speedup).
    diffs.add(Diff(DIFF_DELETE, text1));
    return diffs;
  }

  var longtext = text1.length > text2.length ? text1 : text2;
  var shorttext = text1.length > text2.length ? text2 : text1;
  var i = longtext.indexOf(shorttext);
  if (i != -1) {
    // Shorter text is inside the longer text (speedup).
    var op = (text1.length > text2.length) ? DIFF_DELETE : DIFF_INSERT;
    diffs.add(Diff(op, longtext.substring(0, i)));
    diffs.add(Diff(DIFF_EQUAL, shorttext));
    diffs.add(Diff(op, longtext.substring(i + shorttext.length)));
    return diffs;
  }

  if (shorttext.length == 1) {
    // Single character string.
    // After the previous speedup, the character can't be an equality.
    diffs.add(Diff(DIFF_DELETE, text1));
    diffs.add(Diff(DIFF_INSERT, text2));
    return diffs;
  }

  // Check to see if the problem can be split in two.
  final hm = diffHalfMatch(text1, text2, timeout);
  if (hm != null) {
    // A half-match was found, sort out the return data.
    final text1_a = hm[0];
    final text1_b = hm[1];
    final text2_a = hm[2];
    final text2_b = hm[3];
    final mid_common = hm[4];
    // Send both pairs off for separate processing.
    final diffs_a = diff(text1_a, text2_a,
        timeout: timeout, checklines: checklines, deadline: deadline);
    final diffs_b = diff(text1_b, text2_b,
        timeout: timeout, checklines: checklines, deadline: deadline);
    // Merge the results.
    diffs = diffs_a;
    diffs.add(Diff(DIFF_EQUAL, mid_common));
    diffs.addAll(diffs_b);
    return diffs;
  }

  if (checklines && text1.length > 100 && text2.length > 100) {
    return _diffLineMode(text1, text2, timeout, deadline);
  }

  return diffBisect(text1, text2, timeout, deadline);
}

/// Do a quick line-level diff on both strings, then rediff the parts for
/// greater accuracy.
/// This speedup can produce non-minimal diffs.
///
/// * [text1] is the old string to be diffed.
/// * [text2] is the new string to be diffed.
/// * [timeout]  is a number of seconds to map a diff before giving up
///   (0 for infinity).
/// * [deadline] is the time when the diff should be complete by.
///
/// Returns a List of Diff objects.
List<Diff> _diffLineMode(
    String text1, String text2, double timeout, DateTime deadline) {
  // Scan the text on a line-by-line basis first.
  final a = linesToChars(text1, text2);
  text1 = a['chars1'] as String;
  text2 = a['chars2'] as String;
  final linearray = a['lineArray'] as List<String>;

  final diffs = diff(text1, text2,
      timeout: timeout, checklines: false, deadline: deadline);

  // Convert the diff back to original text.
  charsToLines(diffs, linearray);
  // Eliminate freak matches (e.g. blank lines)
  cleanupSemantic(diffs);

  // Rediff any replacement blocks, this time character-by-character.
  // Add a dummy entry at the end.
  diffs.add(Diff(DIFF_EQUAL, ''));
  var pointer = 0;
  var count_delete = 0;
  var count_insert = 0;
  final text_delete = StringBuffer();
  final text_insert = StringBuffer();
  while (pointer < diffs.length) {
    switch (diffs[pointer].operation) {
      case DIFF_INSERT:
        count_insert++;
        text_insert.write(diffs[pointer].text);
        break;
      case DIFF_DELETE:
        count_delete++;
        text_delete.write(diffs[pointer].text);
        break;
      case DIFF_EQUAL:
        // Upon reaching an equality, check for prior redundancies.
        if (count_delete >= 1 && count_insert >= 1) {
          // Delete the offending records and add the merged ones.
          diffs.removeRange(pointer - count_delete - count_insert, pointer);
          pointer = pointer - count_delete - count_insert;
          final a = diff(text_delete.toString(), text_insert.toString(),
              timeout: timeout, checklines: false, deadline: deadline);
          for (var j = a.length - 1; j >= 0; j--) {
            diffs.insert(pointer, a[j]);
          }
          pointer = pointer + a.length;
        }
        count_insert = 0;
        count_delete = 0;
        text_delete.clear();
        text_insert.clear();
        break;
    }
    pointer++;
  }
  diffs.removeLast(); // Remove the dummy entry at the end.

  return diffs;
}

/// Find the 'middle snake' of a diff, split the problem in two
/// and return the recursively constructed diff.
///
/// See Myers 1986 paper: An O(ND) Difference Algorithm and Its Variations.
///
/// * [text1] is the old string to be diffed.
/// * [text2] is the new string to be diffed.
/// * [timeout]  is a number of seconds to map a diff before giving up
///   (0 for infinity).
/// * [deadline] is the time at which to bail if not yet complete.
///
/// Returns a List of Diff objects.
List<Diff> diffBisect(
    String text1, String text2, double timeout, DateTime deadline) {
  // Cache the text lengths to prevent multiple calls.
  final text1_length = text1.length;
  final text2_length = text2.length;
  final max_d = (text1_length + text2_length + 1) ~/ 2;
  final v_offset = max_d;
  final v_length = 2 * max_d;
  final v1 = List<int>.filled(v_length, null);
  final v2 = List<int>.filled(v_length, null);
  for (var x = 0; x < v_length; x++) {
    v1[x] = -1;
    v2[x] = -1;
  }
  v1[v_offset + 1] = 0;
  v2[v_offset + 1] = 0;
  final delta = text1_length - text2_length;
  // If the total number of characters is odd, then the front path will
  // collide with the reverse path.
  final front = (delta % 2 != 0);
  // Offsets for start and end of k loop.
  // Prevents mapping of space beyond the grid.
  var k1start = 0;
  var k1end = 0;
  var k2start = 0;
  var k2end = 0;
  for (var d = 0; d < max_d; d++) {
    // Bail out if deadline is reached.
    if ((DateTime.now()).compareTo(deadline) == 1) {
      break;
    }

    // Walk the front path one step.
    for (var k1 = -d + k1start; k1 <= d - k1end; k1 += 2) {
      var k1_offset = v_offset + k1;
      int x1;
      if (k1 == -d || k1 != d && v1[k1_offset - 1] < v1[k1_offset + 1]) {
        x1 = v1[k1_offset + 1];
      } else {
        x1 = v1[k1_offset - 1] + 1;
      }
      var y1 = x1 - k1;
      while (x1 < text1_length && y1 < text2_length && text1[x1] == text2[y1]) {
        x1++;
        y1++;
      }
      v1[k1_offset] = x1;
      if (x1 > text1_length) {
        // Ran off the right of the graph.
        k1end += 2;
      } else if (y1 > text2_length) {
        // Ran off the bottom of the graph.
        k1start += 2;
      } else if (front) {
        var k2_offset = v_offset + delta - k1;
        if (k2_offset >= 0 && k2_offset < v_length && v2[k2_offset] != -1) {
          // Mirror x2 onto top-left coordinate system.
          var x2 = text1_length - v2[k2_offset];
          if (x1 >= x2) {
            // Overlap detected.
            return _diffBisectSplit(text1, text2, x1, y1, timeout, deadline);
          }
        }
      }
    }

    // Walk the reverse path one step.
    for (var k2 = -d + k2start; k2 <= d - k2end; k2 += 2) {
      var k2_offset = v_offset + k2;
      int x2;
      if (k2 == -d || k2 != d && v2[k2_offset - 1] < v2[k2_offset + 1]) {
        x2 = v2[k2_offset + 1];
      } else {
        x2 = v2[k2_offset - 1] + 1;
      }
      var y2 = x2 - k2;
      while (x2 < text1_length &&
          y2 < text2_length &&
          text1[text1_length - x2 - 1] == text2[text2_length - y2 - 1]) {
        x2++;
        y2++;
      }
      v2[k2_offset] = x2;
      if (x2 > text1_length) {
        // Ran off the left of the graph.
        k2end += 2;
      } else if (y2 > text2_length) {
        // Ran off the top of the graph.
        k2start += 2;
      } else if (!front) {
        var k1_offset = v_offset + delta - k2;
        if (k1_offset >= 0 && k1_offset < v_length && v1[k1_offset] != -1) {
          var x1 = v1[k1_offset];
          var y1 = v_offset + x1 - k1_offset;
          // Mirror x2 onto top-left coordinate system.
          x2 = text1_length - x2;
          if (x1 >= x2) {
            // Overlap detected.
            return _diffBisectSplit(text1, text2, x1, y1, timeout, deadline);
          }
        }
      }
    }
  }
  // Diff took too long and hit the deadline or
  // number of diffs equals number of characters, no commonality at all.
  return [Diff(DIFF_DELETE, text1), Diff(DIFF_INSERT, text2)];
}

/// Given the location of the 'middle snake', split the diff in two parts
/// and recurse.
///
/// * [text1] is the old string to be diffed.
/// * [text2] is the new string to be diffed.
/// * [x] is the index of split point in text1.
/// * [y] is the index of split point in text2.
/// * [timeout] is a number of seconds to map a diff before giving up
///   (0 for infinity).
/// * [deadline] is the time at which to bail if not yet complete.
///
/// Returns a List of Diff objects.
List<Diff> _diffBisectSplit(String text1, String text2, int x, int y,
    double timeout, DateTime deadline) {
  final text1a = text1.substring(0, x);
  final text2a = text2.substring(0, y);
  final text1b = text1.substring(x);
  final text2b = text2.substring(y);

  // Compute both diffs serially.
  final diffs = diff(text1a, text2a,
      timeout: timeout, checklines: false, deadline: deadline);
  final diffsb = diff(text1b, text2b,
      timeout: timeout, checklines: false, deadline: deadline);

  diffs.addAll(diffsb);
  return diffs;
}
