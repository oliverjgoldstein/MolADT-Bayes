-- | Diborane (B2H6) with two explicit 3c-2e bridge systems.
module ExampleMolecules.Diborane
  ( diboranePretty
  ) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S

import Chem.Dietz
    ( AtomId(..)
    , BondingSystem
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

diboranePretty :: Molecule
diboranePretty = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes B, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes B), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes B, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes B), formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.9928), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom (-0.9928)), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom 1.19) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom (-0.885)) (mkAngstrom (-1.19)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom 1.19) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes H, coordinate = Coordinate (mkAngstrom 0.885) (mkAngstrom (-1.19)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes H), formalCharge = 0 })
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 3), Edge (AtomId 2) (AtomId 3)]) (Just "bridge_h3_3c2e"))
      , (SystemId 2, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 1) (AtomId 4), Edge (AtomId 2) (AtomId 4)]) (Just "bridge_h4_3c2e"))
      ]
        ++ [ singleCovalentSystem 3 (Edge (AtomId 1) (AtomId 2))
           , singleCovalentSystem 4 (Edge (AtomId 1) (AtomId 5))
           , singleCovalentSystem 5 (Edge (AtomId 1) (AtomId 6))
           , singleCovalentSystem 6 (Edge (AtomId 2) (AtomId 7))
           , singleCovalentSystem 7 (Edge (AtomId 2) (AtomId 8))
           ]
  , smilesStereochemistry = emptySmilesStereochemistry
  }

singleCovalentSystem :: Int -> Edge -> (SystemId, BondingSystem)
singleCovalentSystem systemId edge =
  (SystemId systemId, mkBondingSystem (NonNegative 2) (S.singleton edge) Nothing)
