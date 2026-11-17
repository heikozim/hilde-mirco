/* The routines of LAPACK and BLAS that Mirco binds, as the C translation of
   lapack-netlib in OpenBLAS and the BLAS interface of BLIS define them: every
   argument by address, integers of 32 bits, matrices in column-major order. */
#ifndef MIRCO_LAPACK_H
#define MIRCO_LAPACK_H
int dgesv_(int *n, int *nrhs, double *a, int *lda, int *ipiv, double *b, int *ldb, int *info);
void dgetrf_(int *m, int *n, double *a, int *lda, int *ipiv, int *info);
void dpotrf_(char *uplo, int *n, double *a, int *lda, int *info);
void dgeqrf_(int *m, int *n, double *a, int *lda, double *tau, double *work, int *lwork, int *info);
void dorgqr_(int *m, int *n, int *k, double *a, int *lda, double *tau, double *work, int *lwork, int *info);
void dsyevd_(char *jobz, char *uplo, int *n, double *a, int *lda, double *w, double *work, int *lwork,
	int *iwork, int *liwork, int *info);
void dgesdd_(char *jobz, int *m, int *n, double *a, int *lda, double *s, double *u, int *ldu, double *vt,
	int *ldvt, double *work, int *lwork, int *iwork, int *info);
void dgelsd_(int *m, int *n, int *nrhs, double *a, int *lda, double *b, int *ldb, double *s, double *rcond,
	int *rank, double *work, int *lwork, int *iwork, int *info);
void dgemm_(const char *transa, const char *transb, const int *m, const int *n, const int *k,
	const double *alpha, const double *a, const int *lda, const double *b, const int *ldb,
	const double *beta, double *c, const int *ldc);
#endif
