# Diff Match Patch

This is a port of [google-diff-match-patch](https://code.google.com/p/google-diff-match-patch/)
library to Dart.

## Algorithms

This library implements Myer's diff algorithm which is generally considered to
be the best general-purpose diff. A layer of pre-diff speedups and post-diff
cleanups surround the diff algorithm, improving both performance and output
quality.

This library also implements a Bitap matching algorithm at the heart of a
flexible matching and patching strategy.