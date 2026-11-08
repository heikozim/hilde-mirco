# Mirco: arrays for numerical work

Mirco (MIRCO = Matrices, Interpolation, Random numbers, Calculus, Optimization) is the science kit of Hilde: matrices, interpolation, random numbers, calculus and optimization, in
the place NumPy and SciPy have for Python. This page describes its parts: the array type, its views, its wire
format, the compute layer and the numerical modules. Mirco is a package of Hilde with the prefix `Mirco`; its modules come into a programme only
when it imports them.

| Module | What it holds |
|---|---|
| `Mirco.Element` | the element types, their codes and their bytes |
| `Mirco.Array` | the owning array `NdArray[T]` and the view `View[T, R]` |
| `Mirco.Wire` | the binary wire format of an owning array |
| `Mirco.Sperli` | the narrow interface Sperli asks of the array type: encode, decode, elementType, shape, combine |
| `Mirco.Numeric` | the arithmetic of the number types |
| `Mirco.Compute` | elementwise operations, reductions and the products of linear algebra |
| `Mirco.Linalg` | solve, determinant, inverse, Cholesky, QR, least squares, eigenvalues and singular values |
| `Mirco.Text` | a `Float64` read from decimal text and written as the shortest text that reads back |
| `Mirco.Csv` | a table of numbers in CSV read into a matrix, a vector or a matrix written as CSV |
| `Mirco.Root` | files of CERN's ROOT: the header, the keys of the directories and the bytes of their objects |
| `Mirco.RootTree` | the streamer information of a .root file and the simple branches of its trees |
| `Mirco.RNTuple` | the RNTuple of binary format 1.0: its fields of numbers and strings, at the top and below |
| `Mirco.Xxh3` | XXH3 of 64 bits, the checksum of the envelopes and pages of an RNTuple |
| `Mirco.Xz` | streams of xz with LZMA2, as liblzma writes them |
| `Mirco.Zstd` | frames of Zstandard, as the zstd tool writes them |
| `Mirco.Yompi` | YOMPI: lines, points, histograms and heatmaps as SVG or PNG |
| `Mirco.Font` | the pixel font of 5 by 7 with which YOMPI writes text into PNG images |
| `Mirco.Schlucki` | Schlucki: tables of named columns, missing values, filter, sort, group by, join, CSV and SQLite |
| `Mirco.Notebook` | the format of the notebooks: cells, cells of SPERLI, the manifest of the files written  |
| `Mirco.Cell` | the state between cells in files: tables as CSV, arrays in the wire format, images as SVG or PNG |
| `Mirco.Export` | functions callable from C and Python: dot, mean, deviation, matmul over bytes |
| `Mirco.Units` | quantities with their unit in the type, derived units of SI |
| `Mirco.Random` | the generators PCG64 and PCG64DXSM, uniform, normal and integer arrays |
| `Mirco.Stats` | variance, deviation, median, percentiles, histograms, covariance and correlation |
| `Mirco.Fft` | the discrete Fourier transform of any length and its inverse |
| `Mirco.Integrate` | the trapezoid and the Simpson rule, adaptive quadrature of a function |
| `Mirco.Interpolate` | linear interpolation and the natural cubic spline |
| `Mirco.Optimize` | roots by bisection and by Brent's method, the minimum by the golden section |
| `Mirco.Minimize` | the minimum of a function of several variables by Nelder and Mead or by BFGS |
| `Mirco.Math` | square root, powers, logarithms and angles on `Float64`, from the C library |
| `Mirco.Lapack`, `Mirco.Pocketfft` | the backend in C: Mirco.Linalg and Mirco.Fft by Lapack, blis and pocketfft |
| `Mirco.Hdf5`, `Mirco.NetCdf` | arrays written into HDF5 and netCDF files and read back |
| `Mirco.SchluckiStore` | tables of Schlucki in SQLite or DuckDB, the backend named by the caller |
| `Standard.Bits` | from the standard library of Hilde: the bits of a number as an unsigned number of the same width, which the wire format needs |

## Element types

| Type | Code | Width in bytes |
|---|---|---|
| `Float64` | 1 | 8 |
| `Float32` | 2 | 4 |
| `Int64` | 3 | 8 |
| `Int32` | 4 | 4 |
| `Nat8` | 5 | 1 |
| `Bool` | 6 | 1 |

A function over arrays of any element type names the typeclass `Element` in its constraint:
`generic [T: Free(Element), R: Region]`.

## Arrays

An `NdArray[T]` owns its elements, in row-major order, and its shape: a rank of 1 to 32 and every dimension at
least 1. It is linear and is given back with `destroyNdArray`.

    var grid: NdArray[Float64] := zeros(wholeSpan(&shape));
    set(&!grid, wholeSpan(&at), 2.5);
    let value: Float64 := get(&grid, wholeSpan(&at));
    destroyNdArray(grid);

- `zeros`, `filled` and `fromSpan` make an array; `reshape` gives the same elements another shape of the same
  count.
- `rank`, `dimension`, `count` and `dtypeCode` describe it; `get` and `set` take one position for each axis,
  `flatGet` and `flatSet` the position in row-major order, and `elements` lends all of them as a span.
- The contracts hold the rank of an index (`requires spanLength(index) = rank(array)`); a position outside its
  dimension stops the programme with a message.

The rank is a value of the array, not a parameter of its type: Hilde has no numbers as type parameters.

## Views

A `View[T, R]` borrows the array it shows, for as long as the borrow `R` lasts, and has its own offset, shape
and strides. It copies no element.

    borrow g: &[NdArray[Int64], Q] := &grid do
        let whole: View[Int64, Q] := view(g);
        let odd: View[Int64, Q] := slice(&whole, 1, 1, 4, 2);
        let copy: NdArray[Int64] := copyView(&odd);
        destroyView(odd);
        destroyView(whole);
        destroyNdArray(copy);
    end borrow;

- `slice` takes the positions start, start + step, ... below stop of one axis.
- `viewGet` reads through a view, and `copyView` makes a new owning array of what it shows.

## Broadcasting

Broadcasting follows NumPy: two shapes are aligned at their last axis, and two dimensions fit when they are
equal or one of them is 1; the shorter shape counts as 1 in the axes it lacks.

- `broadcastable(a, b)` says whether two shapes fit, `broadcastShape(a, b)` gives the shape they make.
- `broadcastTo(view, shape)` shows a view under a larger shape: an axis of length 1, or one the view lacks,
  repeats its element with stride 0.

## Computing

`Mirco.Compute` is the default compute layer, written in Hilde. Its functions take the number
types, those with an instance of `Numeric` (`Float64`, `Float32`, `Int64`, `Int32`, `Nat8`), and each gives a
new array.

- `add`, `subtract`, `multiply` and `divide` work element by element and broadcast their two arrays; they give
  `None` when the shapes do not broadcast. `addScalar` and `multiplyScalar` take one value for every element.
- `sum`, `product`, `minimum`, `maximum` and `mean` reduce all elements; `sumAxis`, `productAxis`,
  `minimumAxis`, `maximumAxis` and `meanAxis` reduce one axis, and the result has the other axes, or the shape 1
  for a vector. The smallest and the largest pass over a NaN unless every element is one.
- Partial results join: `combine(&first, &second, reduction)` joins two arrays of partial results element by
  element, `combineValues(x, y, reduction)` two values, with `reductionSum()`, `reductionMinimum()`,
  `reductionMaximum()` or `reductionProduct()` (1 to 4, the codes of Standard.SperliCollective). The partial
  result of a mean is a sum: the sums of the parts joined, then `meanOfSums(&sums, total)` divides by the count
  of all parts along the axis, so that no rounded partial mean is carried. Two shapes that differ give `None`;
  nothing is broadcast.
- `dot` of two vectors, `transpose` of a matrix, `matvec` and `matmul`; `gemv` and `gemm` are the products of
  the basic linear algebra subprograms, `y := alpha * m * x + beta * y` and `c := alpha * a * b + beta * c`,
  written into their last argument.
- An integer overflow and a division by zero stop the programme, also for a floating point type; that is how
  the operators of Hilde behave.
- The test vectors in `src/Compute.test.hiq` are worked out by hand. Whole numbers and floating point numbers
  that binary64 and binary32 hold exactly are compared exactly; decimals without an exact binary form, such as
  0.1 + 0.2 + 0.3, within 1e-12 relative for `Float64` and 1e-6 relative for `Float32`. Each vector takes fewer
  than ten roundings, whose steps at 1 are 2.2e-16 and 1.2e-7.

## Numerical modules

The modules of this part work on `Float64`. They are there for Linux, OpenBSD, FreeBSD and macOS; for
WebAssembly they are not, since they reach the C mathematics library through `Mirco.Math`.

- `Mirco.Random`: `pcg64(seed, stream)` is seeded as the reference implementation in C seeds it,
  and its first outputs for seed 42 and stream 54 are those of that implementation. `pcg64Dxsm` is the
  variant with the cheap multiplier. `nextNat64`, `nextBelow`, `nextFloat64` and `nextNormal` draw one
  number; `uniform`, `normal` and `integers` fill a new array. The numbers are reproducible on every system,
  and they are not for keys: a few outputs predict the rest.
  `defaultRng(seed)` is NumPy's `default_rng(seed)`, seeded through `SeedSequence`, and `nextStandardNormal` and
  `standardNormal` draw by NumPy's ziggurat: together they give the numbers NumPy gives for the same seed.
- `Mirco.Stats`: `variance` and `standardDeviation` take `ddof` as NumPy does, `percentile`
  interpolates linearly as NumPy does by default, and `histogram` holds `high` in its last bin. A NaN among
  the elements gives a NaN.
- `Mirco.Fft`: a `Signal` holds the real and the imaginary parts. `fft` and `inverseFft` take any
  length in time n log n, `realFft` gives the first n / 2 + 1 values of a real vector, and
  `fftFrequencies` the frequencies as `numpy.fft.fftfreq` gives them. The inverse divides by n.
- `Mirco.Integrate`: `trapezoid`, `trapezoidOver` and `simpson` over samples, `integrate` over a
  function, by adaptive Simpson quadrature.
- `Mirco.Linalg`: `solve`, `determinant` and `inverse` by LU with partial pivoting, `cholesky`, `qr`, `lstsq`,
  `eigenSymmetric` (ascending, as `numpy.linalg.eigh`) and `svd` (descending, as `numpy.linalg.svd` with
  `full_matrices=False`). A singular matrix gives `None`. `qr`, `eigenSymmetric` and `svd` give a
  `Decomposition`, whose arrays `part` hands out as copies.
- `Mirco.Text`: `parseFloat64` takes only text that is a number in full, blanks around it allowed, and
  `formatFloat64` writes the shortest text that reads back with the same bits. `Mirco.Csv`: `readMatrix`
  reads a table of numbers, a row of names skipped when asked, an empty field as a NaN; `writeMatrix` writes
  one back. Every refusal names its line and column.
- `Mirco.Root`: `readHeader`, `readKeys` and `readDirectoryKeys` read the container of a .root file, small or
  large, and `objectBytes` gives the bytes of an object, unpacked from zlib, LZ4, xz or Zstandard up to a limit; `objString` reads
  a TObjString. A malformed file is refused with a `RootError`, never with an abort.
- `Mirco.RootTree`: `readStreamers` gives every class of the streamer information with its version, checksum and
  members; `readTree` reads a TTree of version 19 or 20, and `branchInt64`, `branchFloat32` and `branchFloat64` give a
  branch of one leaf of numbers as a vector, or a matrix for a fixed array. A counted leaf, such as `Ai4[n]`,
  gives all its numbers as one vector, and `branchOffsets` gives where the numbers of each entry begin.
  `branchStrings` gives the texts of a leaf of characters, one for each entry.
  `readTreeWith` takes the streamer information of the file as well and reads the members of an object split into
  branches: numbers, fixed arrays, arrays counted by another member, std::vector of numbers and std::string.
  `narrowEntries(tree, first, count)` cuts a tree down to a range of its entries, which every reader then reads
  alone, unpacking only the baskets that hold some of them; a rank of Sperli takes its share with `rankFirst`
  and `rankCount` of `Mirco.RNTuple` over `treeEntries`, or by clusters with `narrowTreeClusters` over
  `treeClusterCount`, so that ranks meet where ROOT ended its baskets; `treeClustersAligned` says whether
  they did.
- `Mirco.RNTuple`: `readNtuple` reads the anchor, header, footer and page lists of an RNTuple of format 1.0;
  `fieldInt64`, `fieldFloat32`, `fieldFloat64` and `fieldStrings` give a field of the top, from plain or split
  columns. Every envelope and every page with a checksum is checked against its XXH3 (`Mirco.Xxh3`); a wrong one is refused with `BadChecksum`.
  A collection of numbers, a std::vector or an RVec, gives all its items through the same functions and
  `fieldOffsets` where each entry begins; a projected field reads through its alias columns, and a cardinality
  gives the count of items of each entry. A field below the top is named by its path:
  `fieldPath(tuple, "my_struct.sub_struct.i")` gives a number that each of these functions takes, as
  `items._0` does for the items of a collection or an array; a vector of vectors or of strings and a
  std::array give their values flat, a record only through its members. `fieldTags` gives the alternative of each value of a std::variant,
  -1 for none, and `variant._0`, `variant._1` the values of each alternative. `narrowClusters(t, first, count)`
  cuts the RNTuple down to a range of its clusters, which every reader then reads alone; `rankFirst` and
  `rankCount` share the clusters among the ranks of Sperli, and `clusterCount` and `clusterEntries` count them.
- `Mirco.Yompi` (YOMPI = Your Own Math and Plotting Interface): `figure(width, height)`, then `addLine`, `addScatter`, `addHistogram` or `setHeatmap`, and
  `setTitle`, `setXLabel`, `setYLabel`; `renderSvg` writes SVG with every text, `renderPng` a PNG image with the
  same texts in a pixel font of 5 by 7 of its own. Colours are 0xRRGGBB. The ticks lie at 1, 2 or 5 times a power of ten.
- `Mirco.Schlucki` (SCHLUCKI = Structured Columnar Handling: Load, Unify, Clean, Knit, Inspect): a `Table` of named columns of Float64, Int64, text or Bool; a missing value reads as
  `None`. `select`, `filter`, `sortBy`, `groupBy` and `join` each give a new table; rows are matched by
  position only, and no value is converted to another kind. `readCsv` takes a kind for each column;
  `fromQuery` and `insertRows` go through `Standard.Sqlite`.
- `Mirco.Interpolate`: `interpolate` as `numpy.interp`, and `spline` for a natural cubic spline.
- `Mirco.Optimize`: `bisect` and `brentRoot` find a root where the function changes its sign and
  give `None` otherwise; `minimizeGolden` finds the minimum of a function with one minimum in the interval.
- `Mirco.Minimize`: `nelderMead` and `bfgs` find the minimum of a function of several variables; the function is
  a value of a type with an instance of `Objective`, whose `valueAt` evaluates a vector.

## Units

`Mirco.Units` keeps the unit in the type: `meters(100.0)` is a `Quantity[Meter]`, and
`velocity(meters(100.0), seconds(9.58))` a `Quantity[MeterPerSecond]`. `add` and `subtract` take two quantities of one unit, so the
compiler refuses a length plus a time; a derived unit comes from the fixed table of SI functions (`area`,
`volume`, `velocity`, `acceleration`, `force`, `work`, `powerOf`, `pressure`, `frequency`, `charge`,
`voltage`, `resistance`, `density`). `format` writes `3.5 m/s`.

## From Python and as a script

`hilde compile src/Export.hih,src/Export.hiq --target-type=shared --output=libmirco.so` builds a library with
the functions `mirco_dot`, `mirco_mean`, `mirco_deviation` and `mirco_matmul`; a vector crosses as its bytes,
eight bytes little endian for each number. `examples/python/mirco_ctypes.py` shows the use from Python through
ctypes. A single script runs with `HILDE=/path/to/hilde tools/mirco-run Script.hiq`, in the root of the package; HILDE
names the compiler and, as `--modules`, its `standard/src` and `bindings/generated`.

## The C backend

`Mirco.Lapack` and `Mirco.Pocketfft` have the functions of `Mirco.Linalg` and `Mirco.Fft` with the same names,
arguments and results, computed by BLIS, the C translation of LAPACK and pocketfft; `Mirco.Lapack` adds
`matmul`, `dot`, `matvec`, `gemv` and `gemm` of `Mirco.Compute`, all by dgemm of BLIS: the header of mirco-blis
declares dgemm and no other routine of BLAS, so a dot product is a 1 by k times a k by 1 matrix. A programme
selects the backend by its import. They need the library `mircoblis` of the repository mirco-blis:
`sh tools/build-c.sh` there, then `PKG_CONFIG_PATH` set to its `_c/lib/pkgconfig`. The tests compare each
function with the one in pure Hilde within 1e-9 times 1 plus the value of pure Hilde, the vectors of an
eigenproblem and of an SVD up to their signs. The licences of BLIS, LAPACK, OpenBLAS and pocketfft stand in
`licenses/`, and the gate compares them with mirco-blis. 
## HDF5 and netCDF

`Mirco.Hdf5` and `Mirco.NetCdf` write an array of `Float64` or `Int64` into a file and read it back through
the libraries of the system, libhdf5 and libnetcdf, found by pkg-config as `hdf5` and `netcdf`.
`writeFloat64(path, name, &array, fresh)` writes a dataset or a variable, into a new file when `fresh` holds;
`readFloat64(path, name)` reads it with its dimensions. A dataset is read only as the type it holds, so an
integer dataset is refused as `Float64`; every failure is a fault, never an abort. The dimensions of a
dataset or a variable are checked before the array is made: a dimension of 0, and a count of elements that
does not fit an Index or goes above `readElementLimit()` (2^32 elements, 32 gigabyte of `Float64`), are
refused as `BadShape` or `BadDimensions`. A dimension of 0 gives no empty result, since an array holds every
dimension at least 1; a reader holds the product of the dimensions at or below the limit while it forms the
product, so the product can overflow no Index. netCDF files are of the format netCDF 4, and the dimensions
of a variable `x` are named `x_0`, `x_1` and so on.

## SQLite and DuckDB

`Mirco.SchluckiStore` keeps tables of Schlucki in a database of SQLite or of DuckDB, and the caller names
the backend: `openStore(backendDuckDb(), "facts.duckdb", true)`. `define` makes a table, `queryTable` reads
the rows of a query into a table of the kinds given, and `writeRows` writes every row of a table in one
transaction, all or none; DuckDB writes them through its Appender and so takes only
`INSERT INTO t (a, b) VALUES (?, ?)`. DuckDB comes from the library of the system, libduckdb 1.5.6 or newer, and every
database is opened with external access and extensions off and its configuration locked, so that no
statement reads or writes another file. One programme at a time writes a file of DuckDB.

## Wire format

An owning array is written as a header and its elements, all little endian.

| Bytes | Content |
|---|---|
| 0 to 3 | `M`, `I`, `R`, `C` (77, 73, 82, 67) |
| 4 | version, 1 |
| 5 | element code |
| 6 | rank, 1 to 32 |
| 7 | 0 |
| 8 to 8 + 8 * rank - 1 | each dimension as an unsigned 64-bit number |
| then | the elements in row-major order, each as wide as its type |

`encode(&array)` writes the bytes, `encodedLength(&array)` counts them, and `decode(bytes)` reads them back as
an array of the element type asked for. Before it takes an element, the decoder checks the magic, the
version, the element code against the type asked for, the rank, the zero byte, every dimension and the exact
length, and every Bool is 0 or 1. A refusal is a `WireError`: `TooShort`, `BadMagic`, `BadVersion`,
`UnknownElement`, `OtherElement`, `BadRank`, `BadReserved`, `BadDimension`, `BadLength` or `BadElement`. The
product of the dimensions is held below the bytes there are while it is formed, so a header that announces
more elements than an Index holds is refused, not wrapped.

The test vectors, the bytes for one array of each element type, stand in
`src/Wire.test.hiq`; they were computed with Python's `struct` module.

## The interface for Sperli

Sperli (Simple Parallel Execution over Remote Links Interface) has no array of its own. What it needs of the
array type is the narrow interface of docs/sperli-protocol.md of Hilde, and `Mirco.Sperli` fills it with
`Mirco.Array` and `Mirco.Wire`:

- `encode(&array, &!out)` appends the bytes of the wire format to `out` and gives their count.
- `decode(bytes)` gives the array back or a `WireError`; it is the decoder of `Mirco.Wire` and checks all of it
  before it takes an element.
- `elementType(&array)` gives the code of the table of Sperli: `Int32` 1, `Int64` 2, `Float32` 5, `Float64` 6.
  Sperli has no code for `Nat8` or `Bool`, so both are plain bytes, 0.
- `shape(&array)` gives the length of every axis.
- `combine(&first, &second, reduction)` reduces two arrays of the same shape element by element with
  `Standard.SperliCollective.combine` and its codes (sum 1, min 2, max 3, product 4, the logical and bitwise
  operations 5 to 10). It follows the rules of Sperli, not those of `Mirco.Compute`: whole numbers wrap around,
  and plain bytes, so `Nat8` and `Bool`, take only the bitwise operations. Two shapes that differ give
  `OtherShape`, a reduction that does not fit the type `NotCombined`. The result is read back by the decoder,
  so every element is checked once more.

Where Hilde differs from its design for this interface, Mirco follows the code of Hilde:

- The design says that no code is added for the interface; `Standard.SperliCollective.combine` exists and
  reduces flat arrays of bytes, and `Mirco.Sperli.combine` uses it.
- The collectives (`Standard.Sperli.reduce`, `allreduce`) and the checkpoints (`Standard.SperliCkpt` with the
  typeclass `Checkpointable`), deferred in the design, are built in Hilde.
- The table of Sperli numbers its element types otherwise than `Mirco.Element` does (Float64 6 there, 1 here),
  knows unsigned whole numbers Mirco has no type for, and knows neither `Nat8` nor `Bool`.
- docs/sperli-protocol.md writes `encode(value, buffer)` and `combine(a, b, operation)`; `Mirco.Sperli` takes
  the array by reference, the buffer as a write reference, and the arrays before the operation.

## Checking the package

Unlike `hilde test`, which takes a directory (`hilde test src`), `hilde check` takes no directory but
module sources, one word per module: a pair of interface and body such as `src/Array.hih,src/Array.hiq`,
or a body such as `src/Array.hiq`. A plain `hilde check` at the root of the package fails with H1004
for that reason. The whole package is checked by collecting the pairs the way
`scripts/gate.sh` collects them: every interface below `src/`, also one level deeper such as
`src/Bindings/DuckDB.hih`, with its body beside it. No script of the package writes the list down; it is made
in the call itself, at the root of the package, and `--modules` names, as in the gate, the `standard/src` and
`bindings/generated` of the Hilde tree that HILDE names:

    HILDE=/path/to/hilde
    hilde check "--modules=$HILDE/standard/src:$HILDE/bindings/generated" \
        $(for f in src/*.hih src/*/*.hih; do
              [ -e "${f%.hih}.hiq" ] && printf '%s,%s ' "$f" "${f%.hih}.hiq"
          done)

`hilde check` reads and checks the modules only; it builds no C and so needs neither the library `mircoblis`
nor `PKG_CONFIG_PATH` (The C backend). An interface without a body would be left out of the list silently;
`scripts/check-pairs.sh` names each one beforehand.
