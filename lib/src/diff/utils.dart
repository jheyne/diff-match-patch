/// Misc functions
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

/// Split a text into a list of strings.  Reduce the texts to a string of
/// hashes where each Unicode character represents one line.
///
/// * [text] is the string to encode.
/// * [lineArray] is a List of unique strings.
/// * [lineHash] is a Map of strings to indices.
///
/// Returns an encoded string.
String _linesToCharsMunge(
    String text, List<String> lineArray, Map<String, int> lineHash) {
  var lineStart = 0;
  var lineEnd = -1;
  String line;
  final chars = StringBuffer();
  // Walk the text, pulling out a substring for each line.
  // text.split('\n') would would temporarily double our memory footprint.
  // Modifying text would create many large strings to garbage collect.
  while (lineEnd < text.length - 1) {
    lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) {
      lineEnd = text.length - 1;
    }
    line = text.substring(lineStart, lineEnd + 1);
    lineStart = lineEnd + 1;

    if (lineHash.containsKey(line)) {
      chars.write(String.fromCharCodes([lineHash[line]]));
    } else {
      lineArray.add(line);
      lineHash[line] = lineArray.length - 1;
      chars.write(String.fromCharCodes([lineArray.length - 1]));
    }
  }
  return chars.toString();
}

/// Split two texts into a list of strings.  Reduce the texts to a string of
/// hashes where each Unicode character represents one line.
///
/// * [text1] is the first string.
/// * [text2] is the second string.
///
/// Returns a Map containing the encoded [text1], the encoded [text2] and
/// the List of unique strings.  The zeroth element of the List of
/// unique strings is intentionally blank.
Map<String, dynamic> linesToChars(String text1, String text2) {
  final lineArray = <String>[];
  final lineHash = HashMap<String, int>();
  // e.g. linearray[4] == 'Hello\n'
  // e.g. linehash['Hello\n'] == 4

  // '\x00' is a valid character, but various debuggers don't like it.
  // So we'll insert a junk entry to avoid generating a null character.
  lineArray.add('');

  var chars1 = _linesToCharsMunge(text1, lineArray, lineHash);
  var chars2 = _linesToCharsMunge(text2, lineArray, lineHash);
  return <String, dynamic>{
    'chars1': chars1,
    'chars2': chars2,
    'lineArray': lineArray
  };
}

/// Rehydrate the text in a diff from a string of line hashes to real lines of
/// text.
///
/// * [diffs] is a List of Diff objects.
/// * [lineArray] is a List of unique strings.
void charsToLines(List<Diff> diffs, List<String> lineArray) {
  final text = StringBuffer();
  for (var diff in diffs) {
    for (var y = 0; y < diff.text.length; y++) {
      text.write(lineArray[diff.text.codeUnitAt(y)]);
    }
    diff.text = text.toString();
    text.clear();
  }
}

/// Determine the common prefix of two strings
///
/// * [text1] is the first string.
/// * [text2] is the second string.
///
/// Returns the number of characters common to the start of each string.
int commonPrefix(String text1, String text2) {
  // TODO: Once Dart's performance stabilizes, determine if linear or binary
  // search is better.
  // Performance analysis: http://neil.fraser.name/news/2007/10/09/
  final n = min(text1.length, text2.length);
  for (var i = 0; i < n; i++) {
    if (text1[i] != text2[i]) {
      return i;
    }
  }
  return n;
}

/// Determine the common suffix of two strings
///
/// * [text1] is the first string.
/// * [text2] is the second string.
///
/// Returns the number of characters common to the end of each string.
int commonSuffix(String text1, String text2) {
  // TODO: Once Dart's performance stabilizes, determine if linear or binary
  // search is better.
  // Performance analysis: http://neil.fraser.name/news/2007/10/09/
  final text1_length = text1.length;
  final text2_length = text2.length;
  final n = min(text1_length, text2_length);
  for (var i = 1; i <= n; i++) {
    if (text1[text1_length - i] != text2[text2_length - i]) {
      return i - 1;
    }
  }
  return n;
}

/// Determine if the suffix of one string is the prefix of another.
///
/// * [text1] is the first string.
/// * [text2] is the second string.
///
/// Returns the number of characters common to the end of the first
/// string and the start of the second string.
int commonOverlap(String text1, String text2) {
  // Eliminate the null case.
  if (text1.isEmpty || text2.isEmpty) {
    return 0;
  }
  // Cache the text lengths to prevent multiple calls.
  final text1_length = text1.length;
  final text2_length = text2.length;
  // Truncate the longer string.
  if (text1_length > text2_length) {
    text1 = text1.substring(text1_length - text2_length);
  } else if (text1_length < text2_length) {
    text2 = text2.substring(0, text1_length);
  }
  final text_length = min(text1_length, text2_length);
  // Quick check for the worst case.
  if (text1 == text2) {
    return text_length;
  }

  // Start by looking for a single character match
  // and increase length until no match is found.
  // Performance analysis: http://neil.fraser.name/news/2010/11/04/
  var best = 0;
  var length = 1;
  while (true) {
    var pattern = text1.substring(text_length - length);
    var found = text2.indexOf(pattern);
    if (found == -1) {
      return best;
    }
    length += found;
    if (found == 0 ||
        text1.substring(text_length - length) == text2.substring(0, length)) {
      best = length;
      length++;
    }
  }
}

/// Compute the Levenshtein distance; the number of inserted, deleted or
/// substituted characters.
///
/// [diffs] is a List of Diff objects.
///
/// Returns the number of changes.
int levenshtein(List<Diff> diffs) {
  var levenshtein = 0;
  var insertions = 0;
  var deletions = 0;
  for (var aDiff in diffs) {
    switch (aDiff.operation) {
      case DIFF_INSERT:
        insertions += aDiff.text.length;
        break;
      case DIFF_DELETE:
        deletions += aDiff.text.length;
        break;
      case DIFF_EQUAL:
        // A deletion and an insertion is one substitution.
        levenshtein += max(insertions, deletions).toInt();
        insertions = 0;
        deletions = 0;
        break;
    }
  }
  levenshtein += max(insertions, deletions).toInt();
  return levenshtein;
}

/// [loc] is a location in text1, compute and return the equivalent location in
/// text2.
///
/// e.g. "The cat" vs "The big cat", 1->1, 5->8
///
/// * [diffs] is a List of Diff objects.
/// * [loc] is the location within text1.
///
/// Returns the location within text2.
int diffXIndex(List<Diff> diffs, int loc) {
  var chars1 = 0;
  var chars2 = 0;
  var last_chars1 = 0;
  var last_chars2 = 0;
  Diff lastDiff;
  for (var aDiff in diffs) {
    if (aDiff.operation != DIFF_INSERT) {
      // Equality or deletion.
      chars1 += aDiff.text.length;
    }
    if (aDiff.operation != DIFF_DELETE) {
      // Equality or insertion.
      chars2 += aDiff.text.length;
    }
    if (chars1 > loc) {
      // Overshot the location.
      lastDiff = aDiff;
      break;
    }
    last_chars1 = chars1;
    last_chars2 = chars2;
  }
  if (lastDiff != null && lastDiff.operation == DIFF_DELETE) {
    // The location was deleted.
    return last_chars2;
  }
  // Add the remaining character length.
  return last_chars2 + (loc - last_chars1);
}

/// Compute and return the source text (all equalities and deletions).
///
/// [diffs] is a List of Diff objects.
///
/// Returns the source text.
String diffText1(List<Diff> diffs) {
  final text = StringBuffer();
  for (var aDiff in diffs) {
    if (aDiff.operation != DIFF_INSERT) {
      text.write(aDiff.text);
    }
  }
  return text.toString();
}

/// Compute and return the destination text (all equalities and insertions).
///
/// [diffs] is a List of Diff objects.
///
/// Returns the destination text.
String diffText2(List<Diff> diffs) {
  final text = StringBuffer();
  for (var aDiff in diffs) {
    if (aDiff.operation != DIFF_DELETE) {
      text.write(aDiff.text);
    }
  }
  return text.toString();
}
