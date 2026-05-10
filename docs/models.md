# Models and Exported Features

This repo keeps the typed molecule implementation in Haskell and consumes the
benchmark feature matrices exported by Python.

## What Lives Here

The Haskell model path is narrow:

- dataset: `freesolv_moladt_featurized`
- default model: MolADT WL + bonding-system exact empirical-Bayes Gaussian process
- legacy exported-feature path: finite exact RBF Gaussian process
- legacy inference kernels: `mh` and `lwis`

Run:

```bash
make haskell-infer-benchmark
make haskell-freesolv-20split
```

The older exported-feature path is still available directly:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
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

## What The GP Does

For FreeSolv, the Haskell GP:

- reads the Python-exported MolADT feature matrix
- screens the train split to the strongest `24` feature channels
- builds an exact RBF covariance over the finite training rows
- samples GP hyperparameters with LazyPPL
- predicts validation and test rows with posterior averaging

The model-selection branch is deliberately small:

```haskell
modelFamilyFor :: BenchmarkDataset -> BenchmarkModelFamily
modelFamilyFor dataset
  | "freesolv_" `isPrefixOf` datasetPrefix dataset
    && representationName dataset == "moladt_featurized" = UseGaussianProcessRbf
  | otherwise = UseLinearStudentT
```

The GP hyperparameters are sampled as ordinary probabilistic code:

```haskell
gaussianProcessBenchmarkModel :: GaussianProcessSupport -> Meas BenchmarkParameters
gaussianProcessBenchmarkModel support = do
  meanOffset <- sample (normal 0.0 5.0)
  logKernelScale <- sample (normal 0.0 1.0)
  logLengthScale <- sample (normal 0.0 1.0)
  logNoiseScale <- sample (normal (-1.0) 1.0)
  let params = GaussianProcessParameters
        { gpMeanOffset = meanOffset
        , gpKernelScale = exp logKernelScale
        , gpLengthScale = exp logLengthScale
        , gpNoiseScale = exp logNoiseScale
        }
  scoreLog (Exp (fromMaybe (-1.0e12) (gaussianProcessLogLikelihood support params)))
  pure (GaussianProcessPosterior params)
```

The command prints molecule counts, feature counts, selected GP features, the
draw budget, a runtime expectation, and final metrics.

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

Difference from the previous GP:

- previous path: screened `moladt_featurized` scalar descriptor columns,
  standardized Euclidean distances, and an RBF kernel
- current default: sparse MolADT token counts from atoms, formal charges,
  orbitals, edges, and explicit bonding systems, compared with Tanimoto kernels
- no molecular fingerprints are used in the current default
- for a representation-led result, the current default is the primary model;
  the previous RBF GP is best treated as a baseline or ablation

## Why This Matters

MolADT gives Bayesian models an explicit typed generative state space. The
model can work with molecule fields, not just strings or plain graph labels.

Next: [Inference](inference.md), [Python interop](python-interop.md).
