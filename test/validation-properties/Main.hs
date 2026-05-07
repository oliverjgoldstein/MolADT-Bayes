{-# LANGUAGE ScopedTypeVariables #-}

-- | Property-based tests targeting the molecular validator.  The suite checks
-- invariants of the benzene example under structural transformations.
module Main (main) where

import Test.QuickCheck hiding (NonNegative)
import ExampleMolecules.Benzene (benzene)
import Chem.IO.SMILES (parseSMILES)
import Chem.Molecule
import Chem.Dietz
import Chem.Validate (validateMolecule, usedElectronsAt)
import Constants (elementAttributes)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as M
import qualified Data.Set as S

-- | Relabel a molecule according to a permutation of its 'AtomId's.  All
-- structural data (atoms, bonds and Dietz systems) are updated consistently.
relabelMolecule :: Molecule -> [AtomId] -> Molecule
relabelMolecule m perm = Molecule atoms' systems' (smilesStereochemistry m)
  where
    oldIds   = M.keys (atoms m)
    mapping  = M.fromList (zip oldIds perm)
    rename i = mapping M.! i

    atoms' = M.fromList
      [ (rename i, a { atomID = rename i })
      | (i, a) <- M.toList (atoms m) ]

    systems' =
      [ ( sid
        , mkBondingSystem (sharedElectrons bs)
                          (S.fromList [ mkEdge (rename i) (rename j)
                                       | Edge i j <- S.toList (memberEdges bs) ])
                          (tag bs))
      | (sid, bs) <- systems m
      ]

-- | Property: validation result is invariant under AtomId relabelling.
prop_permInvariant :: Property
prop_permInvariant = forAll genPerm $ \perm ->
  let mol' = relabelMolecule benzene perm
  in isRight (validateMolecule mol') === isRight (validateMolecule benzene)
  where
    genPerm = shuffle (M.keys (atoms benzene))
    isRight (Right _) = True
    isRight _         = False

-- | Property: each ring carbon gains one electron from the \(\pi\) system in
-- addition to its local \(\sigma\) bonds (total of four electrons).
prop_benzeneElectronAccounting :: Property
prop_benzeneElectronAccounting = conjoin
  [ counterexample ("Atom " ++ show i) $
      let sigma  = fromIntegral (length (neighborsSigma benzene i))
          total  = usedElectronsAt benzene i
          system = total - sigma
      in system === 1.0 .&&. total === 4.0
  | i <- ringCarbons ]
  where
    ringCarbons = map AtomId [1..6]

testAtom :: Integer -> AtomicSymbol -> Atom
testAtom n sym =
  Atom
    { atomID = AtomId n
    , attributes = attrs
    , coordinate = Coordinate (mkAngstrom (fromIntegral n)) (mkAngstrom 0.0) (mkAngstrom 0.0)
    , shells = defaultShells attrs
    , formalCharge = 0
    }
  where
    attrs = elementAttributes sym

smallMolecule :: [(SystemId, BondingSystem)] -> Molecule
smallMolecule systems' =
  Molecule
    (M.fromList [(AtomId 1, testAtom 1 C), (AtomId 2, testAtom 2 C), (AtomId 3, testAtom 3 C)])
    systems'
    emptySmilesStereochemistry

expectValidationFailure :: String -> Molecule -> IO ()
expectValidationFailure expected molecule =
  case validateMolecule molecule of
    Left err ->
      if expected `isInfixOf` err
        then pure ()
        else error ("Unexpected validation failure: " ++ err)
    Right _ ->
      error ("Expected validation failure containing: " ++ expected)

runStructuralValidationTests :: IO ()
runStructuralValidationTests = do
  expectValidationFailure "Duplicate SystemId 1" $
    smallMolecule
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (mkEdge (AtomId 1) (AtomId 2))) Nothing)
      , (SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (mkEdge (AtomId 2) (AtomId 3))) Nothing)
      ]
  expectValidationFailure "has no member edges" $
    smallMolecule
      [ (SystemId 1, BondingSystem (NonNegative 0) S.empty S.empty Nothing)
      ]
  expectValidationFailure "Ordinary covalent one-edge systems" $
    smallMolecule
      [ (SystemId 1, mkBondingSystem (NonNegative 4) (S.singleton (mkEdge (AtomId 1) (AtomId 2))) (Just "alkene_bridge"))
      ]
  expectValidationFailure "Ionic bonding systems" $
    smallMolecule
      [ (SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (mkEdge (AtomId 1) (AtomId 2))) (Just "ionic"))
      ]
  expectValidationFailure "non-finite coordinate" $
    Molecule
      (M.fromList
        [ ( AtomId 1
          , (testAtom 1 C) { coordinate = Coordinate (mkAngstrom (0 / 0)) (mkAngstrom 0.0) (mkAngstrom 0.0) }
          )
        , (AtomId 2, testAtom 2 C)
        ])
      [(SystemId 1, mkBondingSystem (NonNegative 2) (S.singleton (mkEdge (AtomId 1) (AtomId 2))) Nothing)]
      emptySmilesStereochemistry

-- | Execute the QuickCheck properties defined above.
main :: IO ()
main = do
  quickCheck prop_permInvariant
  quickCheck prop_benzeneElectronAccounting
  runStructuralValidationTests
  case parseSMILES "CC1(C)CN(C(=O)Nc2cc3ccccc3nn2)C[C@@]2(CCOC2)O1" of
    Left err -> error ("Unexpected parse failure in documented ZINC validation case: " ++ err)
    Right mol ->
      case validateMolecule mol of
        Left err ->
          if err == "Atom 11 exceeds maximum valence"
            then pure ()
            else error ("Unexpected validation failure message: " ++ err)
        Right _ ->
          error "Expected documented ZINC validation failure, but validation unexpectedly succeeded"
