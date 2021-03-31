/// Delta functions
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

/// Crush the diff into an encoded String which describes the operations
/// required to transform text1 into text2.
///
/// E.g. =3\t-2\t+ing  -> Keep 3 chars, delete 2 chars, insert 'ing'.
///
/// Operations are tab-separated.  Inserted text is escaped using %xx notation.
///
/// [diffs] is a List of Diff objects.
///
/// Returns the delta text.

String toDelta(List<Diff> diffs) {
  final text = StringBuffer();
  for (var aDiff in diffs) {
    switch (aDiff.operation) {
      case DIFF_INSERT:
        text..write('+')..write(Uri.encodeFull(aDiff.text))..write('\t');
        break;
      case DIFF_DELETE:
        text..write('-')..write(aDiff.text.length)..write('\t');
        break;
      case DIFF_EQUAL:
        text..write('=')..write(aDiff.text.length)..write('\t');
        break;
    }
  }
  var delta = text.toString();
  if (delta.isNotEmpty) {
    // Strip off trailing tab character.
    delta = delta.substring(0, delta.length - 1);
  }
  return delta.replaceAll('%20', ' ');
}

/// Given the original [text1], and an encoded String which describes the
/// operations required to transform [text1] into text2, compute the full diff.
///
/// * [text1] is the source string for the diff.
/// * [delta] is the delta text.
///
/// Returns a List of Diff objects or null if invalid.
///
/// Throws ArgumentError if invalid input.
List<Diff> fromDelta(String text1, String delta) {
  final diffs = <Diff>[];
  var pointer = 0; // Cursor in text1
  final tokens = delta.split('\t');
  for (var token in tokens) {
    if (token.isEmpty) {
      // Blank tokens are ok (from a trailing \t).
      continue;
    }
    // Each token begins with a one character parameter which specifies the
    // operation of this token (delete, insert, equality).
    var param = token.substring(1);
    switch (token[0]) {
      case '+':
        // decode would change all "+" to " "
        param = param.replaceAll('+', '%2B');
        try {
          param = Uri.decodeFull(param);
        } on ArgumentError {
          // Malformed URI sequence.
          throw ArgumentError('Illegal escape in diff_fromDelta: $param');
        }
        diffs.add(Diff(DIFF_INSERT, param));
        break;
      case '-':
      // Fall through.
      case '=':
        int n;
        try {
          n = int.parse(param);
        } on FormatException {
          throw ArgumentError('Invalid number in diff_fromDelta: $param');
        }
        if (n < 0) {
          throw ArgumentError('Negative number in diff_fromDelta: $param');
        }
        String text;
        try {
          text = text1.substring(pointer, pointer += n);
        } on RangeError {
          throw ArgumentError('Delta length ($pointer)'
              ' larger than source text length (${text1.length}).');
        }
        if (token[0] == '=') {
          diffs.add(Diff(DIFF_EQUAL, text));
        } else {
          diffs.add(Diff(DIFF_DELETE, text));
        }
        break;
      default:
        // Anything else is an error.
        throw ArgumentError(
            'Invalid diff operation in diff_fromDelta: ${token[0]}');
    }
  }
  if (pointer != text1.length) {
    throw ArgumentError('Delta length ($pointer)'
        ' smaller than source text length (${text1.length}).');
  }
  return diffs;
}
