#!/usr/bin/env python3
# Part of Hilde, under the Apache License v2.0 with LLVM Exceptions.
# See LICENSE file for details.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""A second process that holds the write lock of a database file of SQLite,
for the test of concurrency in src/SchluckiStore.test.hiq.

    python3 -I testdata/sqlite_hold.py <path> <seconds> <key>

It opens the file, which must hold the table places, begins an immediate
transaction, so that it holds the write lock, inserts the place hold with
the key given, writes "locked\\n" to its standard output, sleeps for the
seconds given and commits.  Exit 0 when it committed, 2 when the arguments
are wrong, 3 when SQLite refused the lock or the row; the test reads the
line and the code.
"""
import sqlite3
import sys
import time


def main():
    if len(sys.argv) != 4 or not sys.argv[2].isdigit() or not sys.argv[3].isdigit():
        print("usage: sqlite_hold.py <path> <seconds> <key>", file=sys.stderr)
        return 2
    try:
        db = sqlite3.connect(sys.argv[1], timeout=0, isolation_level=None)
        db.execute("BEGIN IMMEDIATE")
        db.execute("INSERT INTO places (city, mass, n, ok) VALUES ('hold', NULL, ?, 1)", (int(sys.argv[3]),))
    except sqlite3.Error as error:
        print("refused: %s" % error, file=sys.stderr)
        return 3
    sys.stdout.write("locked\n")
    sys.stdout.flush()
    time.sleep(int(sys.argv[2]))
    try:
        db.execute("COMMIT")
        db.close()
    except sqlite3.Error as error:
        print("commit refused: %s" % error, file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
