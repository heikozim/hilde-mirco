#!/bin/sh
# Builds the C backend in c/ below _c/ of the repository: BLIS with its
# BLAS interface as a static library, the routines of LAPACK in c/lapack as
# libmircolapack.a, pocketfft as libmircopocketfft.a, and the file
# _c/lib/pkgconfig/mircoblis.pc that names all three, so that a module of
# Hilde that names the library mircoblis links them when PKG_CONFIG_PATH
# holds _c/lib/pkgconfig.  BLIS is configured for the family of the
# processor (arm64 or x86_64), single threaded.  POSIX sh; it needs a C
# compiler, GNU make (make or gmake), python3 and perl.
#
#     sh tools/build-c.sh
#
# Exit 0 built, 1 a step failed, 9 it did not run.
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 9
CC=${CC:-}
if [ -z "$CC" ]; then
	for c in clang gcc cc; do command -v "$c" > /dev/null 2>&1 && { CC=$c; break; }; done
fi
command -v "$CC" > /dev/null 2>&1 || { echo "ABORT: $CC missing -- nothing ran" >&2; exit 9; }
command -v python3 > /dev/null 2>&1 || { echo "ABORT: python3 missing -- nothing ran" >&2; exit 9; }
MAKE=
for m in gmake make; do
	if command -v "$m" > /dev/null 2>&1 && "$m" --version 2> /dev/null | grep -q 'GNU Make'; then MAKE=$m; break; fi
done
[ -n "$MAKE" ] || { echo "ABORT: no GNU make -- nothing ran" >&2; exit 9; }
case "$(uname -m)" in
aarch64 | arm64) family=cortexa57 ;;
x86_64 | amd64) family=x86_64 ;;
*) family=generic ;;
esac
jobs=${JOBS:-4}
out=$root/_c
rm -rf "$out" && mkdir -p "$out/lib/pkgconfig" "$out/include" "$out/obj" || exit 9
work=$out/blis-build
cp -R "$root/c/blis" "$work" || exit 1
(
	cd "$work" || exit 1
	CC=$CC ./configure --prefix="$out" --disable-shared --enable-static --enable-blas --disable-cblas \
		--enable-threading=no "$family" > "$out/blis-configure.log" 2>&1 || { echo "blis-configure failed"; tail -20 "$out/blis-configure.log"; exit 1; }
	"$MAKE" -j"$jobs" > "$out/blis-make.log" 2>&1 || { echo "blis-make failed"; tail -20 "$out/blis-make.log"; exit 1; }
	"$MAKE" install > "$out/blis-install.log" 2>&1 || { echo "blis-install failed"; tail -20 "$out/blis-install.log"; exit 1; }
) || exit 1
rm -rf "$work"
echo "blis=$family lib=$(ls "$out/lib/libblis.a")"
n=0
for f in "$root"/c/lapack/*.c; do
	o=$out/obj/lapack-$(basename "$f" .c).o
	$CC -O2 -fPIC -w -c "$f" -o "$o" || { echo "lapack: $f failed"; exit 1; }
	n=$((n + 1))
done
ar rcs "$out/lib/libmircolapack.a" "$out"/obj/lapack-*.o || exit 1
echo "lapack-files=$n"
$CC -O2 -fPIC -std=c99 -Wall -Wextra -c "$root/c/pocketfft/pocketfft.c" -I"$root/c/pocketfft" -o "$out/obj/pocketfft.o" 2> "$out/pocketfft-warnings.log" || { cat "$out/pocketfft-warnings.log"; exit 1; }
ar rcs "$out/lib/libmircopocketfft.a" "$out/obj/pocketfft.o" || exit 1
cp "$root/c/pocketfft/mirco_pocketfft.h" "$root/c/include/mirco_lapack.h" "$out/include/" || exit 1
echo "pocketfft-warnings=$(wc -l < "$out/pocketfft-warnings.log" | tr -d ' ')"
rm -rf "$out/obj"
{
	printf 'prefix=%s\n' "$out"
	printf 'libdir=${prefix}/lib\n'
	printf 'includedir=${prefix}/include\n\n'
	printf 'Name: mircoblis\n'
	printf 'Description: BLIS, the routines of LAPACK Mirco binds and pocketfft\n'
	printf 'Version: 0.1.0\n'
	printf 'Cflags: -I${includedir} -I${includedir}/blis\n'
	printf 'Libs: -L${libdir} -lmircolapack -lblis -lmircopocketfft -lm -lpthread\n'
} > "$out/lib/pkgconfig/mircoblis.pc" || exit 1
echo "pc=$out/lib/pkgconfig/mircoblis.pc"
echo BUILD-C-DONE
