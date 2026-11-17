#!/bin/sh
# Whether the licences of the C backend below licenses/ are byte for byte
# the files beside the sources in c/, so that a new version of BLIS, of
# LAPACK or of pocketfft in c/ cannot leave an old licence here unseen.
# Run from the root of the package.  POSIX sh.
#
#     sh scripts/check-licenses.sh
#
# Exit 0 all the same, 1 a file differs or is missing, 9 it did not run.
set -u
B=c
[ -r "$B/NOTICE" ] || { echo "ABORT: c/NOTICE missing, not the root of the package -- nothing checked" >&2; exit 9; }
[ -d licenses ] || { echo "ABORT: not the root of the package" >&2; exit 9; }
bad=0
n=0
for pair in blis-LICENSE:blis/LICENSE lapack-LICENSE:lapack/LICENSE openblas-LICENSE:lapack/LICENSE.OpenBLAS \
	pocketfft-numpy-LICENSE:pocketfft/LICENSE.numpy mirco-blis-NOTICE:NOTICE; do
	here=licenses/${pair%%:*}
	there=$B/${pair#*:}
	n=$((n + 1))
	if [ ! -r "$here" ]; then
		echo "missing: $here"
		bad=$((bad + 1))
	elif ! cmp -s "$here" "$there"; then
		echo "differs: $here from $there"
		bad=$((bad + 1))
	fi
done
echo "licenses=$n differing=$bad"
[ "$bad" = 0 ]
