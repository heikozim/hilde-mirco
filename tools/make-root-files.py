#!/usr/bin/env python3
# Writes the small .root files the tests of Mirco.Root read, after the
# description of the format of ROOT (TFile, TKey, TDirectory, compressed
# blocks), into testdata/, and prints each as one line of hex for the test.
# Written because uproot and ROOT are not at hand; files written by ROOT
# itself are to be checked in beside them once they are.
#
#     python3 tools/make-root-files.py
import lzma
import os
import struct
import subprocess
import sys
import zlib

DATIME = 0x7A9C2B40  # a fixed date, so that the files do not change


def tstring(s):
    b = s.encode("ascii")
    if len(b) < 255:
        return bytes([len(b)]) + b
    return b"\xff" + struct.pack(">i", len(b)) + b


def key_header(nbytes, objlen, keylen, cycle, seek_key, seek_pdir, cls, name, title):
    return (struct.pack(">ihiIhhii", nbytes, 4, objlen, DATIME, keylen, cycle, seek_key, seek_pdir)
            + tstring(cls) + tstring(name) + tstring(title))


def key_length(cls, name, title):
    return 4 + 2 + 4 + 4 + 2 + 2 + 4 + 4 + len(tstring(cls)) + len(tstring(name)) + len(tstring(title))


def objstring(text):
    # TObjString: byte count and version, TObject (version, unique id, bits), TString.
    tobject = struct.pack(">hII", 1, 0, 0x03000000)
    body = struct.pack(">h", 1) + tobject + tstring(text)
    return struct.pack(">I", 0x40000000 | len(body)) + body


M64 = (1 << 64) - 1
P1, P2, P3, P4, P5 = (11400714785074694791, 14029467366897019727, 1609587929392839161,
                      9650029242287828579, 2870177450012600261)


def rotl(x, r):
    return ((x << r) | (x >> (64 - r))) & M64


def xx_round(acc, lane):
    return (rotl((acc + lane * P2) & M64, 31) * P1) & M64


def xxh64(data):
    # XXH64 with the seed 0; gives ef46db3751d8e999 for b"" and
    # 44bc2cf5ad770999 for b"abc", the values of its reference.
    n, i = len(data), 0
    word = lambda k, w: int.from_bytes(data[k:k + w], "little")
    if n >= 32:
        v = [(P1 + P2) & M64, P2, 0, (-P1) & M64]
        while i + 32 <= n:
            v = [xx_round(v[j], word(i + 8 * j, 8)) for j in range(4)]
            i += 32
        h = (rotl(v[0], 1) + rotl(v[1], 7) + rotl(v[2], 12) + rotl(v[3], 18)) & M64
        for x in v:
            h = ((h ^ xx_round(0, x)) * P1 + P4) & M64
    else:
        h = P5
    h = (h + n) & M64
    while i + 8 <= n:
        h = (rotl(h ^ xx_round(0, word(i, 8)), 27) * P1 + P4) & M64
        i += 8
    if i + 4 <= n:
        h = (rotl(h ^ ((word(i, 4) * P1) & M64), 23) * P2 + P3) & M64
        i += 4
    while i < n:
        h = (rotl(h ^ ((data[i] * P5) & M64), 11) * P1) & M64
        i += 1
    h = ((h ^ (h >> 33)) * P2) & M64
    h = ((h ^ (h >> 29)) * P3) & M64
    return h ^ (h >> 32)


def lz4_length(n):
    out = b""
    while n >= 255:
        out += b"\xff"
        n -= 255
    return out + bytes([n])


def lz4_block(data):
    # A greedy compressor: a match of 4 bytes or more found through the last
    # position of each 4 bytes, the last 5 bytes always literals.
    out, last, i, seen = b"", 0, 0, {}
    while i + 4 <= len(data) - 5:
        key = data[i:i + 4]
        j = seen.get(key)
        seen[key] = i
        if j is not None and i - j <= 65535:
            size = 4
            while i + size < len(data) - 5 and data[j + size] == data[i + size]:
                size += 1
            lit = data[last:i]
            token = (min(len(lit), 15) << 4) | min(size - 4, 15)
            out += bytes([token])
            if len(lit) >= 15:
                out += lz4_length(len(lit) - 15)
            out += lit + struct.pack("<H", i - j)
            if size - 4 >= 15:
                out += lz4_length(size - 4 - 15)
            i += size
            last = i
        else:
            i += 1
    lit = data[last:]
    out += bytes([min(len(lit), 15) << 4])
    if len(lit) >= 15:
        out += lz4_length(len(lit) - 15)
    return out + lit


def block_header(method, packed, unpacked):
    c, u = len(packed), unpacked
    return method + bytes([8 if method == b"ZL" else 1]) + bytes([c & 255, (c >> 8) & 255, (c >> 16) & 255]) + bytes([u & 255, (u >> 8) & 255, (u >> 16) & 255])


def compress(payload, method="ZL"):
    if method == "ZS":
        packed = subprocess.run(["zstd", "-q", "-c", "-3"], input=payload, stdout=subprocess.PIPE, check=True).stdout
        return block_header(b"ZS", packed, len(payload)) + packed
    if method == "XZ":
        packed = lzma.compress(payload, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC32)
        return block_header(b"XZ", packed, len(payload)) + packed
    if method == "L4":
        block = lz4_block(payload)
        packed = struct.pack(">Q", xxh64(block)) + block
        return block_header(b"L4", packed, len(payload)) + packed
    packed = zlib.compress(payload, 6)
    return block_header(b"ZL", packed, len(payload)) + packed


def build(objects, file_name):
    begin = 100
    title = "a file for the tests of Mirco"
    file_key_len = key_length("TFile", file_name, title)
    named = tstring(file_name) + tstring(title)
    nbytes_name = file_key_len + len(named)
    dir_len = 2 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + 18 + 12
    at = begin + nbytes_name + dir_len
    records = []
    keys = []
    for cls, name, otitle, payload, packed in objects:
        data = compress(payload, packed) if packed else payload
        klen = key_length(cls, name, otitle)
        nbytes = klen + len(data)
        keys.append((nbytes, len(payload), klen, 1, at, begin, cls, name, otitle))
        records.append(key_header(nbytes, len(payload), klen, 1, at, begin, cls, name, otitle) + data)
        at += nbytes
    seek_keys = at
    list_klen = key_length("TFile", file_name, title)
    listing = struct.pack(">i", len(keys)) + b"".join(key_header(*k) for k in keys)
    nbytes_keys = list_klen + len(listing)
    keys_record = key_header(nbytes_keys, len(listing), list_klen, 1, seek_keys, begin, "TFile", file_name, title) + listing
    end = seek_keys + nbytes_keys
    uuid = struct.pack(">h", 1) + bytes(range(16))
    directory = struct.pack(">hIIiiiii", 5, DATIME, DATIME, nbytes_keys, nbytes_name, begin, 0, seek_keys) + uuid + bytes(12)
    file_key = key_header(nbytes_name + dir_len, nbytes_name + dir_len - file_key_len, file_key_len, 1, begin, 0, "TFile", file_name, title)
    header = (b"root" + struct.pack(">iiiiiiiBiii", 62206, begin, end, 0, 0, 0, nbytes_name, 4, 101, 0, 0) + uuid)
    header = header + bytes(begin - len(header))
    out = header + file_key + named + directory + b"".join(records) + keys_record
    assert len(out) == end, (len(out), end)
    return out


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "testdata")
    os.makedirs(root, exist_ok=True)
    files = {
        "two-strings.root": build([
            ("TObjString", "greeting", "collectable string", objstring("hello from a key"), False),
            ("TObjString", "packed", "collectable string", objstring("abc" * 200), True),
        ], "two-strings.root"),
        "three-strings.root": build([
            ("TObjString", "greeting", "collectable string", objstring("hello from a key"), False),
            ("TObjString", "packed", "collectable string", objstring("abc" * 200), "ZL"),
            ("TObjString", "fast", "collectable string", objstring("abc" * 200), "L4"),
        ], "three-strings.root"),
        "xz-string.root": build([
            ("TObjString", "slow", "collectable string", objstring("abc" * 200), "XZ"),
        ], "xz-string.root"),
        "zstd-string.root": build([
            ("TObjString", "zipped", "collectable string", objstring("abc" * 200), "ZS"),
        ], "zstd-string.root"),
    }
    for name, data in files.items():
        with open(os.path.join(root, name), "wb") as f:
            f.write(data)
        print("%s %d %s" % (name, len(data), data.hex()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
