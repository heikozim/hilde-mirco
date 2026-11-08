#!/usr/bin/env python3
# Prints the frames of Zstandard the tests of Mirco.Zstd read, each written
# by the zstd tool on the path: its name, the length and the CRC32 of the
# bytes it holds, and the frame as hex.
#
#     python3 tools/make-zstd-vectors.py
import subprocess
import zlib


def text(n, seed=12345):
    # Words drawn by a congruential generator: repeats near and far.
    words = [b"alpha", b"beta", b"gamma", b"delta", b"mirco", b"hilde", b"root", b"tree", b"branch", b"leaf"]
    out, state = b"", seed
    while len(out) < n:
        state = (state * 1103515245 + 12345) % 2147483648
        out += words[state % len(words)] + (b" " if state % 7 else b"\n")
    return out[:n]


def zstd(data, *options):
    run = subprocess.run(["zstd", "-q", "-c", *options], input=data, stdout=subprocess.PIPE, check=True)
    return run.stdout


def main():
    cases = [
        ("short", b"hello, zstandard", ()),
        ("words", text(6000), ("-3",)),
        ("repeats", b"abc" * 2000, ("-3",)),
        ("strong", text(20000, 777), ("-19",)),
        ("blocks", text(140000, 4242), ("-1",)),
        ("unchecked", text(3000, 99), ("-3", "--no-check")),
        ("empty", b"", ()),
    ]
    for name, data, options in cases:
        packed = zstd(data, *options)
        print("%s %d %d %s" % (name, len(data), zlib.crc32(data), packed.hex()))
    return 0


if __name__ == "__main__":
    main()
