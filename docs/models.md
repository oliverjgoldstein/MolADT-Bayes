# Benchmarking Models and Exported Features

This repo keeps the typed molecule implementation in Haskell and consumes the
benchmark feature matrices exported by Python.

## What Lives Here

The active Haskell benchmark path is narrow:

- dataset: `freesolv_moladt_featurized`
- default command: `infer-benchmark freesolv_moladt_featurized mh:0.2`
- default model family: exact RBF Gaussian process over 30 screened exported
  MolADT features
- paper ablation: A/B/C atom-bag/SMILES-graph/full-MolADT ladder in the Python
  repo

Run:

```bash
make haskell-infer-benchmark
```

Direct form:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

The `freesolv-wl-system-gp` command remains available as an additional
orbital-aware WL + bonding-system GP, but it is no longer the default FreeSolv
result to cite.

## What The Features Are

Python builds MolADT molecules, computes MolADT-native descriptors, and writes
standardized `X/y` matrices. Haskell reads:

- `<prefix>_X_train.csv`
- `<prefix>_X_valid.csv`
- `<prefix>_X_test.csv`
- `<prefix>_y_train.csv`
- `<prefix>_y_valid.csv`
- `<prefix>_y_test.csv`

For `freesolv_moladt_featurized`, Haskell chooses the strongest 30 exported
features by training-set correlation and runs the RBF GP over that screened
matrix.

The latest paper-facing Python feature set is the fixed
`moladt_full30_rbf_gp` list:

- composition and polarity signals
- explicit bonding-system and effective-order summaries
- ring, rotatable-bond, and short-range radial descriptors

That fixed list is documented in
[FreeSolv GP feature list](freesolv-gp-feature-list.md), with a plain-English
companion in [FreeSolv GP feature translations](freesolv-gp-feature-layman.md).

## Kernel

The active dense-descriptor GP uses an RBF kernel over standardized features:

```text
k(x, x') =
  signal_variance * exp(-||z(x) - z(x')||^2 / (2 * lengthscale^2))
```

Haskell samples the mean offset, signal variance, lengthscale, and observation
noise, then uses exact GP conditioning for validation and test predictions.

## Historical FreeSolv Result

The latest committed FreeSolv paper result before the multigraph feature redo
is:

```text
../MolADT-Bayes-Python/results/freesolv_ablation/run_20260512_small_feature_ablation/
```

Its 20-split test metrics are:

| Label | Variant | Meaning | Test RMSE |
| --- | --- | --- | ---: |
| A | atom bag | 10 atom-count features | `1.971 +/- 0.567` |
| B | SMILES adjacency graph | 20 graph-only features | `1.791 +/- 0.505` |
| C | full MolADT | previous 20 graph features plus 10 MolADT descriptors | `1.308 +/- 0.461` |

Re-run the Python `make freesolv-ablation` target before citing an RMSE for the
current multigraph-first C-row feature contract.

Next: [Inference](inference.md), [Python interop](python-interop.md).
