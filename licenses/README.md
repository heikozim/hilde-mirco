# Licences of the code Mirco carries or links

Mirco itself is under the Apache License v2.0 with LLVM Exceptions (`LICENSE` at the root). The files here are the
licences of code from other projects, copied unchanged from their upstreams, so that a copy of Mirco or of a
programme linked with its C backend carries them.

| File | Project | Where Mirco uses it |
|------|---------|---------------------|
| `numpy-random-LICENSE.md` | the generators of NumPy's random (Kevin Sheppard), NCSA and BSD 3-Clause | `Mirco.Random`, `Mirco.Bindings.Ziggurat` |
| `blis-LICENSE` | BLIS 2.1, BSD 3-Clause | `Mirco.Bindings.Lapack`, `Mirco.Lapack` (dgemm), linked as `libblis.a` |
| `lapack-LICENSE` | LAPACK of netlib, modified BSD, as lapack-netlib in OpenBLAS 0.3.34 | `Mirco.Bindings.Lapack`, `Mirco.Lapack`, linked as `libmircolapack.a` |
| `openblas-LICENSE` | OpenBLAS 0.3.34, BSD 3-Clause, the project the C translation of LAPACK comes from | as `lapack-LICENSE` |
| `pocketfft-numpy-LICENSE` | pocketfft of NumPy 1.26.4, BSD 3-Clause | `Mirco.Bindings.Pocketfft`, `Mirco.Pocketfft`, linked as `libmircopocketfft.a` |
| `mirco-blis-NOTICE` | the NOTICE of the repository mirco-blis: sources, versions and SHA-256 of the three | all of the C backend |

The four licences of the C backend and the NOTICE are byte for byte the files `c/blis/LICENSE`, `c/lapack/LICENSE`,
`c/lapack/LICENSE.OpenBLAS`, `c/pocketfft/LICENSE.numpy` and `NOTICE` of mirco-blis. Their SHA-256:

```text
6b54dbb27c2aeba07c72084ea948d3d7ec206758b119eef37a1cc4f958ac694c  blis-LICENSE
978539245c405775bf347b1256c36df4daf8b69a64b099e94b1d53742201621e  lapack-LICENSE
190b5a9c8d9723fe958ad33916bd7346d96fab3c5ea90832bb02d854f620fcff  openblas-LICENSE
263223390c43a9d4a0841e0209265fd927a198f8e89c8eee809b7437d7e5e8c2  pocketfft-numpy-LICENSE
28c76e09227112a53a5bf535474d7493522a4b18660b20fae0d336a7bcf06f85  mirco-blis-NOTICE
```

`scripts/check-licenses.sh` compares them with mirco-blis when `MIRCO_BLIS` names it; the gate runs it.
