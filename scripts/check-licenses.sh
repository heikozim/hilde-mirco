#!/bin/sh
# Whether the licences of the C backend below licenses/ are byte for byte
# the files of mirco-blis they were copied from, so that a new version of
# BLIS, of LAPACK or of pocketfft in mirco-blis cannot leave an old licence
# here unseen.  Run from the root of the package with MIRCO_BLIS naming
# mirco-blis.  POSIX sh.
#
#     MIRCO_BLIS=/path/to/mirco-blis sh scripts/check-licenses.sh
#
# Exit 0 all the same, 1 a file differs or is missing, 9 it did not run.
set -u
B=${MIRCO_BLIS:-}
[ -r "$B/NOTICE" ] || { echo "ABORT: MIRCO_BLIS does not name mirco-blis -- nothing checked" >&2; exit 9; }
[ -d licenses ] || { echo "ABORT: not the root of the package" >&2; exit 9; }
bad=0
n=0
for pair in blis-LICENSE:c/blis/LICENSE lapack-LICENSE:c/lapack/LICENSE openblas-LICENSE:c/lapack/LICENSE.OpenBLAS \
	pocketfft-numpy-LICENSE:c/pocketfft/LICENSE.numpy mirco-blis-NOTICE:NOTICE; do
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
