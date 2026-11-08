#!/usr/bin/perl
# Writes src/Bindings/Ziggurat.hiq from numpy/random/src/distributions/ziggurat_constants.h
# of NumPy 1.26.4: the tables ki_double, wi_double and fi_double, each as a
# constant array of C indexed by the argument.  It stops unless each table
# has 256 entries.
#
#     perl tools/make-ziggurat.pl path/to/ziggurat_constants.h > src/Bindings/Ziggurat.hiq
use strict;
use warnings;
local $/;
my $src = <>;
my %t;
for my $name (qw(ki_double wi_double fi_double)) {
	$src =~ /static const (?:uint64_t|double) \Q$name\E\[\] = \{(.*?)\};/s or die "no $name\n";
	my @v = grep { length } map { s/^\s+|\s+$//gr } split /,/, $1;
	die "$name has " . scalar(@v) . " entries\n" unless @v == 256;
	$t{$name} = join(', ', @v);
}
print <<"EOF";
--
-- Part of Hilde, under the Apache License v2.0 with LLVM Exceptions.
-- See LICENSE file for details.
--
-- SPDX-FileCopyrightText: 2026 Heiko Zimmermann
-- SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

-- The three tables of the ziggurat of 256 layers for the standard normal
-- distribution, as NumPy 1.26.4 ships them in ziggurat_constants.h under
-- the licences of numpy/random (licenses/numpy-random-LICENSE.md).  Each is a
-- constant array of C, so that every value is the double the text of NumPy
-- gives.  Written by tools/make-ziggurat.pl.
pragma Unsafe_Module;

module body Mirco.Bindings.Ziggurat is
    function ki(i: Index): Nat64 is
        return \@embed(Nat64, "(\$1 < 256 ? ((const uint64_t[256]) { $t{ki_double} })[\$1] : 0)", i);
    end;

    function wi(i: Index): Float64 is
        return \@embed(Float64, "(\$1 < 256 ? ((const double[256]) { $t{wi_double} })[\$1] : 0.0)", i);
    end;

    function fi(i: Index): Float64 is
        return \@embed(Float64, "(\$1 < 256 ? ((const double[256]) { $t{fi_double} })[\$1] : 0.0)", i);
    end;
end module body.
EOF
