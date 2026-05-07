# MolADT-Bayes-Haskell

## Molecules, as data.

MolADT is a compact Haskell representation for molecules that need to be
inspected, validated, serialized, and scored by probabilistic models.

Boundary formats stay at the edge. The molecule stays in the ADT.

<p align="center">
  <img src="docs/assets/ferrocene.png" alt="Ferrocene in the MolADT viewer" width="280">
  <img src="docs/assets/diborane.png" alt="Diborane in the MolADT viewer" width="280">
</p>

```text
Molecule = atoms + bonding systems + stereochemistry
```

[Quickstart](docs/quickstart.md) | [ADT](docs/data-model.md) |
[Representation](docs/representation.md) | [Examples](docs/examples.md) |
[Equality](docs/molecule-equality.md) | [CLI](docs/cli-and-demo.md) |
[Viewer](docs/parsing.md#viewer) | [Validator](#validator) |
[Inference](docs/inference.md)

## Why MolADT

String formats are useful for exchange. Plain graphs are useful for traversal.
Neither is a great home for all of the chemistry a model may need to reason
about.

MolADT keeps the important structure explicit:

- atoms with element data, coordinates, formal charge, shells, and orbitals
- every edge represented as a Dietz bonding system
- an edge network derived from bonding-system member edges
- delocalized and multicentre chemistry in the same bonding-system layer
- SMILES stereochemistry annotations as their own typed layer
- shared JSON serialization for Haskell and the sibling Python repo
- Haskell type classes for attaching laws and algebraic structure

That gives inference and inverse-design code a molecule it can inspect directly,
instead of a string it has to reinterpret at every step.

Read more in [MolADT ADT Representation](docs/data-model.md) and
[MolADT Representation](docs/representation.md).

## The Shape

The core Haskell value is deliberately small:

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

`systems` is the canonical Dietz bonding layer. A conventional single, double,
triple, or quadruple bond is a one-edge Dietz `BondingSystem` with `2`, `4`,
`6`, or `8` shared electrons. Pretty printers and viewers display these as
`single covalent`, `double covalent`, `triple covalent`, or `quadruple covalent`.
In the Dietz representation an ionic contact is also a one-edge
`BondingSystem`, but it shares `0` electrons, displays as `ionic`, and stores
formal charge on the atoms rather than on the edge itself.
Sodium chloride therefore has `Na#1` at `+1`, `Cl#2` at `-1`, and one 0e
`ionic` system over the Na-Cl edge.
Pretty printing derives display edges from the bonding systems and reports the
total electrons shared over each edge. For benzene, a C-C edge is shown as
`shared=3e` and `order=1.50`: `2e` from the one-edge `single covalent` system plus
`1e/edge` from the six-electron `pi_ring`. The viewer lists the same explicit
bonding systems.
System identifiers are stable display IDs. Checked examples and parsers put
named or multi-edge systems first, so benzene uses `SystemId 1` for `pi_ring`
and then numbers the ordinary one-edge covalent systems after it.
Shells are optional on atoms, and `elementAttributes` now carries the default
shell data used by simple constructors.

Use [`sameMolecule`](docs/molecule-equality.md) when you want equality modulo
container ordering, such as maps, system lists, member-edge sets, and
annotation lists. It keeps atom and system identifiers meaningful.

The point is not to replace SMILES or SDF. The point is to parse them into a
typed structure where the chemistry is available as data.

Because this is Haskell, the representation is not just a convention. `AtomId`,
`SystemId`, `NonNegative`, and `Angstrom` are separate types; shells and
orbitals are algebraic data types; and type classes can state behavior and laws
around the molecule without hiding the molecule fields.

## What It Unlocks

- **Clearer chemistry**: diborane bridges, ferrocene Cp/metal systems, ionic salts, and
  morphine fused topology can be represented explicitly.
- **Safer boundaries**: SDF, SMILES, and JSON parsing happen at the edge, then
  validation runs on the typed molecule.
- **Shared contracts**: Haskell and Python use the same MolADT JSON shape for
  round-trips and benchmark exports.
- **Better model inputs**: the Haskell benchmark consumer works from
  Python-exported MolADT feature matrices rather than raw notation.
- **Editable structure**: inverse-design experiments can operate on atoms,
  hydrogens, and bonding systems as typed concepts.
- **Inspectable outputs**: the standalone viewer shows atoms, every edge, and
  explicit electron-sharing systems from the same typed payload. Charge renders
  as blue/red halos around charged atoms; halo size and opacity scale with
  formal-charge magnitude, atoms in ionic bonding systems get an additional
  boost, and ionic edges draw a charge gradient.
  Ordinary covalent edges are dark grey one/two/three/four-line strokes for
  single/double/triple/quadruple bonds, with those one-edge systems labelled in
  the side panel. When an edge belongs to more than one bonding system, each
  system overlay gets a dashed lane, including ordinary covalent versus
  delocalised overlap in ferrocene; non-standard systems are labelled as
  delocalised bonding and use coloured dashed overlays.
- **Algebraic contracts**: rotations, atom relabelings, or other transforms can
  be expressed with type classes as groups acting on molecules, giving
  geometric models a clear place to state invariance and equivariance.

See [Example Molecules](docs/examples.md), [Parsing and Rendering](docs/parsing.md),
and [Type Classes And Group Actions](docs/representation.md#type-classes-and-group-actions).

## Why It Helps Bayesian Work

MolADT is useful as a general explicit typed generative model for Bayesian
chemistry tasks. The model can generate, edit, validate, and score molecules as
structured values:

- priors can be written over atoms, edges, charges, rings, and bonding systems
- proposal kernels can make local typed edits instead of string rewrites
- invalid chemistry can be rejected at the molecule boundary
- likelihoods and descriptors can inspect the same explicit object
- posterior samples can be serialized through the shared MolADT JSON contract

That is the point of the ADT: Bayesian inference and inverse design can work on
the molecule itself, not a notation that has to be decoded on every move.

## Validator

`validateMolecule` is a representation validator, not a physical chemistry
oracle. It rejects malformed MolADT values before parsing, viewing,
serialization, benchmark consumption, or inverse-design scoring continue.

It checks that atom map keys match `atomID`, atom IDs and system IDs are
positive, coordinates and element metadata are finite, system IDs are unique,
bonding systems are non-empty and reference existing atoms, cached member atoms
match member edges, duplicate bonding systems are absent, and SMILES
stereochemistry annotations only point at known atoms. It also enforces the
MolADT edge contract: ordinary one-edge covalent systems with `2`, `4`, `6`, or
`8` shared electrons must be unnamed and display as single/double/triple/
quadruple covalent bonds; one-edge `0e` systems must be tagged `ionic`; and
`ionic` systems must share zero electrons over exactly one edge.

It deliberately does not prove physical realism, infer missing hydrogens,
choose protonation states, or decide whether a delocalised system is chemically
preferred. Those are task-level constraints layered on top of the representation
validator.

## Start

```bash
make haskell-build
stack run moladtbayes -- parse molecules/benzene.sdf
stack run moladtbayes -- parse-smiles "c1ccccc1"
stack run moladtbayes -- pretty-example benzene
stack run moladtbayes -- pretty-example ferrocene
stack run moladtbayes -- pretty-example sodium_chloride
make haskell-viewer
```

For the full first-run path, use [Quickstart](docs/quickstart.md).

## Explore By Task

| Task | Go to |
| --- | --- |
| Understand the ADT | [ADT Representation](docs/data-model.md) |
| See why MolADT is not just a graph | [Representation](docs/representation.md) |
| Inspect benzene, morphine, diborane, ferrocene, or sodium chloride | [Examples](docs/examples.md) |
| Compare reordered molecules | [Molecule Equality](docs/molecule-equality.md) |
| Parse SDF, SMILES, or MolADT JSON | [CLI and Demo](docs/cli-and-demo.md) |
| Export a standalone HTML viewer | [Parsing and Rendering](docs/parsing.md#viewer) |
| Check parser scope and validation rules | [SMILES Scope and Validation](docs/smiles-scope-and-validation.md) |
| Run the Haskell benchmark consumer | [Inference](docs/inference.md) |
| Understand exported feature matrices | [Models and Exported Features](docs/models.md) |
| Work across the Python repo boundary | [Python Interop](docs/python-interop.md) |
| Find files quickly | [Repo Map](docs/repo-map.md) |
| Run tests | [Testing](docs/testing.md) |

## Commands

```bash
stack run moladtbayes -- --help
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
stack run moladtbayes -- view-html molecules/benzene.sdf --output results/viewer/benzene.viewer.html
stack run moladtbayes -- pretty-example benzene --viewer-output results/viewer/benzene.viewer.html
stack run moladtbayes -- pretty-example diborane --viewer-output results/viewer/diborane.viewer.html
stack run moladtbayes -- pretty-example sodium_chloride --viewer-output results/viewer/sodium-chloride.viewer.html
stack run moladtbayes -- to-smiles molecules/benzene.sdf
make haskell-test
make haskell-viewer
make haskell-demo
make haskell-infer-benchmark
```

Viewer commands print both the HTML path and a portable `file://` URL. With
`--open-viewer` or `OPEN_VIEWER=1`, the same URL is printed as the manual
fallback if the operating system does not open a browser automatically.

The Haskell benchmark path is intentionally narrow: it consumes the Python
`freesolv_moladt_featurized` export and runs a local exact RBF Gaussian process
over the typed MolADT feature matrix. The Python repo owns the larger benchmark
runner and paper artifacts.

## Scope

This repo is the typed Haskell implementation and aligned benchmark consumer.
It includes:

- the MolADT molecule ADT
- conservative SDF and SMILES boundary parsing
- shared MolADT JSON serialization
- built-in typed molecule examples
- a compact FreeSolv inference and inverse-design path

For the full benchmark pipeline, data processing, figures, and Python-side
experiments, use
[MolADT-Bayes-Python](https://github.com/oliverjgoldstein/MolADT-Bayes-Python).
