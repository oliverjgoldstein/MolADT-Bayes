-- | Small catalogue of manually assembled molecules used across tests and examples.
module SampleMolecules
  ( hydrogen
  , oxygen
  , water
  , methane
  ) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
    ( AtomId(..)
    , Edge(..)
  , NonNegative(..)
  , SystemId(..)
  , mkBondingSystem
  )
import Chem.Molecule
  ( Atom(..)
  , AtomicSymbol(..)
  , ElementAttributes(..)
  , Coordinate(..)
  , Molecule(..)
  , SmilesAtomStereo(..)
  , SmilesAtomStereoClass(..)
  , SmilesBondStereo(..)
  , SmilesBondStereoDirection(..)
    , SmilesStereochemistry(..)
    , emptySmilesStereochemistry
    , mkAngstrom
    )
import Constants (elementAttributes)

hydrogen :: Molecule
hydrogen = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.74) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        ]
  , systems = [(SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 2))) Nothing)]
  , smilesStereochemistry = emptySmilesStereochemistry
  }

oxygen :: Molecule
oxygen = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 1.21) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        ]
  , systems = [(SystemId 1, mkBondingSystem (NonNegative 4) (S.singleton (Edge (AtomId 1) (AtomId 2))) Nothing)]
  , smilesStereochemistry = emptySmilesStereochemistry
  }

water :: Molecule
water = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.96) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.32)) (mkAngstrom 0.9) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 2))) Nothing)
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 3))) Nothing)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }

methane :: Molecule
methane = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 1.09) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-1.09)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 1.09) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom (-1.09)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 2))) Nothing)
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 3))) Nothing)
      , (SystemId 3, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 4))) Nothing)
      , (SystemId 4, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 5))) Nothing)
      ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }
