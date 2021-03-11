/**
 * Diff class
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
 * The data structure representing a diff is a List of Diff objects:
 *
 *     [Diff(DIFF_DELETE, 'Hello'),
 *      Diff(DIFF_INSERT, 'Goodbye'),
 *      Diff(DIFF_EQUAL, ' world.')]
 *
 * which means: delete 'Hello', add 'Goodbye' and keep ' world.'
 */

const DIFF_DELETE = -1;
const DIFF_INSERT = 1;
const DIFF_EQUAL = 0;

/**
 * Class representing one diff operation.
 */
class Diff {
  /**
   * One of: [DIFF_INSERT], [DIFF_DELETE] or [DIFF_EQUAL].
   */
  int operation;
  /**
   * The text associated with this diff operation.
   */
  String? text;

  /**
   * Constructor.  Initializes the diff with the provided values.
   *
   * * [operation] is one of [DIFF_INSERT], [DIFF_DELETE] or [DIFF_EQUAL].
   * * [text] is the text being applied.
   */
  Diff(this.operation, this.text);

  /**
   * Display a human-readable version of this Diff.
   *
   * Returns a text version.
   */
  String toString() {
    String prettyText = this.text!.replaceAll('\n', '\u00b6');
    return 'Diff(${this.operation},"$prettyText")';
  }

  /**
   * Is this Diff equivalent to another Diff?
   *
   * [other] is another Diff to compare against.
   *
   * Returns true or false.
   */
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Diff &&
              runtimeType == other.runtimeType &&
              operation == other.operation &&
              text == other.text;

  @override
  int get hashCode =>
      operation.hashCode ^
      text.hashCode;

}
