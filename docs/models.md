# Models and Exported Features

This repo keeps the typed molecule implementation in Haskell and consumes the
benchmark feature matrices exported by Python.

## What Lives Here

The Haskell model path is narrow:

- dataset: `freesolv_moladt_featurized`
- default model: MolADT WL + bonding-system exact empirical-Bayes Gaussian process
- paper ablation: A-F graph/multigraph/Dietz ladder in the Python repo

Run:

```bash
make haskell-infer-benchmark
make haskell-freesolv-20split
```

For the MolADT-only WL + bonding-system GP:

```bash
stack run moladtbayes -- freesolv-wl-system-gp --seed 18
```

The default split is the repo-local seed-18 single split:

```bash
stack run moladtbayes -- freesolv-wl-system-gp \
  --split-json data/freesolv_wl_system_seed18_split.json
```

For repeated-split uncertainty:

```bash
make haskell-freesolv-20split
```

That target reads `data/freesolv_wl_system_20_splits.json` and writes a CSV to
`results/freesolv_20split/`.

## What The Features Are

Python builds MolADT molecules, computes MolADT-native descriptors, and writes
standardized `X/y` matrices.

Haskell reads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

## MolADT WL + Bonding-System GP

The `freesolv-wl-system-gp` command is the Haskell equivalent of the default
Python MolADT-only FreeSolv GP:

- it reads `freesolv_moladt_featurized_features.csv` only for `mol_id` and
  `expt`
- it loads each matching FreeSolv SDF through the Haskell SDF parser
- it does not use RDKit or SMILES features
- atom labels include element symbol, formal-charge bucket, shell count,
  orbital count, shell electron count, and shell occupancy signature
- edge labels and system tokens are derived from MolADT bonding systems,
  effective order, shared electrons, overlap count, and system kind
- the exact GP combines Tanimoto kernels over WL + bonding-system tokens,
  bonding-system tokens, and WL graph tokens
- the default split is the same seed-18 single split used by the Python repo

The kernel is:

```text
k(x, x') =
  w_all    * Tanimoto(WL + bonding-system tokens)
  + w_sys  * Tanimoto(bonding-system tokens)
  + w_wl   * Tanimoto(WL graph tokens)
```

Tanimoto is used because the features are sparse non-negative token counts, so
similarity should mean shared active chemistry relative to the union of active
chemistry rather than Euclidean distance in a dense descriptor table.

On the local seed-18 split, the Haskell path reported
`0.650917` kcal/mol RMSE and `0.408483` kcal/mol MAE on 65 held-out molecules.

## Representation Ablation

The paper comparison is the Python A-F ablation rather than the legacy RBF
descriptor GP:

| Label | Variant | Meaning | Test RMSE |
| --- | --- | --- | ---: |
| A | atom bag | atoms only, no connectivity | `1.857 +/- 0.361` |
| B | simple graph WL | atoms plus binary adjacency | `1.060 +/- 0.131` |
| C | bond-order graph WL | one edge per atom pair with bond-order labels | `1.049 +/- 0.142` |
| D | multigraph multiplicity WL | parallel-edge-style multiplicity from effective order | `1.020 +/- 0.123` |
| E | Dietz edge WL | Dietz-derived edge labels without separate system tokens | `1.049 +/- 0.142` |
| F | full MolADT | Dietz edge labels plus explicit bonding-system tokens | `0.904 +/- 0.168` |

That ladder is the direct test of the representation claim: non-multigraph graph
structure versus multigraph-like order versus explicit Dietz bonding systems.

## Why This Matters

MolADT gives Bayesian models an explicit typed generative state space. The
model can work with molecule fields, not just strings or plain graph labels.

Next: [Inference](inference.md), [Python interop](python-interop.md).
