# Quickstart

This is the shortest path to a working Haskell checkout.

## Build

From `MolADT-Bayes-Haskell`:

```bash
make haskell-build
```

If Stack is missing, the Makefile explains how to install it.

## Try The CLI

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse molecules/sodium_chloride.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- parse-smiles "[Na+][Cl-]"
stack run moladtbayes -- pretty-example benzene
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example sodium_chloride
stack run moladtbayes -- to-smiles molecules/benzene.sdf
stack run moladtbayes -- to-smiles molecules/sodium_chloride.sdf
make haskell-viewer
```

Those commands prove that SDF parsing, SMILES parsing, built-in examples, and
SMILES rendering are wired up for covalent and ionic cases. The viewer command
writes `results/viewer/benzene.viewer.html`.

## Test

```bash
make haskell-test
```

## Demo

```bash
make haskell-demo
```

The demo parses local molecules and runs a small FreeSolv benchmark smoke pass.
It prints molecule counts and a rough runtime expectation before inference
starts.

## Full Benchmark Consumer

```bash
make haskell-infer-benchmark
```

This runs the 30-feature exported-matrix RBF GP benchmark. It reads processed
feature and target exports from the sibling Python repo:

```bash
../MolADT-Bayes-Python/data/processed
```

Override that path with:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed \
  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

`make haskell-freesolv-20split` runs the additional WL-token GP over the
committed `data/freesolv_wl_system_20_splits.json` file.

`make haskell-freesolv-feature-list` regenerates
`docs/freesolv-wl-token-feature-list.md`, the sparse token names used by the
WL GP. The current 30-feature paper list lives in
`docs/freesolv-gp-feature-list.md`.

## Common Fixes

- Missing Stack: run `make haskell-build` and follow the install hint.
- Missing benchmark exports: generate them in the Python repo, then rerun.
- Unsure what command exists: run `make help`.

Next: [CLI and demo](cli-and-demo.md), [Inference](inference.md),
[FreeSolv GP feature list](freesolv-gp-feature-list.md),
[FreeSolv GP feature translations](freesolv-gp-feature-layman.md),
[Python interop](python-interop.md).
