# Files of scikit-hep-testdata

The `.root` files here are test files of uproot, taken unchanged from scikit-hep-testdata v0.6.9
(`src/skhep_testdata/data/` of <https://github.com/scikit-hep/scikit-hep-testdata>, fetched on 2026-10-27 from
`https://raw.githubusercontent.com/scikit-hep/scikit-hep-testdata/v0.6.9/src/skhep_testdata/data/<name>`). They
are under the BSD 3-Clause licence of the Scikit-HEP Administrators, `LICENSE` beside them.

| File | SHA-256 | Holds |
|---|---|---|
| uproot-sample-6.20.04-uncompressed.root | 53cc776b8b3c831967ed7281178b382a8d894d7673ae9223bed9f835108d9a31 | the TTree sample of ROOT 6.20.04, 30 entries, no compression |
| uproot-sample-6.20.04-zlib.root | eda641030e502a93758a311c5b8834cce2a0c28f80e2e93e6830911d6363ea27 | the same, zlib |
| uproot-sample-6.20.04-lz4.root | bba6cd2629b604e40ef595dd9554a57219d9a572dfb0e8a1967a7c511d0e3827 | the same, LZ4 |
| uproot-sample-6.20.04-lzma.root | de141fb9ca4a8a4732e2334dd8a907b3713226c85c6120f4387dbf0d4644ec86 | the same, LZMA |
| test_int_float_rntuple_v1-0-0-0.root | 2dbd4e9688861f2040505155d41fafcdb8eb5e63214dd43976f6b75e974245c0 | an RNTuple of format 1.0.0.0, an int32 and a float field |
| ntpl001_staff_rntuple_v1-0-0-0.root | 3562f610fdba54f5c8515496a7639d708ce95ea656fe6076755812dc86c812a9 | the RNTuple Staff of ROOT's tutorial ntpl001, 3354 entries, Zstandard |
| rntviewer-testfile-uncomp-single-rntuple-v1-0-0-0.root | aa6ed8d4bb821ab55c0a5ecb7cd2e05f098fc6a355ca6025e9f5e83c5fc62db6 | an RNTuple of two string fields, no compression |
| uproot-small-evnt-tree-fullsplit.root | e5032b776cafd9e048d8b88bfdb00d7e7eff785b0fe120d628aec3b30e4c7b1a | a TTree of version 19, ROOT 6.08.06, 100 entries of an object Event split into its members: numbers, fixed arrays, counted arrays, std::vector, TString and std::string; zlib |
| test_1jag_int_float_rntuple_v1-0-0-0.root | a37891c82d06a1479fe390780f0b6c7723f5f4995f91add126dd3c56d7e7ca57 | an RNTuple of 100 entries with a std::vector<std::int32_t> and a std::vector<float>, Zstandard |
| uproot-Zmumu.root | 8290ddc1f2b1f866f30df016558936da27107f7f5b87e574c741f2baab1bad64 | the TTree events of uproot's Zmumu sample, zlib |
| uproot-Zmumu-zstd.root | c504a3dbe5f26986019093ebd47b236c3dcc3d7bd847610c91bfabce56209f1a | the same tree, Zstandard |
| test_index_multicluster_rntuple_v1-0-0-0.root | 3c96a33a3c1fccd92374c6a5f97ae1e22ca42e93cc9de9b7f776b0a73e6e004e | 200 entries of a std::vector<std::int16_t> in 3 clusters, written by dev/make-root/rntuple_index_multicluster.C, Zstandard |
| test_nested_structs_rntuple_v1-0-0-0.root | 446f0e7d524f645b9f000b95c0a50698a017b50b5e6d1bd149d50c7048524fe1 | 10 entries of a record of a record of a record with a std::vector<int>, written by dev/make-root/rntuple_nested_structs.C |
| test_stl_containers_rntuple_v1-0-0-0.root | 29580a1af991729c85e4e4b2777b70deed665711a9fd7fa6a466e9bde029e3ff | 5 entries of strings, vectors of vectors and of strings, arrays, variants, tuples, pairs and records, written by dev/make-root/rntuple_stl_containers.C |
| test_multiple_cluster_groups_rntuple_v1-0-0-0.root | ac612c1333643cf5138aa25470f5dcfebc0d13059788bf924fd012736969bc24 | 1000 entries of an int and a std::vector<std::int16_t> in 12 clusters, with cluster groups committed at the entries 450 and 750 by dev/make-root/rntuple_multiple_cluster_groups.C, Zstandard |
| Run2012BC_DoubleMuParked_Muons_1000evts_rntuple_v1-0-0-0.root | 6a71d6ca866b76c8d89689dfce2cc402aecd2aea0ff03a650db9fe78e60b8385 | the muons of 1000 events of CMS open data, written by the RNTupleImporter: a collection, projected RVec fields and a cardinality |

The file uproot-small-evnt-tree-fullsplit.root was fetched the same way on 2026-10-27. So were the two RNTuple files
of collections; their pages are packed by Zstandard, and their tests hold what does not depend on this reader:
the counts against each other, and every charge of a muon 1 or -1. The values its tests expect
were read from the bytes of its baskets by a script outside the reader: entry i holds i, ten times i in the
fixed arrays, i mod 10 times i in the counted arrays and vectors, and the text std-00i.

The muons of Run2012BC_DoubleMuParked_Muons_1000evts_rntuple_v1-0-0-0.root are CMS open data: its events come
from Run2012BC_DoubleMuParked_Muons.root, the record "DoubleMuParked dataset from 2012 in NanoAOD format
reduced on muons" of the CERN Open Data Portal, <https://opendata.cern.ch/record/12341>, DOI
10.7483/OPENDATA.CMS.LVG5.QT81, under CC0-1.0 (looked up on 2026-10-28 through the search of the portal for
that file name). CC0 asks for no notice; the record is named here so the origin can be followed.

The two Zmumu files were fetched the same way on 2026-10-28. Their test holds that the tree packed by Zstandard
gives the same values as the tree packed by zlib, which the sample of ROOT 6.20.04 already tests.

The two files of several clusters were fetched the same way on 2026-10-28. The values their tests expect are
those their generator scripts, under `dev/make-root/` of scikit-hep-testdata v0.6.9, write: in the first,
entry 100 j + i holds i and i + j; in the second, entry k holds k in the field one and k and k + 1 in the
vector.

The values the tests expect come from the tests of uproot 5.7.7 (`tests/test_0016_interpretations.py`,
`tests/test_0018_array_fetching_interface.py`, `tests/test_0630_rntuple_basics.py`,
`tests/test_0013_rntuple_anchor.py`): the branch i4 holds -15 to 14, its basket 3 lies at 35042 and holds 6 to
12, f4 begins with -14.899999618530273, and the RNTuple ntuple begins with 9, 8, 7. The first row of Staff is
the first row of ROOT's cernstaff data.
