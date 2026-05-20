module Chem.BondingPerception
  ( InferredBondingSystem(..)
  , BondingPerception(..)
  , perceiveSDFBonding
  ) where

import qualified Data.Map.Strict as M
import qualified Data.Set as S
import           Data.List (sort, sortOn)

import           Chem.Dietz
import           Chem.Molecule

data InferredBondingSystem = InferredBondingSystem
  { inferredSharedElectrons :: Int
  , inferredMemberEdges :: S.Set Edge
  , inferredTag :: String
  } deriving (Eq, Show)

data BondingPerception = BondingPerception
  { perceivedSystems :: [InferredBondingSystem]
  , sigmaOverrideEdges :: S.Set Edge
  , suppressedEdges :: S.Set Edge
  } deriving (Eq, Show)

data Candidate = Candidate
  { candidateElectrons :: Int
  , candidateEdges :: S.Set Edge
  , candidateTag :: String
  , candidateOverridesSigma :: Bool
  , candidateSuppressedEdges :: S.Set Edge
  }

perceiveSDFBonding :: [Atom] -> [(Edge, Int)] -> BondingPerception
perceiveSDFBonding atomList bonds =
  let atomMap = M.fromList [(atomID atom, atom) | atom <- atomList]
      orderMap = M.fromList bonds
      adj = adjacency bonds
      aromatic =
        [ Candidate 6 ring "pi_ring" True S.empty
        | ring <- detectAromaticSixRings bonds
        ]
      oxo =
        [ Candidate 2 edges tagValue True S.empty
        | (tagValue, edges) <- detectTwoEdgeOxoResonance atomMap adj orderMap
        ]
      amide =
        [ Candidate 2 edges "inferred_amide_pi" True S.empty
        | edges <- detectAmideResonance atomMap adj orderMap
        ]
      occupiedBeforeDienes = S.unions (map candidateEdges (aromatic ++ oxo ++ amide))
      dienes =
        [ Candidate 4 edges "inferred_conjugated_diene_pi" True S.empty
        | edges <- detectConjugatedDienePaths atomMap adj orderMap
        , S.null (edges `S.intersection` occupiedBeforeDienes)
        ]
      boranes =
        [ Candidate 2 bridgeEdges ("inferred_borane_bridge_h" ++ atomIdText hydrogenId ++ "_3c2e") False suppressed
        | (hydrogenId, bridgeEdges, maybeBBEdge) <- detectBoraneBridges atomMap orderMap
        , let suppressed = maybe bridgeEdges (`S.insert` bridgeEdges) maybeBBEdge
        ]
      cps =
        [ Candidate 6 cpEdges ("inferred_cp" ++ show index ++ "_pi") False S.empty
        | (index, cpEdges) <- zip [1 :: Int ..] (detectFerroceneCpSystems atomMap adj orderMap)
        ]
      candidates = dedupeCandidates (aromatic ++ oxo ++ amide ++ dienes ++ boranes ++ cps)
      systems =
        [ InferredBondingSystem (candidateElectrons candidate) (candidateEdges candidate) (candidateTag candidate)
        | candidate <- candidates
        ]
      overrides =
        S.unions [ candidateEdges candidate | candidate <- candidates, candidateOverridesSigma candidate ]
      suppressed = S.unions (map candidateSuppressedEdges candidates)
  in BondingPerception systems overrides suppressed

atomIdText :: AtomId -> String
atomIdText (AtomId value) = show value

adjacency :: [(Edge, Int)] -> M.Map AtomId [(AtomId, Int)]
adjacency bonds = M.unionWith (++) left right
  where
    left = M.fromListWith (++) [ (a, [(b, orderValue)]) | (Edge a b, orderValue) <- bonds ]
    right = M.fromListWith (++) [ (b, [(a, orderValue)]) | (Edge a b, orderValue) <- bonds ]

symbolOf :: Atom -> AtomicSymbol
symbolOf = symbol . attributes

edgeKey :: Edge -> (Integer, Integer)
edgeKey (Edge (AtomId left) (AtomId right)) = (left, right)

edgeSetKey :: S.Set Edge -> [(Integer, Integer)]
edgeSetKey = sort . map edgeKey . S.toList

dedupeCandidates :: [Candidate] -> [Candidate]
dedupeCandidates = go S.empty []
  where
    go _ acc [] = reverse acc
    go seen acc (candidate : rest)
      | key `S.member` seen = go seen acc rest
      | otherwise = go (S.insert key seen) (candidate : acc) rest
      where
        key = (edgeSetKey (candidateEdges candidate), candidateTag candidate)

detectAromaticSixRings :: [(Edge, Int)] -> [S.Set Edge]
detectAromaticSixRings bonds = sortOn edgeSetKey . S.toList . S.fromList $ concatMap findFrom (M.keys adj)
  where
    adj = adjacency bonds

    findFrom start = searchAlternating [start] start Nothing ++ searchAromatic [start] start
      where
        neighbors value = M.findWithDefault [] value adj

        alternate 1 = 2
        alternate 2 = 1
        alternate _ = 0

        searchAlternating path current previousOrder
          | length path == 6 =
              case previousOrder of
                Just previous ->
                  case lookup start (neighbors current) of
                    Just orderValue | orderValue == alternate previous ->
                      let atomsInCycle = path ++ [start]
                          edges = zipWith mkEdge atomsInCycle (tail atomsInCycle)
                      in if start == minimum path then [S.fromList edges] else []
                    _ -> []
                Nothing -> []
          | otherwise =
              concat
                [ searchAlternating (path ++ [neighbor]) neighbor (Just orderValue)
                | (neighbor, orderValue) <- neighbors current
                , orderValue `elem` [1, 2]
                , maybe True ((== orderValue) . alternate) previousOrder
                , neighbor `notElem` path
                ]

        searchAromatic path current
          | length path == 6 =
              case lookup start (neighbors current) of
                Just 4 ->
                  let atomsInCycle = path ++ [start]
                      edges = zipWith mkEdge atomsInCycle (tail atomsInCycle)
                  in if start == minimum path then [S.fromList edges] else []
                _ -> []
          | otherwise =
              concat
                [ searchAromatic (path ++ [neighbor]) neighbor
                | (neighbor, orderValue) <- neighbors current
                , orderValue == 4
                , neighbor `notElem` path
                ]

detectTwoEdgeOxoResonance ::
  M.Map AtomId Atom ->
  M.Map AtomId [(AtomId, Int)] ->
  M.Map Edge Int ->
  [(String, S.Set Edge)]
detectTwoEdgeOxoResonance atomMap adj orderMap =
  sortOn (\(label, edges) -> (label, edgeSetKey edges))
    [ (tagFor centerSymbol, S.fromList [leftEdge, rightEdge])
    | (centerId, centerAtom) <- M.toAscList atomMap
    , let centerSymbol = symbolOf centerAtom
    , centerSymbol `elem` [C, N, P, S]
    , (leftEdge, leftOrder) : rest <- [oxygenEdges centerId]
    , (rightEdge, rightOrder) <- rest
    , let orders = sort [leftOrder, rightOrder]
    , head orders <= 1
    , last orders >= 2
    ]
  where
    oxygenEdges centerId =
      [ (edge, M.findWithDefault orderValue edge orderMap)
      | (neighbor, orderValue) <- M.findWithDefault [] centerId adj
      , Just neighborAtom <- [M.lookup neighbor atomMap]
      , symbolOf neighborAtom == O
      , let edge = mkEdge centerId neighbor
      ]

    tagFor C = "inferred_carboxylate_pi"
    tagFor N = "inferred_nitro_pi"
    tagFor _ = "inferred_oxoanion_pi"

detectAmideResonance ::
  M.Map AtomId Atom ->
  M.Map AtomId [(AtomId, Int)] ->
  M.Map Edge Int ->
  [S.Set Edge]
detectAmideResonance atomMap adj orderMap =
  sortOn edgeSetKey . S.toList . S.fromList $
    [ S.fromList [oxygenEdge, nitrogenEdge]
    | (centerId, centerAtom) <- M.toAscList atomMap
    , symbolOf centerAtom == C
    , oxygenEdge <- oxygenEdges centerId
    , nitrogenEdge <- nitrogenEdges centerId
    ]
  where
    oxygenEdges centerId =
      [ edge
      | (neighbor, _) <- M.findWithDefault [] centerId adj
      , Just neighborAtom <- [M.lookup neighbor atomMap]
      , symbolOf neighborAtom == O
      , let edge = mkEdge centerId neighbor
      , M.findWithDefault 1 edge orderMap >= 2
      ]
    nitrogenEdges centerId =
      [ edge
      | (neighbor, _) <- M.findWithDefault [] centerId adj
      , Just neighborAtom <- [M.lookup neighbor atomMap]
      , symbolOf neighborAtom == N
      , let edge = mkEdge centerId neighbor
      , M.findWithDefault 1 edge orderMap == 1
      ]

detectConjugatedDienePaths ::
  M.Map AtomId Atom ->
  M.Map AtomId [(AtomId, Int)] ->
  M.Map Edge Int ->
  [S.Set Edge]
detectConjugatedDienePaths atomMap adj orderMap =
  sortOn edgeSetKey . S.toList . S.fromList $ concatMap (\start -> search [start] start) (M.keys atomMap)
  where
    allowed = S.fromList [C, N, O, S, P]
    search path current
      | length path == 4 =
          if all atomAllowed path && map edgeOrder pathEdges == [2, 1, 2]
            then [S.fromList pathEdges]
            else []
      | otherwise =
          concat
            [ search (path ++ [neighbor]) neighbor
            | (neighbor, _) <- M.findWithDefault [] current adj
            , neighbor `notElem` path
            ]
      where
        pathEdges = zipWith mkEdge path (tail path)
        edgeOrder edge = M.findWithDefault 1 edge orderMap
    atomAllowed atomId =
      maybe False ((`S.member` allowed) . symbolOf) (M.lookup atomId atomMap)

detectBoraneBridges ::
  M.Map AtomId Atom ->
  M.Map Edge Int ->
  [(AtomId, S.Set Edge, Maybe Edge)]
detectBoraneBridges atomMap orderMap =
  sortOn (\(hydrogenId, _, _) -> hydrogenId)
    [ (hydrogenId, S.fromList [mkEdge leftId hydrogenId, mkEdge rightId hydrogenId], maybeBBEdge)
    | (leftId, rightId) <- pairs boronIds
    , Just leftAtom <- [M.lookup leftId atomMap]
    , Just rightAtom <- [M.lookup rightId atomMap]
    , let bbEdge = mkEdge leftId rightId
    , bbEdge `M.member` orderMap || atomDistance leftAtom rightAtom <= 2.05
    , hydrogenId <- hydrogenIds
    , Just hydrogenAtom <- [M.lookup hydrogenId atomMap]
    , atomDistance leftAtom hydrogenAtom <= 1.45
    , atomDistance rightAtom hydrogenAtom <= 1.45
    , let maybeBBEdge = if bbEdge `M.member` orderMap then Just bbEdge else Nothing
    ]
  where
    boronIds = [ atomId | (atomId, atom) <- M.toAscList atomMap, symbolOf atom == B ]
    hydrogenIds = [ atomId | (atomId, atom) <- M.toAscList atomMap, symbolOf atom == H ]

detectFerroceneCpSystems ::
  M.Map AtomId Atom ->
  M.Map AtomId [(AtomId, Int)] ->
  M.Map Edge Int ->
  [S.Set Edge]
detectFerroceneCpSystems atomMap adj orderMap =
  sortOn edgeSetKey
    [ S.fromList (ringEdges ++ ironEdges)
    | ironId <- ironIds
    , Just ironAtom <- [M.lookup ironId atomMap]
    , cycle <- carbonFiveCycles atomMap adj
    , all ((<= 2.45) . atomDistance ironAtom . (atomMap M.!)) cycle
    , let ringEdges = zipWith mkEdge cycle (tail cycle ++ [head cycle])
    , all (\edge -> M.findWithDefault 1 edge orderMap <= 2) ringEdges
    , let ironEdges = map (mkEdge ironId) cycle
    ]
  where
    ironIds = [ atomId | (atomId, atom) <- M.toAscList atomMap, symbolOf atom == Fe ]

carbonFiveCycles :: M.Map AtomId Atom -> M.Map AtomId [(AtomId, Int)] -> [[AtomId]]
carbonFiveCycles atomMap adj =
  sort . S.toList . S.fromList $ concatMap (\start -> search start start [start]) (M.keys atomMap)
  where
    search start current path
      | length path == 5 =
          if any ((== start) . fst) (M.findWithDefault [] current adj)
            && all isCarbon path
            then [canonicalCycle path]
            else []
      | otherwise =
          concat
            [ search start neighbor (path ++ [neighbor])
            | (neighbor, _) <- M.findWithDefault [] current adj
            , neighbor `notElem` path
            ]
    isCarbon atomId = maybe False ((== C) . symbolOf) (M.lookup atomId atomMap)

canonicalCycle :: Ord a => [a] -> [a]
canonicalCycle values =
  minimum (rotations values ++ rotations (reverse values))

rotations :: [a] -> [[a]]
rotations values =
  take (length values) (iterate rotate values)
  where
    rotate [] = []
    rotate (x:xs) = xs ++ [x]

pairs :: [a] -> [(a, a)]
pairs [] = []
pairs (x:xs) = [(x, y) | y <- xs] ++ pairs xs

atomDistance :: Atom -> Atom -> Double
atomDistance left right =
  let Coordinate x1 y1 z1 = coordinate left
      Coordinate x2 y2 z2 = coordinate right
      dx = unAngstrom x1 - unAngstrom x2
      dy = unAngstrom y1 - unAngstrom y2
      dz = unAngstrom z1 - unAngstrom z2
  in sqrt (dx * dx + dy * dy + dz * dz)
