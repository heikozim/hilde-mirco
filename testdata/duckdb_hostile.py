#!/usr/bin/env python3
# Part of Hilde, under the Apache License v2.0 with LLVM Exceptions.
# See LICENSE file for details.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""Makes a database file of DuckDB as a programme of a third party might,
for the tests of the definitions a file holds in src/Bindings/DuckDB.test.hiq
and src/SchluckiStore.test.hiq.

    python3 -I testdata/duckdb_hostile.py <path> plain|view|macro|shadow

It opens the file through libduckdb by ctypes without the safe layer of
Mirco.Bindings.DuckDB and writes a table facts of one row, then by the kind
named: plain a view and two macros that call no function the layer refuses;
view a view that calls enable_logging; macro a table macro that calls it;
shadow the view of view beside macros named duckdb_views, duckdb_functions
and current_setting, which a query of the catalog that does not name the
catalog would read in its place.  Exit 0 when the file was written, 2 when
the library or the arguments are not there, 3 when DuckDB refused a
statement.
"""
import ctypes
import ctypes.util
import sys

LOGGING_VIEW = "CREATE VIEW facts_logged AS SELECT * FROM enable_logging(storage = 'stdout')"

KINDS = {
    "plain": [
        "CREATE VIEW v AS SELECT a FROM facts",
        "CREATE MACRO plus1(x) AS x + 1",
        "CREATE MACRO facts_of() AS TABLE SELECT a FROM facts",
    ],
    "view": [LOGGING_VIEW],
    "macro": ["CREATE MACRO logged() AS TABLE SELECT * FROM enable_logging(storage = 'stdout')"],
    "shadow": [
        LOGGING_VIEW,
        "CREATE MACRO duckdb_views() AS TABLE SELECT NULL::VARCHAR AS sql, false AS internal WHERE false",
        "CREATE MACRO duckdb_functions() AS TABLE SELECT NULL::VARCHAR AS macro_definition, false AS internal WHERE false",
        "CREATE MACRO current_setting(x) AS CASE WHEN x = 'lock_configuration' THEN 'true' ELSE 'false' END",
    ],
}


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in KINDS:
        print("usage: duckdb_hostile.py <path> plain|view|macro|shadow", file=sys.stderr)
        return 2
    name = ctypes.util.find_library("duckdb") or "libduckdb.so"
    try:
        lib = ctypes.CDLL(name)
    except OSError as error:
        print("no libduckdb: %s" % error, file=sys.stderr)
        return 2
    handle = ctypes.c_void_p
    lib.duckdb_open.argtypes = [ctypes.c_char_p, ctypes.POINTER(handle)]
    lib.duckdb_open.restype = ctypes.c_int
    lib.duckdb_connect.argtypes = [handle, ctypes.POINTER(handle)]
    lib.duckdb_connect.restype = ctypes.c_int
    lib.duckdb_query.argtypes = [handle, ctypes.c_char_p, ctypes.c_void_p]
    lib.duckdb_query.restype = ctypes.c_int
    lib.duckdb_result_error.argtypes = [ctypes.c_void_p]
    lib.duckdb_result_error.restype = ctypes.c_char_p
    lib.duckdb_destroy_result.argtypes = [ctypes.c_void_p]
    lib.duckdb_destroy_result.restype = None
    lib.duckdb_disconnect.argtypes = [ctypes.POINTER(handle)]
    lib.duckdb_disconnect.restype = None
    lib.duckdb_close.argtypes = [ctypes.POINTER(handle)]
    lib.duckdb_close.restype = None
    database = handle()
    if lib.duckdb_open(sys.argv[1].encode(), ctypes.byref(database)) != 0:
        print("the file could not be opened", file=sys.stderr)
        return 3
    connection = handle()
    if lib.duckdb_connect(database, ctypes.byref(connection)) != 0:
        lib.duckdb_close(ctypes.byref(database))
        return 3
    failed = 0
    for sql in ["CREATE TABLE facts AS SELECT 1 AS a"] + KINDS[sys.argv[2]] + ["CHECKPOINT"]:
        # Room for a duckdb_result, six fields of eight bytes, and to spare.
        result = ctypes.create_string_buffer(128)
        lib.duckdb_query(connection, sql.encode(), result)
        error = lib.duckdb_result_error(result)
        if error is not None:
            print("%s: %s" % (sql, error.decode(errors="replace")), file=sys.stderr)
            failed = 1
        lib.duckdb_destroy_result(result)
        if failed:
            break
    lib.duckdb_disconnect(ctypes.byref(connection))
    lib.duckdb_close(ctypes.byref(database))
    return 3 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
