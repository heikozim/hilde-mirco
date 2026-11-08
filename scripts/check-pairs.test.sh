#!/bin/sh
# The checks of scripts/check-pairs.sh: the sources of the package have no
# lone interface, a directory with one (as src/Jupyter.hih was) is refused
# naming it, a body that is a directory is no body, and a missing
# directory aborts.  POSIX sh; exit 0 when every check holds.
#
#     sh scripts/check-pairs.test.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 9
check=$root/scripts/check-pairs.sh
tmp=$(mktemp -d) || exit 9
trap 'rm -rf "$tmp"' EXIT
failed=0
expect() {
	name=$1
	want=$2
	shift 2
	"$@" > "$tmp/out" 2>&1
	rc=$?
	if [ "$rc" = "$want" ]; then echo "ok $name"; else echo "FAIL $name: exit $rc, not $want"; cat "$tmp/out"; failed=$((failed + 1)); fi
}
expect package 0 sh "$check" "$root/src"
mkdir -p "$tmp/lone/Sub" || exit 9
: > "$tmp/lone/A.hih"
: > "$tmp/lone/A.hiq"
: > "$tmp/lone/Sub/B.hih"
expect lone 1 sh "$check" "$tmp/lone"
grep -q "lone interface: $tmp/lone/Sub/B.hih has no body" "$tmp/out" || { echo "FAIL lone: B.hih not named"; failed=$((failed + 1)); }
grep -q "A.hih" "$tmp/out" && { echo "FAIL lone: A.hih named though it has its body"; failed=$((failed + 1)); }
mkdir -p "$tmp/dir/C.hiq" || exit 9
: > "$tmp/dir/C.hih"
expect body-a-directory 1 sh "$check" "$tmp/dir"
expect missing 9 sh "$check" "$tmp/none"
echo "failed=$failed"
[ "$failed" = 0 ]
