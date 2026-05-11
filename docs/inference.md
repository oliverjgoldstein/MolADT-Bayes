# Inference

The Haskell repo is the FreeSolv benchmark consumer.

It does not own the full benchmark pipeline. Python writes the processed
`mol_id`/target exports. Haskell reads them, parses the matching SDF molecules,
and runs the MolADT WL + bonding-system GP locally.

## Main Command

```bash
make haskell-infer-benchmark
make haskell-freesolv-20split
make haskell-freesolv-feature-list
```

Direct form:

```bash
stack run moladtbayes -- freesolv-wl-system-gp --seed 18
```

The default command uses the repo-local seed-18 split:

```bash
stack run moladtbayes -- freesolv-wl-system-gp \
  --split-json data/freesolv_wl_system_seed18_split.json
```

The repeated-split target uses the committed 20-split JSON:

```bash
make haskell-freesolv-20split
stack run moladtbayes -- freesolv-wl-system-gp --all-splits \
  --split-json data/freesolv_wl_system_20_splits.json \
  --output results/freesolv_20split/run_manual/freesolv_wl_system_20split.csv
```

The feature-document target writes the exact token names used by the GP:

```bash
make haskell-freesolv-feature-list
stack run moladtbayes -- freesolv-wl-system-features \
  --output docs/freesolv-gp-feature-list.md
```

## Methods

The default `freesolv-wl-system-gp` command is an exact empirical-Bayes GP. The
older `infer-benchmark` consumer remains available for exported feature-matrix
experiments.

Accepted method strings:

- `mh`
- `mh:<jitter>`
- `lwis`
- `lwis:<particles>`

Example:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized lwis:64 128
```

The default Makefile path uses:

```text
model=MolADT WL + bonding-system GP
seed=18
split_json=data/freesolv_wl_system_seed18_split.json
```

## What It Prints

Before inference starts, the command prints:

- train, validation, test, and total molecule counts
- feature count
- selected GP features
- inference method
- burn-in, posterior sample count, and draw budget
- rough runtime expectation

After inference, it prints:

- measured inference runtime
- posterior summary
- validation metrics
- per-test-row predictions
- test metrics

The WL + bonding-system command prints the split source, train+valid and test
counts, RMSE, MAE, R2, mean predictive standard deviation, and 90% coverage.
It uses parsed MolADT molecules directly: element symbols, formal charges,
shell/orbital occupancy, effective edge order, shared electrons, and
bonding-system overlap all enter the token kernels.

The literal feature names are listed in
[FreeSolv GP feature list](freesolv-gp-feature-list.md).

## Data Location

Default:

```bash
../MolADT-Bayes-Python/data/processed
```

Override:

```bash
MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed \
  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

Next: [Models and exported features](models.md), [Python interop](python-interop.md).
