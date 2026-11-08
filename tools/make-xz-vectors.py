#!/usr/bin/env python3
# Prints the xz streams the tests of Mirco.Xz read, each written by
# liblzma through Python's lzma: its name, the length and the CRC32 of
# the bytes it holds, and the stream as hex.
#
#     python3 tools/make-xz-vectors.py
import lzma
import zlib


def text(n):
    # Words drawn by a congruential generator: repeats near and far.
    words = [b"alpha", b"beta", b"gamma", b"delta", b"mirco", b"hilde", b"root", b"tree", b"branch", b"leaf"]
    out, state = b"", 12345
    while len(out) < n:
        state = (state * 1103515245 + 12345) % 2147483648
        out += words[state % len(words)] + (b" " if state % 7 else b"\n")
    return out[:n]


def main():
    cases = [
        ("mixed", b"abc" * 200 + b"the quick brown fox " * 10, lzma.CHECK_CRC32),
        ("words", text(6000), lzma.CHECK_CRC32),
        ("unchecked", text(300), lzma.CHECK_NONE),
        ("crc64", text(500), lzma.CHECK_CRC64),
        ("empty", b"", lzma.CHECK_CRC32),
    ]
    for name, data, check in cases:
        packed = lzma.compress(data, format=lzma.FORMAT_XZ, check=check, preset=6)
        print("%s %d %d %s" % (name, len(data), zlib.crc32(data), packed.hex()))
    return 0


if __name__ == "__main__":
    main()
