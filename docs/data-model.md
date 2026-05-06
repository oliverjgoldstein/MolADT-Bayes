# MolADT Data Model

MolADT represents a molecule as ordinary Haskell data.

The core value is not a string, a dictionary, or a loose graph. It is a record
with typed fields:

```haskell
data Molecule = Molecule
  { atoms :: Map AtomId Atom
  , systems :: [(SystemId, BondingSystem)]
  , smilesStereochemistry :: SmilesStereochemistry
  }
```

```text
Molecule = atoms + bonding systems + stereochemistry
```

That gives one inspectable object with four layers:

- `atoms`: atom table
- `systems`: canonical Dietz bonding systems
- `smilesStereochemistry`: stereo annotations from boundary notation

Every edge belongs to a bonding system. Conventional single, double, triple,
and quadruple bonds are one-edge systems with `2`, `4`, `6`, and `8` shared
electrons, displayed as `single covalent`, `double covalent`,
`triple covalent`, and `quadruple covalent`.
Pretty-printing derives edge rows and shared-electron totals from the bonding
systems.

## Haskell Shape

The representation uses Haskell's type system directly:

- `data` types for molecule structure
- `newtype` wrappers for stable identifiers and units
- records for named fields
- smart constructors where a value has an invariant
- derived instances for equality, printing, binary encoding, and evaluation

The small wrappers matter. `AtomId`, `SystemId`, `NonNegative`, and `Angstrom`
are not interchangeable numbers.

```haskell
newtype AtomId      = AtomId Integer
newtype SystemId    = SystemId Int
newtype NonNegative = NonNegative { getNN :: Int }
newtype Angstrom    = Angstrom Double

data Coordinate = Coordinate
  { x :: Angstrom
  , y :: Angstrom
  , z :: Angstrom
  }
```

## Atoms

```haskell
data AtomicSymbol = H | C | N | O | S | P | Si | F | Cl | Br | I | Fe | B | Na

data ElementAttributes = ElementAttributes
  { symbol       :: AtomicSymbol
  , atomicNumber :: Int
  , atomicWeight :: Double
  , defaultShells :: Shells
  }

data Atom = Atom
  { atomID       :: AtomId
  , attributes   :: ElementAttributes
  , coordinate   :: Coordinate
  , shells       :: Shells
  , formalCharge :: Int
  }
```

An atom carries identity, element data, 3D coordinates, shell/orbital data, and
formal charge. That is why downstream code can ask about the molecule directly
instead of reparsing a notation string.

`Shells` is optional (`Maybe Orb.Shells`). `elementAttributes` contains the
default shell data for each element, and `elementShells` is retained only as a
compatibility wrapper around `defaultShells . elementAttributes`.

## Bonding Systems

```haskell
data Edge = Edge AtomId AtomId

data BondingSystem = BondingSystem
  { sharedElectrons :: NonNegative
  , memberAtoms     :: Set AtomId
  , memberEdges     :: Set Edge
  , tag             :: Maybe String
  }
```

`systems` is the bonding layer. The edge network is the union of
`memberEdges` across those bonding systems.

That is how MolADT can represent things like:

- benzene `pi_ring`
- diborane `3c-2e` bridges
- ferrocene Cp/metal systems

Example shape for one benzene-style pi system:

```haskell
piRing :: BondingSystem
piRing =
  mkBondingSystem
    (NonNegative 6)
    (S.fromList
      [ Edge (AtomId 1) (AtomId 2)
      , Edge (AtomId 1) (AtomId 6)
      , Edge (AtomId 2) (AtomId 3)
      , Edge (AtomId 3) (AtomId 4)
      , Edge (AtomId 4) (AtomId 5)
      , Edge (AtomId 5) (AtomId 6)
      ])
    (Just "pi_ring")
```

`mkBondingSystem` derives `memberAtoms` from the edge set, so the atom scope and
edge scope cannot drift apart.

## Orbitals

```haskell
data So = So
data P = Px | Py | Pz
data D = Dxy | Dyz | Dxz | Dx2y2 | Dz2
data F = Fxxx | Fxxy | Fxxz | Fxyy | Fxyz | Fxzz | Fzzz

data PureOrbital
  = PureSo So
  | PureP  P
  | PureD  D
  | PureF  F

data Orbital subshellType = Orbital
  { orbitalType      :: subshellType
  , electronCount    :: Int
  , orientation      :: Maybe Coordinate
  , hybridComponents :: Maybe [(Double, PureOrbital)]
  }

newtype SubShell subshellType = SubShell
  { orbitals :: [Orbital subshellType] }

data Shell = Shell
  { principalQuantumNumber :: Int
  , sSubShell              :: Maybe (SubShell So)
  , pSubShell              :: Maybe (SubShell P)
  , dSubShell              :: Maybe (SubShell D)
  , fSubShell              :: Maybe (SubShell F)
  }

type Shells = [Shell]
```

This is Haskell-specific: the subshell type parameter prevents an `Orbital P`
from being silently mixed into a `SubShell D`.

In the molecule layer, `Chem.Molecule.Shells` wraps this as `Maybe Orb.Shells`
so atom shells can be omitted.

For example, iodine's final valence shell is written as explicit `5s2 5p5`
data:

```haskell
Shell
  { principalQuantumNumber = 5
  , sSubShell = Just (SubShell
      [ Orbital
          { orbitalType      = So
          , electronCount    = 2
          , orientation      = Nothing
          , hybridComponents = Nothing
          }
      ])
  , pSubShell = Just (SubShell
      [ Orbital
          { orbitalType      = Px
          , electronCount    = 2
          , orientation      = Just (angCoord 1 0 0)
          , hybridComponents = Nothing
          }
      , Orbital
          { orbitalType      = Py
          , electronCount    = 1
          , orientation      = Just (angCoord 0 1 0)
          , hybridComponents = Nothing
          }
      , Orbital
          { orbitalType      = Pz
          , electronCount    = 0
          , orientation      = Nothing
          , hybridComponents = Nothing
          }
      ])
  , dSubShell = Nothing
  , fSubShell = Nothing
  }
```

The full shell definitions live in
[`src/Orbital.hs`](../src/Orbital.hs).

## Minimal Molecule

This is the shape of water as a typed molecule:

```haskell
water :: Molecule
water =
  Molecule
    { atoms = M.fromList
      [ (AtomId 1, let attrs = elementAttributes O in Atom { atomID = AtomId 1, attributes = attrs, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells attrs, formalCharge = 0 })
      , (AtomId 2, let attrs = elementAttributes H in Atom { atomID = AtomId 2, attributes = attrs, coordinate = Coordinate (mkAngstrom 0.96) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells attrs, formalCharge = 0 })
      , (AtomId 3, let attrs = elementAttributes H in Atom { atomID = AtomId 3, attributes = attrs, coordinate = Coordinate (mkAngstrom (-0.32)) (mkAngstrom 0.9) (mkAngstrom 0.0), shells = defaultShells attrs, formalCharge = 0 })
      ]
    , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 2)]) Nothing)
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 3)]) Nothing)
      ]
    , smilesStereochemistry = emptySmilesStereochemistry
    }
```

The important part is that the O-H edges are themselves one-edge `single
covalent` systems.

## Canonical Normal Form

Checked molecules use a direct canonical form:

- atoms keyed by `AtomId`
- edges written as normalized `Edge` values
- bonding systems sorted by `SystemId`
- coordinates stored in Angstroms
- examples expanded as literal atoms, edges, and bonding systems
- no hidden chemistry inside ranges, zips, or generated tables

## Stereo

SMILES stereochemistry is kept in its own layer. It is not hidden inside an
edge or atom string.

This keeps the core molecule inspectable while still preserving boundary
stereo information.

## Type Classes

Haskell keeps behavior separate from the data shape through type classes.
Equality, serialization, pretty printing, validation helpers, and algebraic
structure can be attached without turning `Molecule` into a dynamic object.

That matters for geometric and Bayesian modelling. A rotation, atom relabeling,
or rigid transform can be expressed as a type with a `Group` instance, and
`Molecule` can be made an instance of the corresponding action. The laws then
become explicit contracts: compose, invert, apply identity, and preserve the
quantities that should be invariant.

See [Representation](representation.md#type-classes-and-group-actions) and
[`src/Group.hs`](../src/Group.hs).

## Interop Boundary

The sibling Python repo mirrors the same JSON contract, but this repo's
representation is the Haskell ADT. JSON is the boundary between languages; the
Haskell source remains records, constructors, maps, sets, and type classes.

Next: [Representation](representation.md), [Python interop](python-interop.md).
