#!/bin/sh
# Every interface below a source directory has its body beside it: a .hih
# without its .hiq stops hilde check and hilde test of the whole package
# with H1025 before a module is checked.  Names each lone interface and
# exits 1; 0 when every one has its body, 9 when the directory is missing.
# POSIX sh, the names taken from globs and never split.
#
#     sh scripts/check-pairs.sh [DIR]
set -u
dir=${1:-src}
[ -d "$dir" ] || { echo "ABORT: no directory $dir" >&2; exit 9; }
lone=0
for f in "$dir"/*.hih "$dir"/*/*.hih; do
	[ -e "$f" ] || continue
	if [ ! -f "${f%.hih}.hiq" ]; then
		echo "lone interface: $f has no body ${f%.hih}.hiq"
		lone=$((lone + 1))
	fi
done
echo "lone-interfaces=$lone"
[ "$lone" = 0 ]
