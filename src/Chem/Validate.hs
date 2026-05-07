{-# LANGUAGE OverloadedStrings #-}

-- | Validation routines for Dietz-based molecules.  The validator enforces
-- structural invariants (existing atoms, symmetric bond maps, reasonable
-- valence counts) and returns the molecule unchanged on success.
module Chem.Validate
  ( validateMolecule
  , usedElectronsAt
  ) where

import           Chem.Molecule
import           Chem.Dietz
import           Constants (getMaxBondsSymbol)
import           Data.Char      (isSpace)
import qualified Data.Map.Strict as M
import qualified Data.Set        as S
import           Control.Monad   (foldM)

-- | Total electrons used at an atom from explicit Dietz pools.
-- Uses the Dietz pool formula: e_S(v) = s * deg_S(v) / (2*|E_S|).
usedElectronsAt :: Molecule -> AtomId -> Double
usedElectronsAt m v = system
  where
    system = sum [ ePart v bs | (_, bs) <- allSystems m ]

    ePart :: AtomId -> BondingSystem -> Double
    ePart a bs =
      let degSv = fromIntegral $ length
                    [ ()
                    | Edge x y <- S.toList (memberEdges bs)
                    , x == a || y == a ]
          s = fromIntegral (getNN (sharedElectrons bs))
          totalEdges = fromIntegral (S.size (memberEdges bs))
      in if totalEdges == 0 then 0 else s * degSv / (2 * totalEdges)

type BondMap = M.Map (AtomId, AtomId) Double
type SystemSignature = (NonNegative, [Edge], Maybe String)

standardCovalentElectrons :: S.Set Int
standardCovalentElectrons = S.fromList [2, 4, 6, 8]

reservedCovalentTags :: S.Set String
reservedCovalentTags = S.fromList ["single", "double", "triple", "quadruple"]

-- | Validate a molecule according to Dietz bonding rules.
validateMolecule :: Molecule -> Either String Molecule
validateMolecule m = do
  let atomIDsList = M.keys (atoms m)
      atomSet     = S.fromList atomIDsList

  ensureAtoms m
  ensureSystemIds (systems m)
  ensureStereochemistry m atomSet
  ensureUniqueSystems (systems m)
  let addSystem acc (_, bs) = addSystemBonds atomSet bs acc
  fullMap <- foldM addSystem M.empty =<< mapM (ensureSystemShape atomSet) (systems m)
  ensureSymmetric fullMap
  ensureValence m atomSet fullMap
  pure m

ensureAtoms :: Molecule -> Either String ()
ensureAtoms m = foldM check () (M.toList (atoms m))
  where
    check _ (aid@(AtomId n), atom)
      | n < 1 = Left "AtomId must be positive"
      | atomID atom /= aid = Left $ "Atom map key " ++ showAtomId aid ++ " does not match Atom.atomID"
      | any (not . finite) (coordinateValues (coordinate atom))
          = Left $ "Atom " ++ showAtomId aid ++ " has non-finite coordinate"
      | atomicNumber (attributes atom) <= 0
          = Left $ "Atom " ++ showAtomId aid ++ " has invalid atomic number"
      | not (finite (atomicWeight (attributes atom))) || atomicWeight (attributes atom) <= 0
          = Left $ "Atom " ++ showAtomId aid ++ " has invalid atomic weight"
      | otherwise = Right ()

    coordinateValues coord =
      [ unAngstrom (x coord)
      , unAngstrom (y coord)
      , unAngstrom (z coord)
      ]

    finite value = not (isNaN value || isInfinite value)

ensureSystemIds :: [(SystemId, BondingSystem)] -> Either String ()
ensureSystemIds entries = foldM check S.empty entries >> pure ()
  where
    check seen (sid@(SystemId n), _)
      | n < 1 = Left "SystemId must be positive"
      | sid `S.member` seen = Left $ "Duplicate SystemId " ++ show n
      | otherwise = Right (S.insert sid seen)

ensureStereochemistry :: Molecule -> S.Set AtomId -> Either String ()
ensureStereochemistry m atomSet = do
  foldM checkAtom () (atomStereoAnnotations stereo)
  foldM checkBond () (bondStereoAnnotations stereo)
  where
    stereo = smilesStereochemistry m
    checkAtom _ annotation
      | stereoCenter annotation `S.member` atomSet = Right ()
      | otherwise = Left "SMILES atom stereochemistry references non-existent atom"
    checkBond _ annotation
      | bondStereoStart annotation `S.member` atomSet
        && bondStereoEnd annotation `S.member` atomSet = Right ()
      | otherwise = Left "SMILES bond stereochemistry references non-existent atom"

ensureUniqueSystems :: [(SystemId, BondingSystem)] -> Either String ()
ensureUniqueSystems entries = foldM check S.empty entries >> pure ()
  where
    check seen (sid, bs)
      | signature `S.member` seen = Left $ "Duplicate Dietz bonding system at SystemId " ++ showSystemId sid
      | otherwise = Right (S.insert signature seen)
      where
        signature = systemSignature bs

systemSignature :: BondingSystem -> SystemSignature
systemSignature bs =
  ( sharedElectrons bs
  , S.toAscList (memberEdges bs)
  , tag bs
  )

ensureSystemShape :: S.Set AtomId -> (SystemId, BondingSystem) -> Either String (SystemId, BondingSystem)
ensureSystemShape atomSet entry@(sid, bs)
  | S.null (memberEdges bs) = Left $ "Bonding system " ++ showSystemId sid ++ " has no member edges"
  | memberAtoms bs /= derivedAtoms bs = Left $ "Bonding system " ++ showSystemId sid ++ " member atoms do not match member edges"
  | otherwise = do
      ensureSystemTagContract sid bs
      foldM checkEdge () (S.toList (memberEdges bs))
      pure entry
  where
    checkEdge _ (Edge i j)
      | i == j = Left $ "Atom " ++ showAtomId i ++ " is bonded to itself"
      | not (i `S.member` atomSet) || not (j `S.member` atomSet)
          = Left "Bond references non-existent atom"
      | otherwise = Right ()

ensureSystemTagContract :: SystemId -> BondingSystem -> Either String ()
ensureSystemTagContract sid bs
  | maybe False (all isSpace) systemTag = Left $ "Bonding system " ++ showSystemId sid ++ " has an empty tag"
  | systemTag == Just "ionic" && (electrons /= 0 || edgeCount /= 1)
      = Left "Ionic bonding systems must be one-edge systems with 0 shared electrons"
  | maybe False (`S.member` reservedCovalentTags) systemTag
      = Left "Covalent bond names are display-derived; leave the bonding-system tag unset"
  | edgeCount == 1 && electrons == 0 && systemTag /= Just "ionic"
      = Left "Zero-electron one-edge systems must be tagged ionic"
  | edgeCount == 1 && electrons `S.member` standardCovalentElectrons && systemTag /= Nothing
      = Left "Ordinary covalent one-edge systems must not carry a bonding-system tag"
  | otherwise = Right ()
  where
    systemTag = tag bs
    electrons = getNN (sharedElectrons bs)
    edgeCount = S.size (memberEdges bs)

derivedAtoms :: BondingSystem -> S.Set AtomId
derivedAtoms bs =
  S.fromList [ atom | edge <- S.toList (memberEdges bs), atom <- edgeAtoms edge ]
  where
    edgeAtoms edge = let (i, j) = atomsOfEdge edge in [i, j]

showAtomId :: AtomId -> String
showAtomId (AtomId n) = show n

showSystemId :: SystemId -> String
showSystemId (SystemId n) = show n

-- | Insert a bond contribution into the directed bond map, performing the
-- endpoint and self-bond checks mandated by the validator specification.
accumulateBond :: S.Set AtomId -> Double -> BondMap -> Edge -> Either String BondMap
accumulateBond atomSet value acc (Edge i j)
  | i == j = Left $ "Atom " ++ showAtomId i ++ " is bonded to itself"
  | not (i `S.member` atomSet) || not (j `S.member` atomSet)
      = Left "Bond references non-existent atom"
  | otherwise = Right $ addDirected i j value (addDirected j i value acc)
  where
    showAtomId (AtomId n) = show n

-- | Accumulate contributions from a Dietz bonding system by distributing the
-- shared electrons across its member edges.
addSystemBonds :: S.Set AtomId -> BondingSystem -> BondMap -> Either String BondMap
addSystemBonds atomSet bs acc
  | edgeCount == 0 = Right acc
  | otherwise      = foldM insertEdge acc (S.toList (memberEdges bs))
  where
    edgeCount = S.size (memberEdges bs)
    contribution = fromIntegral (getNN (sharedElectrons bs))
                 / fromIntegral edgeCount

    insertEdge m (Edge i j)
      | i == j = Left $ "Atom " ++ showAtomId i ++ " is bonded to itself"
      | not (i `S.member` atomSet) || not (j `S.member` atomSet)
          = Left "Bond references non-existent atom"
      | otherwise = Right $ addDirected i j contribution (addDirected j i contribution m)

    showAtomId (AtomId n) = show n

-- | Ensure that for every directed bond entry (i,j) there exists a mirrored
-- entry (j,i) with the same contribution.
ensureSymmetric :: BondMap -> Either String ()
ensureSymmetric bonds = foldM check () (M.toList bonds)
  where
    check _ ((i,j), val) =
      case M.lookup (j,i) bonds of
        Nothing   -> Left "Bond map is not symmetric"
        Just val' ->
          if approxEqual val val'
            then Right ()
            else Left "Bond map is not symmetric"

-- | Verify that each atom respects its maximum valence according to the
-- element-specific bound.
ensureValence :: Molecule -> S.Set AtomId -> BondMap -> Either String ()
ensureValence mol atomSet bonds =
  foldM check () (S.toList atomSet)
  where
    atomMap = atoms mol
    contributions i =
      [ val
      | ((a,_), val) <- M.toList bonds
      , a == i ]

    check _ aid =
      case M.lookup aid atomMap of
        Nothing -> Left "Bond references non-existent atom"
        Just atom ->
          let total    = sum (contributions aid)
              used     = total / 2.0
              maxVal   = getMaxBondsSymbol (symbol (attributes atom))
          in if used <= maxVal + 1e-9
                then Right ()
                else Left $ "Atom " ++ showAtomId aid ++ " exceeds maximum valence"

    showAtomId (AtomId n) = show n

-- | Insert a directed bond contribution, summing if an entry already exists.
addDirected :: AtomId -> AtomId -> Double -> BondMap -> BondMap
addDirected i j value = M.insertWith (+) (i, j) value

-- | Approximate equality used when comparing symmetric bond contributions.
approxEqual :: Double -> Double -> Bool
approxEqual a b = abs (a - b) <= 1e-9
