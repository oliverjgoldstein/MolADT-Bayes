# Molecule Equality

Use `sameMolecule` when you want to ask whether two `Molecule` values are the
same MolADT object after harmless ordering differences are removed.

It is stricter than graph isomorphism, but more useful than raw `Eq` for
serialized molecules.

## What It Ignores

`sameMolecule` ignores incidental ordering in:

- `Map AtomId Atom`
- the `systems :: [(SystemId, BondingSystem)]` list
- `memberEdges` inside each `BondingSystem`
- stereochemistry annotation lists
- endpoint order inside an `Edge`

Atom IDs and system IDs still matter. If atom `1` and atom `2` are swapped
throughout the whole molecule, that is a relabelled molecule, not the same
MolADT value under `sameMolecule`.

## Haskell Example

```haskell
import qualified Data.Set as S

import Chem.Dietz (BondingSystem(..), Edge(..))
import Chem.Molecule (Molecule(..), sameMolecule)
import ExampleMolecules.Diborane (diboranePretty)

flipEdge :: Edge -> Edge
flipEdge (Edge left right) = Edge right left

reordered :: Molecule
reordered =
  diboranePretty
    { systems =
        [ ( systemId
          , system
              { memberEdges =
                  S.fromList
                    [ flipEdge edge
                    | edge <- S.toList (memberEdges system)
                    ]
              }
          )
        | (systemId, system) <- reverse (systems diboranePretty)
        ]
    }

sameMolecule diboranePretty reordered
-- True
```

Raw `Eq` is still allowed to be false here because the `systems` list order and
some direct `Edge` constructors differ. `sameMolecule` says the molecular ADT
content is the same.

## Structural Changes Still Fail

```haskell
import qualified Data.Set as S

import Chem.Dietz (AtomId(..), Edge(..))
import Chem.Molecule (Molecule(..), sameMolecule)
import ExampleMolecules.Diborane (diboranePretty)

changed :: Molecule
changed =
  diboranePretty
    { systems =
        [ entry@(systemId, system)
        | entry@(systemId, system) <- systems diboranePretty
        , Edge (AtomId 1) (AtomId 2) `S.notMember` memberEdges system
        ]
    }

sameMolecule diboranePretty changed
-- False
```

Removing a bonding system changes the molecule, so the equality check fails.

## When To Use It

Use `sameMolecule` for round-trip tests, JSON comparisons, generated molecule
deduplication, and checks where the source may serialize maps, sets, or systems
in a different order.

Use a separate isomorphism or relabelling check if you want to treat different
atom IDs as equivalent.
