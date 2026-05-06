-- | Morphine represented as explicit Dietz-style atoms, sigma edges, bonding systems, and SMILES stereochemistry.
module ExampleMolecules.Morphine
  ( morphinePretty
  , morphineRingClosureSmiles
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

morphineRingClosureSmiles :: String
morphineRingClosureSmiles = "CN1CC[C@]23C4=C5C=CC(O)=C4O[C@H]2[C@@H](O)C=C[C@H]3[C@H]1C5"

morphinePretty :: Molecule
morphinePretty = Molecule
  { atoms =
      M.fromList
        [ (AtomId 1, Atom { atomID = AtomId 1, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.0) (mkAngstrom 0.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        , (AtomId 2, Atom { atomID = AtomId 2, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.0) (mkAngstrom 0.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 3, Atom { atomID = AtomId 3, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 2.0) (mkAngstrom 0.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 4, Atom { atomID = AtomId 4, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 2.0) (mkAngstrom (-0.4)) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        , (AtomId 5, Atom { atomID = AtomId 5, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 3.0) (mkAngstrom 0.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 6, Atom { atomID = AtomId 6, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 4.0) (mkAngstrom 0.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 7, Atom { atomID = AtomId 7, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 5.0) (mkAngstrom 0.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 8, Atom { atomID = AtomId 8, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.8) (mkAngstrom 2.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 9, Atom { atomID = AtomId 9, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 2.8) (mkAngstrom 2.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 10, Atom { atomID = AtomId 10, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 3.8) (mkAngstrom 2.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 11, Atom { atomID = AtomId 11, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 0.8) (mkAngstrom 2.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 12, Atom { atomID = AtomId 12, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 1.2) (mkAngstrom 3.2) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 13, Atom { atomID = AtomId 13, attributes = elementAttributes O, coordinate = Coordinate (mkAngstrom 0.4) (mkAngstrom 4.0) (mkAngstrom 0.0), shells = defaultShells (elementAttributes O), formalCharge = 0 })
        , (AtomId 14, Atom { atomID = AtomId 14, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 2.4) (mkAngstrom 3.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 15, Atom { atomID = AtomId 15, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 3.6) (mkAngstrom 3.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 16, Atom { atomID = AtomId 16, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 4.2) (mkAngstrom 2.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 17, Atom { atomID = AtomId 17, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 5.4) (mkAngstrom 2.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 18, Atom { atomID = AtomId 18, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 6.2) (mkAngstrom 1.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 19, Atom { atomID = AtomId 19, attributes = elementAttributes N, coordinate = Coordinate (mkAngstrom 7.2) (mkAngstrom 1.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes N), formalCharge = 0 })
        , (AtomId 20, Atom { atomID = AtomId 20, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 8.2) (mkAngstrom 2.4) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        , (AtomId 21, Atom { atomID = AtomId 21, attributes = elementAttributes C, coordinate = Coordinate (mkAngstrom 6.0) (mkAngstrom 2.8) (mkAngstrom 0.0), shells = defaultShells (elementAttributes C), formalCharge = 0 })
        ]
  , systems =
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.fromList [Edge (AtomId 5) (AtomId 6)]) (Just "alkene_bridge"))
      , (SystemId 2, mkBondingSystem (NonNegative 6) (S.fromList [Edge (AtomId 10) (AtomId 11), Edge (AtomId 10) (AtomId 16), Edge (AtomId 11) (AtomId 12), Edge (AtomId 12) (AtomId 14), Edge (AtomId 14) (AtomId 15), Edge (AtomId 15) (AtomId 16)]) (Just "phenyl_pi_ring"))
      ]
        ++ [ (SystemId 3, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 2))) Nothing)
           , (SystemId 4, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 1) (AtomId 11))) Nothing)
           , (SystemId 5, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 2) (AtomId 3))) Nothing)
           , (SystemId 6, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 2) (AtomId 8))) Nothing)
           , (SystemId 7, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 3) (AtomId 4))) Nothing)
           , (SystemId 8, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 3) (AtomId 5))) Nothing)
           , (SystemId 9, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 5) (AtomId 6))) Nothing)
           , (SystemId 10, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 6) (AtomId 7))) Nothing)
           , (SystemId 11, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 7) (AtomId 8))) Nothing)
           , (SystemId 12, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 7) (AtomId 18))) Nothing)
           , (SystemId 13, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 8) (AtomId 9))) Nothing)
           , (SystemId 14, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 8) (AtomId 10))) Nothing)
           , (SystemId 15, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 9) (AtomId 21))) Nothing)
           , (SystemId 16, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 10) (AtomId 11))) Nothing)
           , (SystemId 17, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 10) (AtomId 16))) Nothing)
           , (SystemId 18, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 11) (AtomId 12))) Nothing)
           , (SystemId 19, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 12) (AtomId 13))) Nothing)
           , (SystemId 20, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 12) (AtomId 14))) Nothing)
           , (SystemId 21, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 14) (AtomId 15))) Nothing)
           , (SystemId 22, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 15) (AtomId 16))) Nothing)
           , (SystemId 23, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 16) (AtomId 17))) Nothing)
           , (SystemId 24, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 17) (AtomId 18))) Nothing)
           , (SystemId 25, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 18) (AtomId 19))) Nothing)
           , (SystemId 26, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 19) (AtomId 20))) Nothing)
           , (SystemId 27, mkBondingSystem (NonNegative 2) (S.singleton (Edge (AtomId 19) (AtomId 21))) Nothing)
           ]
  , smilesStereochemistry = SmilesStereochemistry [SmilesAtomStereo (AtomId 2) StereoTetrahedral 1 "@", SmilesAtomStereo (AtomId 3) StereoTetrahedral 2 "@@", SmilesAtomStereo (AtomId 7) StereoTetrahedral 1 "@", SmilesAtomStereo (AtomId 8) StereoTetrahedral 1 "@", SmilesAtomStereo (AtomId 18) StereoTetrahedral 1 "@"] []
  }