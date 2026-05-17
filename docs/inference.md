# Inference

The Haskell repo is the FreeSolv benchmark consumer.

Python owns the full benchmark pipeline and writes the processed FreeSolv
exports. Haskell reads those matrices and runs the local 30-feature RBF GP
consumer.

## Main Command

```bash
make haskell-infer-benchmark
```

Direct form:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
```

The Makefile path uses:

```text
dataset_prefix=freesolv_moladt_featurized
method=mh:0.2
feature_cap=30
```

## Methods

Accepted method strings:

- `mh`
- `mh:<jitter>`
- `lwis`
- `lwis:<particles>`

Examples:

```bash
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2
stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized lwis:64 128
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

The legacy `freesolv-wl-system-gp` command still prints its split source,
train+valid and test counts, RMSE, MAE, R2, mean predictive standard deviation,
and 90% coverage. Keep it for tokenizer diagnostics rather than the main
FreeSolv result.

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

Next: [Benchmarking models and exported features](models.md), [Python interop](python-interop.md).
