/* The C interface of pocketfft that Mirco binds, over arrays of double.
   mirco_cfft transforms n complex numbers stored as n pairs of real and
   imaginary part in place, forward when forward is not 0, and multiplies
   the result by fct.  mirco_rfft_forward transforms n real numbers in place
   into the half complex order of FFTPACK: r0, r1, i1, r2, i2, and so on,
   the last real part alone when n is even.  mirco_rfft_backward is its
   inverse.  Each returns 0 when the transform was made and -1 when n is 0 or
   memory could not be allocated. */
#ifndef MIRCO_POCKETFFT_H
#define MIRCO_POCKETFFT_H
#include <stddef.h>
int mirco_cfft(double *c, size_t n, int forward, double fct);
int mirco_rfft_forward(double *c, size_t n, double fct);
int mirco_rfft_backward(double *c, size_t n, double fct);
#endif
