# Repo Map

Use this page when you need to find the right file quickly.

## App

- [`app/Main.hs`](../app/Main.hs): CLI dispatcher.
- [`examples/ParseMolecules.hs`](../examples/ParseMolecules.hs): small standalone parse example.

## Chemistry Core

- [`src/Chem/Molecule.hs`](../src/Chem/Molecule.hs): typed molecule and pretty report.
- [`src/Chem/Dietz.hs`](../src/Chem/Dietz.hs): atoms, edges, bonding systems.
- [`src/Chem/Validate.hs`](../src/Chem/Validate.hs): validation.
- [`src/Chem/Molecule/Coordinate.hs`](../src/Chem/Molecule/Coordinate.hs): coordinates.
- [`src/Group.hs`](../src/Group.hs): type-class sketch for group structure and molecular symmetry actions.
- [`src/Orbital.hs`](../src/Orbital.hs): shell, subshell, and orbital ADTs.

## IO

- [`src/Chem/IO/SDF.hs`](../src/Chem/IO/SDF.hs): SDF parser.
- [`src/Chem/IO/SMILES.hs`](../src/Chem/IO/SMILES.hs): conservative SMILES parser and renderer.
- [`src/Chem/IO/MoleculeJSON.hs`](../src/Chem/IO/MoleculeJSON.hs): shared MolADT JSON.
- [`src/Chem/IO/MoleculeViewer.hs`](../src/Chem/IO/MoleculeViewer.hs): standalone single-molecule and collection viewer export.
- [`src/Chem/IO/SDFTiming.hs`](../src/Chem/IO/SDFTiming.hs): opt-in parser timing utility, not part of the generic test suite.

## Examples

- [`src/ExampleMolecules/Benzene.hs`](../src/ExampleMolecules/Benzene.hs)
- [`src/ExampleMolecules/Morphine.hs`](../src/ExampleMolecules/Morphine.hs)
- [`src/ExampleMolecules/Diborane.hs`](../src/ExampleMolecules/Diborane.hs)
- [`src/ExampleMolecules/Ferrocene.hs`](../src/ExampleMolecules/Ferrocene.hs)
- [`molecules/`](../molecules/): small SDF inputs.

## Benchmarking

- [`src/Benchmarking/BenchmarkModel.hs`](../src/Benchmarking/BenchmarkModel.hs): Haskell FreeSolv exported-matrix benchmark consumer.
- [`src/Benchmarking/GaussianProcess.hs`](../src/Benchmarking/GaussianProcess.hs): exact GP linear algebra helpers for the 30-feature RBF path.
- [`src/Benchmarking/FreeSolvWLBondingGP.hs`](../src/Benchmarking/FreeSolvWLBondingGP.hs): legacy MolADT-only WL + bonding-system FreeSolv GP.
- [`docs/freesolv-gp-feature-list.md`](freesolv-gp-feature-list.md): latest 30-feature FreeSolv GP list.
- [`docs/freesolv-gp-feature-layman.md`](freesolv-gp-feature-layman.md): plain-English descriptions for the current 30 features.
- [`src/LazyPPL.hs`](../src/LazyPPL.hs): `mh` and `lwis` kernels.
- [`src/Benchmarking/FreeSolvInverseDesign.hs`](../src/Benchmarking/FreeSolvInverseDesign.hs): legacy exported-feature typed inverse-design search.

## Tests

- [`test/benchmark-alignment`](../test/benchmark-alignment/)
- [`test/edge-properties`](../test/edge-properties/)
- [`test/parser-roundtrip`](../test/parser-roundtrip/)
- [`test/validation-properties`](../test/validation-properties/)

Next: [Testing](testing.md), [CLI and demo](cli-and-demo.md).
