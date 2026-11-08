#!/usr/bin/env python3
"""Writes src/Font.hiq from tools/font-5x7.txt: the rows of the 95 printable
characters of ASCII as one string of hexadecimal digits, two for each row, the
leftmost pixel the highest of five bits.  It stops unless every character from
32 to 126 is there once, in order, with seven rows of five pixels.

    python3 tools/make-font.py tools/font-5x7.txt > src/Font.hiq
"""
import sys

lines = [l.rstrip('\n') for l in open(sys.argv[1], encoding='ascii') if not l.startswith('# ')]
glyphs = []
i = 0
while i < len(lines):
    head = lines[i]
    if not head.startswith('= '):
        raise SystemExit('line %d: no "= c" but %r' % (i, head))
    name = head[2:]
    char = ' ' if name == 'space' else name
    if len(char) != 1:
        raise SystemExit('line %d: %r is no one character' % (i, name))
    rows = lines[i + 1:i + 8]
    if len(rows) != 7 or any(len(r) != 5 or set(r) - set('#.') for r in rows):
        raise SystemExit('character %r: not seven rows of five' % char)
    glyphs.append((char, rows))
    i += 8
if [c for c, _ in glyphs] != [chr(c) for c in range(32, 127)]:
    raise SystemExit('the characters are not 32 to 126 in order')
hexrows = ''
for _, rows in glyphs:
    for r in rows:
        v = 0
        for p in r:
            v = v * 2 + (1 if p == '#' else 0)
        hexrows += '%02x' % v
print('''--
-- Part of Hilde, under the Apache License v2.0 with LLVM Exceptions.
-- See LICENSE file for details.
--
-- SPDX-FileCopyrightText: 2026 Heiko Zimmermann
-- SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

-- The rows of the font as one string of hexadecimal digits, seven rows of
-- two digits for each character from 32 to 126.  Written by
-- tools/make-font.py from tools/font-5x7.txt.
module body Mirco.Font is
    constant rows: Span[Nat8, Static] := "%s";

    function hexValue(d: Nat8): Nat8 is
        if d >= 97 then
            return d - 87;
        end if;
        return d - 48;
    end;

    function glyphRow(c: Nat8, row: Index): Nat8 is
        if (c < 32) or (c > 126) or (row >= 7) then
            return 0;
        end if;
        case toIndex(c - 32) of
            when Some(value as k: Index) do
                let table: Span[Nat8, Static] := rows;
                let at: Index := 2 * ((k * 7) + row);
                return (hexValue(table[at]) * 16) + hexValue(table[at + 1]);
            when None do
                return 0;
        end case;
    end;
end module body.''' % hexrows)
