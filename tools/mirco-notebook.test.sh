#!/bin/sh
# The checks of tools/mirco-notebook from the outside, each a notebook in a
# new directory of mktemp: the command lines it refuses, a notebook it
# refuses with its line, the state of one cell loaded by the next and the
# manifest of both, one cell run again, a message of the compiler with the
# line of the notebook, and a name of a state that would leave state/.
# HILDE and HILDE_COMPILER as for the tool.  POSIX sh; exit 0 when every
# check holds.
#
#     HILDE=/path/to/hilde sh tools/mirco-notebook.test.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 9
tool="$root/tools/mirco-notebook"
d=$(mktemp -d) || exit 9
trap 'rm -rf "$d"' EXIT
checks=0
failed=0
check() {
	checks=$((checks + 1))
	if [ "$1" = 0 ]; then
		echo "ok   $2"
	else
		echo "FAIL $2"
		failed=$((failed + 1))
	fi
}
holds() {
	if "$@" > /dev/null 2>&1; then echo 0; else echo 1; fi
}

sh "$tool" > /dev/null 2>&1
check "$([ $? = 9 ] && echo 0 || echo 1)" "no arguments: exit 9"
: > "$d/plain.txt"
sh "$tool" run "$d/plain.txt" > /dev/null 2> "$d/err"
check "$([ $? = 9 ] && grep -q 'ends with .hnb' "$d/err" && echo 0 || echo 1)" "a notebook ends with .hnb"
printf -- '--- cell a\nmodule body A is\nend module body.\n' > "$d/a.hnb"
sh "$tool" run "$d/a.hnb" ../x > /dev/null 2> "$d/err"
check "$([ $? = 9 ] && grep -q 'no cell can be named' "$d/err" && echo 0 || echo 1)" "a cell named by a path is refused"

printf 'About.\n\n--- cell Bad\nmodule body A is\nend module body.\n' > "$d/bad.hnb"
sh "$tool" run "$d/bad.hnb" > "$d/out" 2> "$d/err"
check "$([ $? = 2 ] && grep -q 'bad.hnb:3: a name of a cell' "$d/err" && echo 0 || echo 1)" "a refused notebook: exit 2 and its line"
check "$(holds test ! -e "$d/bad.run/cells/Bad.hiq")" "no source of a refused notebook"

cat > "$d/two.hnb" << 'EOF'
Two cells: one saves, the next loads.

--- cell one
import Standard.Buffer (Buffer, allocateEmpty, insertBack, destroyFree, wholeSpan);
import Mirco.Element (Element);
import Mirco.Array (NdArray, fromSpan, destroyNdArray);
import Mirco.Cell (saveArray, saveText);

module body Cell.One is
    function main(): ExitCode is
        var s: Buffer[Index] := allocateEmpty();
        insertBack(&!s, 3);
        var v: Buffer[Float64] := allocateEmpty();
        insertBack(&!v, 1.5);
        insertBack(&!v, 2.5);
        insertBack(&!v, 3.0);
        let a: NdArray[Float64] := fromSpan(wholeSpan(&s), wholeSpan(&v));
        let saved: Bool := saveArray("numbers", &a) and saveText("note", "three numbers\n");
        destroyNdArray(a);
        destroyFree(s);
        destroyFree(v);
        printLn("one saved");
        if saved then
            return ExitSuccess();
        end if;
        return ExitFailure();
    end;
end module body.

--- cell two
import Mirco.Element (Element);
import Mirco.Array (NdArray, destroyNdArray, flatGet, count);
import Mirco.Cell (CellError, loadArray);

module body Cell.Two is
    function main(): ExitCode is
        let read: Either[CellError, NdArray[Float64]] := loadArray("numbers");
        case read of
            when Right(right as a: NdArray[Float64]) do
                print("two loaded ");
                print(count(&a));
                print(" last ");
                printLn(flatGet(&a, 2));
                destroyNdArray(a);
                return ExitSuccess();
            when Left(left as e: CellError) do
                printLn("no state numbers");
                return ExitFailure();
        end case;
    end;
end module body.
EOF
sh "$tool" run "$d/two.hnb" > "$d/out" 2> "$d/err"
rc=$?
check "$([ $rc = 0 ] && echo 0 || echo 1)" "two cells run: exit 0 (was $rc)"
check "$(holds grep -q '^two loaded 3 last 3' "$d/out")" "the second cell loads the array of the first"
m="$d/two.run/manifest.csv"
check "$(holds grep -q '^one,state/numbers.mirc,array,40' "$m")" "the manifest names the array of one"
check "$(holds grep -q '^one,state/note.txt,text,14' "$m")" "the manifest names the text of one"
check "$(holds grep -q '^two,out/two.txt,text,' "$m")" "the manifest names the output of two"
check "$([ "$(grep -c '^two,state/' "$m")" = 0 ] && echo 0 || echo 1)" "two wrote no state"
check "$([ "$(stat -c %a "$d/two.run" 2> /dev/null || echo 700)" = 700 ] && echo 0 || echo 1)" "the directory of the run is 0700"

sh "$tool" run "$d/two.hnb" one > "$d/out" 2> "$d/err"
check "$([ $? = 0 ] && ! grep -q '^== cell two' "$d/out" && echo 0 || echo 1)" "only the cell named runs"
check "$([ "$(grep -c '^one,' "$m")" = 3 ] && [ "$(grep -c '^two,' "$m")" = 1 ] && echo 0 || echo 1)" "its rows replaced, those of two kept"
check "$([ "$(wc -l < "$d/two.run/runs.csv" | tr -d ' ')" = 4 ] && echo 0 || echo 1)" "runs.csv holds a row for each of three runs"

printf 'About.\n\n--- cell broken\nmodule body Cell.Broken is\n    function main(): ExitCode is\n        return nothing;\n    end;\nend module body.\n' > "$d/broken.hnb"
sh "$tool" run "$d/broken.hnb" > "$d/out" 2> "$d/err"
rc=$?
check "$([ $rc != 0 ] && grep -q 'line 6' "$d/err" && echo 0 || echo 1)" "a message of the compiler names line 6 of the notebook"

cat > "$d/escape.hnb" << 'EOF'
--- cell escape
import Mirco.Cell (saveText);

module body Cell.Escape is
    function main(): ExitCode is
        if saveText("../outside", "no") then
            return ExitSuccess();
        end if;
        return ExitFailure();
    end;
end module body.
EOF
sh "$tool" run "$d/escape.hnb" > "$d/out" 2> "$d/err"
rc=$?
check "$([ $rc != 0 ] && echo 0 || echo 1)" "a name of a state with a slash stops the cell (exit $rc)"
check "$(holds test ! -e "$d/escape.run/outside.txt")" "nothing written beside state/"
check "$([ "$(grep -c '^escape,state/' "$d/escape.run/manifest.csv")" = 0 ] && echo 0 || echo 1)" "and no state recorded"

echo "checks=$checks failed=$failed"
[ "$failed" = 0 ]
