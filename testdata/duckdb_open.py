#!/usr/bin/env python3
# Part of Hilde, under the Apache License v2.0 with LLVM Exceptions.
# See LICENSE file for details.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""A second process that tries to open a database file of DuckDB, for the
test of concurrency in src/SchluckiStore.test.hiq.

    python3 -I testdata/duckdb_open.py <path> READ_WRITE|READ_ONLY

It opens the file through libduckdb by ctypes, in the mode named, and
closes it at once.  Exit 0 when DuckDB refused the open for the lock on
the file, 1 when it opened the file, 2 when the library or the arguments
are not there, 3 when DuckDB refused it for another reason; the test
reads only the code.
"""
import ctypes
import ctypes.util
import sys


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ("READ_WRITE", "READ_ONLY"):
        print("usage: duckdb_open.py <path> READ_WRITE|READ_ONLY", file=sys.stderr)
        return 2
    name = ctypes.util.find_library("duckdb") or "libduckdb.so"
    try:
        lib = ctypes.CDLL(name)
    except OSError as error:
        print("no libduckdb: %s" % error, file=sys.stderr)
        return 2
    handle = ctypes.c_void_p
    lib.duckdb_create_config.argtypes = [ctypes.POINTER(handle)]
    lib.duckdb_create_config.restype = ctypes.c_int
    lib.duckdb_set_config.argtypes = [handle, ctypes.c_char_p, ctypes.c_char_p]
    lib.duckdb_set_config.restype = ctypes.c_int
    lib.duckdb_destroy_config.argtypes = [ctypes.POINTER(handle)]
    lib.duckdb_destroy_config.restype = None
    lib.duckdb_open_ext.argtypes = [ctypes.c_char_p, ctypes.POINTER(handle), handle, ctypes.POINTER(ctypes.c_void_p)]
    lib.duckdb_open_ext.restype = ctypes.c_int
    lib.duckdb_close.argtypes = [ctypes.POINTER(handle)]
    lib.duckdb_close.restype = None
    lib.duckdb_free.argtypes = [ctypes.c_void_p]
    lib.duckdb_free.restype = None
    config = handle()
    if lib.duckdb_create_config(ctypes.byref(config)) != 0:
        return 2
    lib.duckdb_set_config(config, b"access_mode", sys.argv[2].encode())
    lib.duckdb_set_config(config, b"enable_external_access", b"false")
    database = handle()
    words = ctypes.c_void_p()
    state = lib.duckdb_open_ext(sys.argv[1].encode(), ctypes.byref(database), config, ctypes.byref(words))
    lib.duckdb_destroy_config(ctypes.byref(config))
    message = ""
    if words.value:
        message = ctypes.cast(words, ctypes.c_char_p).value.decode(errors="replace")
        print(message, file=sys.stderr)
        lib.duckdb_free(words)
    if state != 0:
        # "Could not set lock on file": the fcntl lock of another process.
        return 0 if "Could not set lock" in message else 3
    lib.duckdb_close(ctypes.byref(database))
    return 1


if __name__ == "__main__":
    sys.exit(main())
