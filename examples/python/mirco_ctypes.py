#!/usr/bin/env python3
# Calls the library of Mirco from Python through ctypes: the dot product,
# the mean, the standard deviation and a product of matrices.  A vector
# crosses as its bytes, each number eight bytes little endian, as
# struct.pack("<...d") or numpy.ndarray.tobytes() write them.  Exits with 0
# when every result is the one expected, with 1 otherwise.
#
#     python3 examples/python/mirco_ctypes.py path/to/libmirco.so
import ctypes
import math
import struct
import sys


def vector(values):
    data = struct.pack("<%dd" % len(values), *values)
    return ctypes.c_char_p(data), ctypes.c_size_t(len(data))


def main(path):
    lib = ctypes.CDLL(path)
    lib.hilde_start.restype = None
    lib.hilde_end.restype = None
    span = [ctypes.c_char_p, ctypes.c_size_t]
    lib.mirco_dot.argtypes = span + span
    lib.mirco_dot.restype = ctypes.c_double
    lib.mirco_mean.argtypes = span
    lib.mirco_mean.restype = ctypes.c_double
    lib.mirco_deviation.argtypes = span + [ctypes.c_size_t]
    lib.mirco_deviation.restype = ctypes.c_double
    lib.mirco_matmul.argtypes = span + span + [ctypes.c_size_t] * 3 + [ctypes.c_void_p, ctypes.c_size_t]
    lib.mirco_matmul.restype = ctypes.c_bool
    lib.hilde_start()
    good = 0
    want = 6
    if lib.mirco_dot(*vector([1.0, 2.0, 3.0]), *vector([4.0, 5.0, 6.0])) == 32.0:
        good += 1
    if lib.mirco_mean(*vector([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])) == 5.0:
        good += 1
    if lib.mirco_deviation(*vector([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]), 0) == 2.0:
        good += 1
    if math.isnan(lib.mirco_dot(*vector([1.0]), *vector([1.0, 2.0]))):
        good += 1
    out = ctypes.create_string_buffer(4 * 8)
    a = vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    b = vector([7.0, 8.0, 9.0, 10.0, 11.0, 12.0])
    if lib.mirco_matmul(*a, *b, 2, 3, 2, out, len(out)):
        if list(struct.unpack("<4d", out.raw)) == [58.0, 64.0, 139.0, 154.0]:
            good += 1
    if not lib.mirco_matmul(*a, *b, 2, 2, 2, out, len(out)):
        good += 1
    lib.hilde_end()
    print("mirco-ctypes good=%d want=%d" % (good, want))
    return 0 if good == want else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: mirco_ctypes.py path/to/libmirco.so", file=sys.stderr)
        sys.exit(9)
    sys.exit(main(sys.argv[1]))
