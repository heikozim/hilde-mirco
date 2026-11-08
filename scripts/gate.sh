#!/bin/sh
# The gate of Mirco, run from the root of the package with HILDE naming a
# Hilde tree whose compiler is built and MIRCO_BLIS naming the package
# mirco-blis, whose C it builds first: every interface with its body, the
# manifest and the capabilities, every module checked, the licences of the
# C backend against mirco-blis, the tests, the form of the sources, the
# contracts, the comments and the documentation, the library for C and
# Python, a script, and the units the compiler must refuse.  Each step
# writes its log below _gate/; the gate is green only when every step exits
# with 0.  POSIX sh, so that it runs alike on Linux, OpenBSD and FreeBSD.
#
# Every hilde that resolves modules gets --modules naming standard/src and
# bindings/generated of HILDE; hilde fmt takes none, hilde verify needs none.
#
#     HILDE=/path/to/hilde MIRCO_BLIS=/path/to/mirco-blis sh scripts/gate.sh
#
# With --quick only the touched modules and their direct dependents are
# built and tested; it writes nothing below _gate/ and never the
# line GATE-RESULT, the stamp of the full gate.
set -u
usage() {
	cat << 'EOF'
usage: HILDE=<hilde> MIRCO_BLIS=<mirco-blis> sh scripts/gate.sh [--quick | -q] [--help | -h]

Without an option the full gate runs: every module checked and tested, the
form, contracts, comments, Markdown, the library, a script and the units.
Its logs are written below _gate/ and it ends with GATE-RESULT=GREEN or RED.

--quick, -q  the quick gate: builds (hilde check) and tests only the modules
             touched since the merge base with main (committed, staged,
             unstaged and untracked) and the modules that import them
             directly.  No guard, form, contracts, comments, Markdown,
             library, script or units.  Its logs go to a directory under
             TMPDIR, never _gate/, and it never prints GATE-RESULT: it is no
             release stamp.  A change outside src/ and the documentation
             (scripts, tools, examples, testdata, hilde.toml, ...) or no
             merge base falls back to the full gate, which it says.
--help, -h   this text.

Exit: 0 green, 1 a step red, 9 the gate did not run.
EOF
}
quick=0
for a in "$@"; do
	case "$a" in
	--quick | -q) quick=1 ;;
	--help | -h) usage; exit 0 ;;
	*) usage >&2; echo "ABORT: unknown argument -- the gate did NOT run" >&2; exit 9 ;;
	esac
done
H=${HILDE:-}
[ -n "$H" ] || { echo "ABORT: HILDE is not set -- the gate did NOT run" >&2; exit 9; }
[ -x "$H/hilde" ] || { echo "ABORT: HILDE does not name a built Hilde -- the gate did NOT run" >&2; exit 9; }
# The modules of Hilde are named, not found beside whatever hilde the path
# holds: the standard library and the generated bindings of HILDE.  A colon
# would split the list, so the path is held to letters, digits and / . _ -.
case "$H" in *[!A-Za-z0-9/._-]*) echo "ABORT: HILDE holds a byte other than letters, digits and / . _ - -- the gate did NOT run" >&2; exit 9 ;; esac
for d in standard/src bindings/generated; do
	[ -d "$H/$d" ] || { echo "ABORT: HILDE has no $d -- the gate did NOT run" >&2; exit 9; }
done
M="--modules=$H/standard/src:$H/bindings/generated"
[ -r hilde.toml ] || { echo "ABORT: not the root of the package" >&2; exit 9; }
command -v python3 > /dev/null 2>&1 || { echo "ABORT: python3 missing -- the gate did NOT run" >&2; exit 9; }
B=${MIRCO_BLIS:-}
[ -r "$B/tools/build-c.sh" ] || { echo "ABORT: MIRCO_BLIS does not name the package mirco-blis -- the gate did NOT run" >&2; exit 9; }
PATH="$H:$PATH"
export PATH
# The quick gate: which files changed, which modules they are, which import
# them.  Whatever it cannot place on a module sends it to the full gate.
fallback=
if [ "$quick" = 1 ]; then
	Q=$(mktemp -d "${TMPDIR:-/tmp}/mirco-quick.XXXXXX") || exit 9
	base=
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
		for r in main origin/main; do
			base=$(git merge-base "$r" HEAD 2> /dev/null) && break
			base=
		done
		[ -n "$base" ] || fallback="no merge base with main or origin/main"
	else
		fallback="not a checkout of git"
	fi
	if [ -z "$fallback" ]; then
		{
			git diff --name-only "$base..HEAD" &&
				git diff --name-only --cached &&
				git diff --name-only &&
				git ls-files -o --exclude-standard
		} > "$Q/changed-all.txt" || fallback="git could not list the changes"
		sort -u "$Q/changed-all.txt" > "$Q/changed.txt"
	fi
	: > "$Q/touched.txt"
	if [ -z "$fallback" ]; then
		while IFS= read -r f; do
			# A name is held to letters, digits and / . _ -, as below.
			case "$f" in
			*[!A-Za-z0-9/._-]* | -*) fallback="a changed file with a name outside letters, digits and / . _ -"; break ;;
			src/*.test.hiq) m=${f#src/}; m=${m%.test.hiq} ;;
			src/*.hih) m=${f#src/}; m=${m%.hih} ;;
			src/*.hiq) m=${f#src/}; m=${m%.hiq} ;;
			src/*) fallback="$f is not a module of src/"; break ;;
			docs/*.md | README.md | CHANGELOG | LICENSE) continue ;;
			*) fallback="$f is the gate, the build or shared configuration"; break ;;
			esac
			echo "$m" | tr / . >> "$Q/touched.txt"
		done < "$Q/changed.txt"
	fi
	if [ -n "$fallback" ]; then
		echo "QUICK GATE NOT POSSIBLE: $fallback -- falling back to the FULL gate"
		rm -rf "$Q"
		quick=0
	fi
fi
if [ "$quick" = 1 ]; then
	sort -u "$Q/touched.txt" > "$Q/direct.txt"
	cp "$Q/direct.txt" "$Q/modules-all.txt"
	# The direct dependents, one level: every module one of whose files
	# imports a touched module.
	for f in src/*.hih src/*.hiq src/*/*.hih src/*/*.hiq; do
		[ -e "$f" ] || continue
		m=${f#src/}
		m=${m%.hih}
		m=${m%.hiq}
		m=${m%.test}
		sed -n 's/^import Mirco\.\([A-Za-z0-9.]*\)[ (;].*/\1/p' "$f" > "$Q/imports.txt"
		if grep -qxF -f "$Q/direct.txt" "$Q/imports.txt"; then
			echo "$m" | tr / . >> "$Q/modules-all.txt"
		fi
	done
	sort -u "$Q/modules-all.txt" > "$Q/modules.txt"
	: > "$Q/pairs.txt"
	: > "$Q/tests.txt"
	while IFS= read -r m; do
		p=src/$(echo "$m" | tr . /)
		[ -e "$p.hih" ] && [ -e "$p.hiq" ] && echo "$p.hih,$p.hiq" >> "$Q/pairs.txt"
		[ -e "$p.test.hiq" ] && echo "$p.test.hiq" >> "$Q/tests.txt"
	done < "$Q/modules.txt"
	L=$Q
	steps=0
	failed=0
	step() {
		name=$1
		shift
		"$@" > "$L/$name.log" 2>&1
		rc=$?
		echo "$name-exit=$rc | $(tail -1 "$L/$name.log" | cut -c1-120)"
		steps=$((steps + 1))
		[ "$rc" = 0 ] || failed=$((failed + 1))
	}
	echo "quick gate: base=$base logs=$Q"
	echo "touched: $(tr '\n' ' ' < "$Q/direct.txt")"
	if [ -s "$Q/pairs.txt" ]; then
		step native sh "$B/tools/build-c.sh"
		PKG_CONFIG_PATH=$B/_c/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
		export PKG_CONFIG_PATH
		# shellcheck disable=SC2046 # one word a pair, the names held above
		step build hilde check "$M" $(cat "$Q/pairs.txt")
	fi
	if [ -s "$Q/tests.txt" ]; then
		tests=$(wc -l < "$Q/tests.txt" | tr -d ' ')
		# shellcheck disable=SC2046 # one word a file, the names held above
		step test hilde test "$M" $(cat "$Q/tests.txt")
		grep -q "^hilde test: $tests test files\{0,1\}, .* 0 failed, 0 not built$" "$L/test.log" || { echo "test-files-run: not $tests or not all green"; failed=$((failed + 1)); }
	fi
	echo "steps=$steps failed-steps=$failed"
	echo "SCHNELLES GATE – kein Release-Stempel"
	if [ -s "$Q/modules.txt" ]; then sed 's/^/Mirco./' "$Q/modules.txt"; else echo "(no module touched)"; fi
	[ "$failed" = 0 ]
	exit
fi
L=_gate
rm -rf "$L" && mkdir "$L" || exit 9
steps=0
failed=0
step() {
	name=$1
	shift
	"$@" > "$L/$name.log" 2>&1
	rc=$?
	echo "$name-exit=$rc | $(tail -1 "$L/$name.log" | cut -c1-120)"
	steps=$((steps + 1))
	[ "$rc" = 0 ] || failed=$((failed + 1))
}
: > "$L/sources.txt"
: > "$L/pairs.txt"
: > "$L/tests.txt"
for f in src/*.hih src/*.hiq src/*/*.hih src/*/*.hiq; do
	[ -e "$f" ] || continue
	echo "$f" >> "$L/sources.txt"
	case "$f" in
	*.test.hiq) echo "$f" >> "$L/tests.txt" ;;
	*.hih) [ -e "${f%.hih}.hiq" ] && echo "$f,${f%.hih}.hiq" >> "$L/pairs.txt" ;;
	esac
done
sources=$(wc -l < "$L/sources.txt" | tr -d ' ')
pairs=$(wc -l < "$L/pairs.txt" | tr -d ' ')
# The backend DuckDB of Mirco.SchluckiStore needs libduckdb and duckdb.h of
# the system, at least 1.5.6.  A small C programme built and run against
# them says whether they are there; where they are not, as on OpenBSD 8.0,
# the tests that reach libduckdb are left out, and the gate says so.
printf '#include <duckdb.h>\n#include <stdio.h>\nint main(void) { duckdb_instance_cache c = duckdb_create_instance_cache(); duckdb_destroy_instance_cache(&c); puts(duckdb_library_version()); return 0; }\n' > "$L/duckdb-probe.c"
duckdb_flags=$(pkg-config --cflags --libs duckdb 2> /dev/null) || duckdb_flags="-I/usr/local/include -L/usr/local/lib -lduckdb"
duckdb=skipped
duckdb_version=none
if cc -o "$L/duckdb-probe" "$L/duckdb-probe.c" $duckdb_flags > "$L/duckdb-probe.log" 2>&1; then
	duckdb_version=$("$L/duckdb-probe" 2>> "$L/duckdb-probe.log")
	# "v1.5.6" or "1.5.6-dev": the v taken off, then major, minor, patch.
	if echo "$duckdb_version" | sed 's/^v//' | awk -F'[.-]' '{ v = $1 * 1000000 + $2 * 1000 + $3; exit !(v >= 1005006) }'; then
		duckdb=run
	fi
fi
echo "duckdb=$duckdb version=$duckdb_version"
if [ "$duckdb" = run ]; then
	tested=src
else
	grep -v -e '^src/Bindings/DuckDB\.test\.hiq$' -e '^src/SchluckiStore\.test\.hiq$' "$L/tests.txt" > "$L/tests-run.txt"
	mv "$L/tests-run.txt" "$L/tests.txt"
	tested=$(cat "$L/tests.txt")
fi
tests=$(wc -l < "$L/tests.txt" | tr -d ' ')
echo "sources=$sources modules=$pairs test-files=$tests"
[ "$pairs" -gt 0 ] || { echo "ABORT: no modules below src" >&2; exit 9; }
step pairs sh scripts/check-pairs.sh src
step verify hilde verify
step native sh "$B/tools/build-c.sh"
step licenses sh scripts/check-licenses.sh
PKG_CONFIG_PATH=$B/_c/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
export PKG_CONFIG_PATH
step guard hilde guard "$M" $(cat "$L/pairs.txt")
step test hilde test "$M" $tested
grep -q "^hilde test: $tests test files, .* 0 failed, 0 not built$" "$L/test.log" || { echo "test-files-run: not $tests or not all green"; failed=$((failed + 1)); }
step fmt hilde fmt --check $(cat "$L/sources.txt")
step contracts python3 "$H/scripts/check-contracts.py" src
step comments python3 "$H/scripts/check-comments.py" $(cat "$L/sources.txt")
# In a checkout of git the Markdown files are those git counts as the
# package's, tracked or not ignored, so that a file git excludes (such as
# one a tool wrote for its own run) is not judged; elsewhere every one.
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	git ls-files -co --exclude-standard '*.md' > "$L/markdown.txt" || exit 9
	# The names are split by the shell: a blank, a glob or a leading - would
	# change what is checked, so a name is held to letters, digits and / . _ -.
	if grep -q -e '[^A-Za-z0-9/._-]' -e '^-' "$L/markdown.txt"; then
		echo "ABORT: a Markdown file whose name holds a byte other than letters, digits and / . _ - -- the gate did NOT run" >&2
		exit 9
	fi
	# shellcheck disable=SC2046 # one word a name, the names held above
	step markdown python3 "$H/scripts/check-markdown-ascii.py" --files $(cat "$L/markdown.txt")
else
	step markdown python3 "$H/scripts/check-markdown-ascii.py" .
fi
mkdir -p "$L/lib" || exit 9
step library hilde compile "$M" src/Export.hih,src/Export.hiq --target-type=shared "--output=$L/lib/libmirco.so"
step ctypes python3 examples/python/mirco_ctypes.py "$L/lib/libmirco.so"
step script env "HILDE=$H" sh tools/mirco-run examples/scripts/Summary.hiq
grep -q '^deviation 2.23606797749979$' "$L/script.log" || { echo "script-output: not the deviation of 1, 3, 5, 7"; failed=$((failed + 1)); }
# Units: two files the compiler must refuse, each with its code, and the
# control with the same calls in order, which it must take.
units=0
hilde check "$M" examples/units/WrongAdd.hiq > "$L/units-add.log" 2>&1 && units=1
grep -q 'Error code: H3003' "$L/units-add.log" || units=1
hilde check "$M" examples/units/WrongVelocity.hiq > "$L/units-velocity.log" 2>&1 && units=1
grep -q 'Error code: H3060' "$L/units-velocity.log" || units=1
hilde check "$M" examples/units/RightVelocity.hiq > "$L/units-right.log" 2>&1 || units=1
echo "units-exit=$units | a length plus a time and a time over a length refused, the control taken"
steps=$((steps + 1))
[ "$units" = 0 ] || failed=$((failed + 1))
echo "steps=$steps failed-steps=$failed"
if [ "$failed" = 0 ]; then echo "GATE-RESULT=GREEN"; else echo "GATE-RESULT=RED"; fi
echo "SECTIONS-RUN=1"
[ "$failed" = 0 ]
