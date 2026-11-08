#!/bin/sh
# The checks of tools/mirco-run: without HILDE, with a HILDE that is no
# built Hilde, lacks standard/src or bindings/generated, or holds a colon,
# it aborts with 9 before it compiles; with a Hilde tree it compiles with
# the compiler of HILDE and --modules naming its standard/src and
# bindings/generated, and runs the script with its arguments.  A stand-in
# compiler under a temporary tree records its arguments; with HILDE set,
# examples/scripts/Summary.hiq is also run by the real one.  POSIX sh;
# exit 0 when every check holds.
#
#     [HILDE=/path/to/hilde] sh tools/mirco-run.test.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 9
run=$root/tools/mirco-run
real=${HILDE:-}
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
said() {
	grep -q "$2" "$tmp/out" || { echo "FAIL $1: not said: $2"; cat "$tmp/out"; failed=$((failed + 1)); }
}
# The stand-in compiler: its arguments one per line into args.txt, and as
# the programme of --output a script that prints its own arguments.
fake=$tmp/fake
mkdir -p "$fake/standard/src" "$fake/bindings/generated" || exit 9
cat > "$fake/hilde" << 'EOF'
#!/bin/sh
: > "$(dirname "$0")/args.txt"
for a in "$@"; do
	printf '%s\n' "$a" >> "$(dirname "$0")/args.txt"
	case "$a" in --output=*) printf '#!/bin/sh\necho "ran $*"\n' > "${a#--output=}" && chmod +x "${a#--output=}" ;; esac
done
EOF
chmod +x "$fake/hilde" || exit 9
script=$tmp/Probe.hiq
printf 'module body Probe is\nend;\n' > "$script"

# shellcheck disable=SC2016 # expanded by the inner sh
expect unset 9 sh -c 'unset HILDE; exec sh "$0" "$1"' "$run" "$script"
said unset 'HILDE is not set'
expect empty 9 env HILDE= sh "$run" "$script"
said empty 'HILDE is not set'
expect no-compiler 9 env "HILDE=$tmp/none" sh "$run" "$script"
said no-compiler 'does not name a built Hilde'
mkdir -p "$tmp/half/standard/src" || exit 9
cp "$fake/hilde" "$tmp/half/hilde" || exit 9
expect no-bindings 9 env "HILDE=$tmp/half" sh "$run" "$script"
said no-bindings 'HILDE has no bindings/generated'
mkdir -p "$tmp/a:b" || exit 9
cp -R "$fake/." "$tmp/a:b/" || exit 9
expect colon 9 env "HILDE=$tmp/a:b" sh "$run" "$script"
said colon 'HILDE holds a byte other than'
[ -e "$tmp/a:b/args.txt" ] && { echo "FAIL colon: the compiler was called"; failed=$((failed + 1)); }

expect fake 0 env "HILDE=$fake" sh "$run" "$script" one two
said fake '^ran one two$'
grep -qx -e "--modules=$fake/standard/src:$fake/bindings/generated" "$fake/args.txt" || { echo "FAIL fake: no --modules of HILDE"; cat "$fake/args.txt"; failed=$((failed + 1)); }
grep -qx compile "$fake/args.txt" || { echo "FAIL fake: not hilde compile"; failed=$((failed + 1)); }
grep -qx -e "--entrypoint=Probe:main" "$fake/args.txt" || { echo "FAIL fake: no entrypoint Probe:main"; failed=$((failed + 1)); }

if [ -n "$real" ]; then
	expect summary 0 env "HILDE=$real" sh "$run" "$root/examples/scripts/Summary.hiq"
	said summary '^deviation 2.23606797749979$'
else
	echo "skipped summary: HILDE not set"
fi
echo "failed=$failed"
[ "$failed" = 0 ]
