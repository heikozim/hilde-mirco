#!/usr/bin/perl
# Writes c/pocketfft/pocketfft.c from c/pocketfft/_pocketfft.c.orig, the file
# numpy/fft/_pocketfft.c of NumPy 1.26.4: the licence head and the C core are
# kept as they are; the includes of Python and NumPy and every line from the
# first function over PyObject on are left out, and four plain C functions
# over arrays of double are appended.  It checks that the cut lines are the
# ones it expects and stops otherwise.
#
#     perl tools/make-pocketfft.pl c/pocketfft/_pocketfft.c.orig > c/pocketfft/pocketfft.c
use strict;
use warnings;
my @l = <>;
die "unexpected length\n" unless @l == 2384;
die "line 15 is not the include of Python\n" unless $l[14] =~ /^#include <Python\.h>$/;
die "line 2195 is not the first PyObject function\n" unless $l[2194] =~ /^static PyObject \*$/;
print @l[0 .. 10];
print "#include <assert.h>\n";
print "#include \"mirco_pocketfft.h\"\n";
print @l[19 .. 2193];
print <<'EOF';
/* The functions Mirco binds.  Each returns 0 when the transform was made and
   -1 when a plan or a buffer could not be allocated or n is 0. */

int mirco_cfft(double *c, size_t n, int forward, double fct)
{
  if (n == 0) return -1;
  cfft_plan plan = make_cfft_plan(n);
  if (!plan) return -1;
  int res = forward ? cfft_forward(plan, c, fct) : cfft_backward(plan, c, fct);
  destroy_cfft_plan(plan);
  return res == 0 ? 0 : -1;
}

int mirco_rfft_forward(double *c, size_t n, double fct)
{
  if (n == 0) return -1;
  rfft_plan plan = make_rfft_plan(n);
  if (!plan) return -1;
  int res = rfft_forward(plan, c, fct);
  destroy_rfft_plan(plan);
  return res == 0 ? 0 : -1;
}

int mirco_rfft_backward(double *c, size_t n, double fct)
{
  if (n == 0) return -1;
  rfft_plan plan = make_rfft_plan(n);
  if (!plan) return -1;
  int res = rfft_backward(plan, c, fct);
  destroy_rfft_plan(plan);
  return res == 0 ? 0 : -1;
}
EOF
