{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module FreeSolvWLBondingGP
  ( FreeSolvWLBondingConfig(..)
  , FreeSolvWLBondingResult(..)
  , defaultFreeSolvWLBondingConfig
  , runFreeSolvWLBondingGP
  , runFreeSolvWLBondingGPSplits
  , writeFreeSolvWLBondingFeatureDoc
  , printFreeSolvWLBondingResult
  , printFreeSolvWLBondingSummary
  ) where

import           Chem.Dietz
import           Chem.IO.SDF (readSDF)
import           Chem.Molecule
import           Control.Monad (forM, unless)
import           Data.Aeson (FromJSON(..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Lazy as BL
import           Data.Char (isSpace)
import           Data.List (foldl', intercalate, sort, sortOn)
import qualified Data.Map.Strict as M
import           Data.Maybe (fromMaybe)
import qualified Data.Set as S
import           GHC.Generics (Generic)
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as U
import qualified GaussianProcess as GP
import qualified Orbital as Orb
import           System.Directory (createDirectoryIfMissing, doesFileExist)
import           System.FilePath (takeDirectory, (</>))
import           System.Random (StdGen, mkStdGen, randomR)
import           System.IO (Handle, IOMode(WriteMode), hPutStrLn, withFile)
import           Text.Printf (printf)
import           Text.Read (readMaybe)

data FreeSolvWLBondingConfig = FreeSolvWLBondingConfig
  { wlProcessedDir :: !FilePath
  , wlRawSdfDir    :: !FilePath
  , wlSeed         :: !Int
  , wlSplitJson    :: !(Maybe FilePath)
  , wlOutputCsv    :: !(Maybe FilePath)
  , wlAllSplits    :: !Bool
  } deriving (Eq, Show)

defaultFreeSolvWLBondingConfig :: FilePath -> FreeSolvWLBondingConfig
defaultFreeSolvWLBondingConfig processedDir =
  FreeSolvWLBondingConfig
    { wlProcessedDir = processedDir
    , wlRawSdfDir = "../MolADT-Bayes-Python/data/raw/freesolv/sdffiles"
    , wlSeed = 18
    , wlSplitJson = Just "data/freesolv_wl_system_seed18_split.json"
    , wlOutputCsv = Nothing
    , wlAllSplits = False
    }

data FreeSolvWLBondingResult = FreeSolvWLBondingResult
  { resultSeed        :: !Int
  , resultTrainCount  :: !Int
  , resultTestCount   :: !Int
  , resultRmse        :: !Double
  , resultMae         :: !Double
  , resultR2          :: !Double
  , resultCoverage90  :: !Double
  , resultMeanSd      :: !Double
  , resultSplitSource :: !String
  } deriving (Eq, Show)

data FreeSolvRow = FreeSolvRow
  { rowMolId  :: !String
  , rowTarget :: !Double
  } deriving (Eq, Show)

data Observation = Observation
  { observationMolId  :: !String
  , observationTarget :: !Double
  , observationMol    :: !Molecule
  } deriving (Eq, Show)

data TokenViews = TokenViews
  { wlTokens     :: !(M.Map String Double)
  , systemTokens :: !(M.Map String Double)
  } deriving (Eq, Show)

data PreparedFreeSolv = PreparedFreeSolv
  { preparedObservations :: !(V.Vector Observation)
  , preparedViews        :: !(V.Vector TokenViews)
  , preparedKernel       :: !(U.Vector Double)
  , preparedIndexById    :: !(M.Map String Int)
  } deriving (Eq, Show)

data ResolvedSplit = ResolvedSplit
  { resolvedSeed        :: !Int
  , resolvedTrainIdxs   :: ![Int]
  , resolvedTestIdxs    :: ![Int]
  , resolvedSplitSource :: !String
  } deriving (Eq, Show)

data SplitRecord = SplitRecord
  { splitSeed        :: !Int
  , splitTrainMolIds :: ![String]
  , splitValidMolIds :: ![String]
  , splitTestMolIds  :: ![String]
  } deriving (Eq, Show, Generic)

instance FromJSON SplitRecord where
  parseJSON = withObject "SplitRecord" $ \obj ->
    SplitRecord
      <$> obj .: "seed"
      <*> obj .: "train_mol_ids"
      <*> obj .: "valid_mol_ids"
      <*> obj .: "test_mol_ids"

-- Empirical-Bayes hyperparameters from the Python seed-18 MolADT
-- WL + bonding-system GP artifact.
wlSystemKernelWeight :: Double
wlSystemKernelWeight = 0.00033546262790251185

systemKernelWeight :: Double
systemKernelWeight = 4.232146253796119

wlKernelWeight :: Double
wlKernelWeight = 0.23803398404993845

noiseVariance :: Double
noiseVariance = 0.002070630985235373

kernelJitter :: Double
kernelJitter = 1.0e-8

minimumVariance :: Double
minimumVariance = 1.0e-9

trainValidCount :: Int
trainValidCount = 577

runFreeSolvWLBondingGP :: FreeSolvWLBondingConfig -> IO FreeSolvWLBondingResult
runFreeSolvWLBondingGP config = do
  results <- runFreeSolvWLBondingGPSplits config { wlAllSplits = False }
  case results of
    result : _ -> pure result
    [] -> fail "MolADT WL+bonding GP produced no split results"

runFreeSolvWLBondingGPSplits :: FreeSolvWLBondingConfig -> IO [FreeSolvWLBondingResult]
runFreeSolvWLBondingGPSplits config = do
  prepared <- loadPreparedFreeSolv config
  splits <- resolveSplits config prepared
  results <- mapM (evaluateSplit prepared) splits
  maybe (pure ()) (`writeResultsCsv` results) (wlOutputCsv config)
  pure results

writeFreeSolvWLBondingFeatureDoc :: FreeSolvWLBondingConfig -> FilePath -> IO ()
writeFreeSolvWLBondingFeatureDoc config outputPath = do
  views <- loadFreeSolvTokenViews config
  let rows = featureRows views
      familyCounts =
        M.toAscList $
          M.fromListWith (+)
            [ ((groupName, familyName), 1 :: Int)
            | (_, groupName, familyName, _) <- rows
            ]
      wlCount = length [() | (_, "wl_graph", _, _) <- rows]
      systemCount = length [() | (_, "bonding_system", _, _) <- rows]
  createDirectoryIfMissing True (takeDirectory outputPath)
  withFile outputPath WriteMode $ \handle -> do
    hPutStrLn handle "# FreeSolv GP Feature List"
    hPutStrLn handle ""
    hPutStrLn handle "This is the literal feature vocabulary used by the Haskell `freesolv-wl-system-gp` command on the current FreeSolv data export. The GP does not use SMILES, RDKit fingerprints, or 3D geometry in this feature map. Each line below is a sparse count feature name."
    hPutStrLn handle ""
    hPutStrLn handle "## Counts"
    hPutStrLn handle ""
    hPutStrLn handle ("- total features: `" ++ show (length rows) ++ "`")
    hPutStrLn handle ("- WL graph-token features: `" ++ show wlCount ++ "`")
    hPutStrLn handle ("- bonding-system token features: `" ++ show systemCount ++ "`")
    hPutStrLn handle ""
    hPutStrLn handle "## Feature Families"
    hPutStrLn handle ""
    mapM_
      (\((groupName, familyName), count) ->
         hPutStrLn handle $
           "- `" ++ groupName ++ "` / `" ++ familyName ++ "`: `" ++ show count ++ "`"
      )
      familyCounts
    hPutStrLn handle ""
    hPutStrLn handle "## What The Names Mean"
    hPutStrLn handle ""
    hPutStrLn handle "- `wl_graph / edge_label`: one count for each typed edge label seen in FreeSolv. These encode element pair, effective bond-order bucket, bonding-system overlap count, shared-electron count, member-edge count, and bonding-system kind."
    hPutStrLn handle "- `wl_graph / wl0`: atom-label counts before WL propagation. These encode element, formal charge bucket, shell count, orbital count, total shell electrons, and orbital occupancy signature."
    hPutStrLn handle "- `wl_graph / wl1` through `wl_graph / wl4`: Weisfeiler-Lehman neighbourhood labels after one to four rounds of neighbourhood aggregation. These are long because each token contains the sorted labelled neighbourhood around an atom."
    hPutStrLn handle "- `bonding_system / atom`: atom element plus formal-charge count tokens."
    hPutStrLn handle "- `bonding_system / atom_shell`: atom element plus shell/orbital occupancy count tokens."
    hPutStrLn handle "- `bonding_system / edge`: edge element pair plus effective order count tokens."
    hPutStrLn handle "- `bonding_system / edge_overlap`: edge element pair, effective order, and number of bonding systems sharing the edge."
    hPutStrLn handle "- `bonding_system / edge_charge`: edge element pair, endpoint formal charges, and effective order."
    hPutStrLn handle "- `bonding_system / edge_in_system`: edge element pair, effective order, shared electrons, member-edge count, and bonding-system kind for each system using that edge."
    hPutStrLn handle "- `bonding_system / system`: whole bonding-system summary by shared electrons, member atom count, member edge count, and kind."
    hPutStrLn handle "- `bonding_system / system_atoms`: whole bonding-system summary including member atom symbols."
    hPutStrLn handle "- `bonding_system / system_edges`: whole bonding-system summary including member edge element pairs."
    hPutStrLn handle ""
    hPutStrLn handle "## Full List"
    writeFeatureRows handle rows Nothing

featureRows :: V.Vector TokenViews -> [(Int, String, String, String)]
featureRows viewVector =
  zipWith rowFor [0 ..] (wlNames ++ systemNames)
  where
    views = V.toList viewVector
    wlNames =
      [ ("wl_graph", name)
      | name <- S.toAscList (S.unions (map (M.keysSet . wlTokens) views))
      ]
    systemNames =
      [ ("bonding_system", name)
      | name <- S.toAscList (S.unions (map (M.keysSet . systemTokens) views))
      ]
    rowFor index (groupName, name) =
      (index, groupName, featureFamily name, name)

featureFamily :: String -> String
featureFamily = takeWhile (/= ':')

writeFeatureRows :: Handle -> [(Int, String, String, String)] -> Maybe (String, String) -> IO ()
writeFeatureRows _ [] _ = pure ()
writeFeatureRows handle ((index, groupName, familyName, name) : rest) currentSection = do
  let section = Just (groupName, familyName)
  unless (section == currentSection) $ do
    hPutStrLn handle ""
    hPutStrLn handle ("### " ++ groupName ++ " / " ++ familyName)
    hPutStrLn handle ""
  hPutStrLn handle (show index ++ ". `" ++ name ++ "`")
  writeFeatureRows handle rest section

loadFreeSolvTokenViews :: FreeSolvWLBondingConfig -> IO (V.Vector TokenViews)
loadFreeSolvTokenViews config = do
  rows <- loadFreeSolvRows (wlProcessedDir config </> "freesolv_moladt_featurized_features.csv")
  views <- forM rows $ \row -> do
    molecule <- loadFreeSolvMolecule config row
    pure (tokenViews molecule)
  pure (V.fromList views)

loadPreparedFreeSolv :: FreeSolvWLBondingConfig -> IO PreparedFreeSolv
loadPreparedFreeSolv config = do
  rows <- loadFreeSolvRows (wlProcessedDir config </> "freesolv_moladt_featurized_features.csv")
  observations <- forM rows $ \row -> do
    molecule <- loadFreeSolvMolecule config row
    pure Observation
      { observationMolId = rowMolId row
      , observationTarget = rowTarget row
      , observationMol = molecule
      }
  let observationVector = V.fromList observations
      viewVector = V.map (tokenViews . observationMol) observationVector
      fullKernel = fullKernelMatrix viewVector
      byId =
        M.fromList
          [ (observationMolId obs, index)
          | (index, obs) <- zip [0 ..] observations
          ]
  pure PreparedFreeSolv
    { preparedObservations = observationVector
    , preparedViews = viewVector
    , preparedKernel = fullKernel
    , preparedIndexById = byId
    }

loadFreeSolvMolecule :: FreeSolvWLBondingConfig -> FreeSolvRow -> IO Molecule
loadFreeSolvMolecule config row = do
  let sdfPath = wlRawSdfDir config </> rowMolId row ++ ".sdf"
  exists <- doesFileExist sdfPath
  unless exists $
    fail ("Missing FreeSolv SDF for " ++ rowMolId row ++ ": " ++ sdfPath)
  parsed <- readSDF sdfPath
  case parsed of
    Left err -> fail ("Could not parse " ++ sdfPath ++ ": " ++ show err)
    Right molecule -> pure molecule

evaluateSplit :: PreparedFreeSolv -> ResolvedSplit -> IO FreeSolvWLBondingResult
evaluateSplit prepared splitInfo = do
  let trainIdxs = resolvedTrainIdxs splitInfo
      testIdxs = resolvedTestIdxs splitInfo
      observations = preparedObservations prepared
      fullKernel = preparedKernel prepared
      fullSize = V.length observations
      trainTargets =
        [ observationTarget (observations V.! index)
        | index <- trainIdxs
        ]
      (targetMean, targetScale) = meanAndScale trainTargets
      centeredTargets =
        [ (target - targetMean) / targetScale
        | target <- trainTargets
        ]
      kernel = trainKernelFromFull fullKernel fullSize trainIdxs
  cholesky <-
    case GP.choleskyDecompose (length trainIdxs) kernel of
      Nothing -> fail "MolADT WL+bonding GP covariance was not positive definite"
      Just chol -> pure chol
  let alpha =
        GP.solveSymmetricPositiveDefinite
          (length trainIdxs)
          cholesky
          (U.fromList centeredTargets)
      predictions =
        [ predictOneFromFull fullKernel fullSize trainIdxs cholesky alpha targetMean targetScale testIndex
        | testIndex <- testIdxs
        ]
      actual =
        [ observationTarget (observations V.! index)
        | index <- testIdxs
        ]
      metrics = summarizePredictions actual predictions
      result =
        FreeSolvWLBondingResult
          { resultSeed = resolvedSeed splitInfo
          , resultTrainCount = length trainIdxs
          , resultTestCount = length testIdxs
          , resultRmse = metricRmse metrics
          , resultMae = metricMae metrics
          , resultR2 = metricR2 metrics
          , resultCoverage90 = metricCoverage90 metrics
          , resultMeanSd = metricMeanSd metrics
          , resultSplitSource = resolvedSplitSource splitInfo
          }
  pure result

loadFreeSolvRows :: FilePath -> IO [FreeSolvRow]
loadFreeSolvRows path = do
  content <- readFile path
  case filter (not . null) (lines content) of
    [] -> fail ("Empty FreeSolv feature table: " ++ path)
    _header : rowLines ->
      pure . sortOn rowMolId $
        [ FreeSolvRow molId target
        | line <- rowLines
        , let cols = splitComma line
        , length cols >= 3
        , let molId = cols !! 0
        , Just target <- [readMaybe (cols !! 2)]
        ]

resolveSplits :: FreeSolvWLBondingConfig -> PreparedFreeSolv -> IO [ResolvedSplit]
resolveSplits config prepared =
  case wlSplitJson config of
    Just path -> do
      payload <- BL.readFile path
      records <- case eitherDecode payload of
        Left err -> fail ("Could not parse split JSON " ++ path ++ ": " ++ err)
        Right value -> pure value
      let selectedRecords =
            if wlAllSplits config
              then records
              else [record | record <- records, splitSeed record == wlSeed config]
      case selectedRecords of
        [] -> fail ("No split with seed " ++ show (wlSeed config) ++ " found in " ++ path)
        _ ->
          mapM
            (\record ->
               let trainIds = splitTrainMolIds record ++ splitValidMolIds record
                   testIds = splitTestMolIds record
               in ResolvedSplit (splitSeed record)
                    <$> lookupIndices (preparedIndexById prepared) trainIds
                    <*> lookupIndices (preparedIndexById prepared) testIds
                    <*> pure ("split-json:" ++ path)
            )
            selectedRecords
    Nothing ->
      let observationCount = V.length (preparedObservations prepared)
          shuffled = shuffleWithSeed (wlSeed config) [0 .. observationCount - 1]
          trainObs = take trainValidCount shuffled
          testObs = drop trainValidCount shuffled
      in pure
           [ ResolvedSplit
               { resolvedSeed = wlSeed config
               , resolvedTrainIdxs = trainObs
               , resolvedTestIdxs = testObs
               , resolvedSplitSource = "haskell-deterministic-shuffle"
               }
           ]

lookupIndices :: M.Map String Int -> [String] -> IO [Int]
lookupIndices byId ids =
  forM ids $ \molId ->
    case M.lookup molId byId of
      Just index -> pure index
      Nothing -> fail ("Split references unknown FreeSolv molecule id: " ++ molId)

shuffleWithSeed :: Int -> [a] -> [a]
shuffleWithSeed seed = go (mkStdGen seed)
  where
    go _ [] = []
    go gen xs =
      let (index, gen') = randomR (0, length xs - 1) gen
          (prefix, picked : suffix) = splitAt index xs
      in picked : go gen' (prefix ++ suffix)

tokenViews :: Molecule -> TokenViews
tokenViews molecule =
  TokenViews
    { wlTokens = wlTokenCounts molecule
    , systemTokens = systemTokenCounts molecule
    }

wlTokenCounts :: Molecule -> M.Map String Double
wlTokenCounts molecule =
  let initialLabels =
        M.fromList
          [ (atomId, atomLabel atom)
          | (atomId, atom) <- M.toAscList (atoms molecule)
          ]
      adjacency = adjacencyLabels molecule
      edgeCounts =
        M.fromListWith (+)
          [ ("edge_label:" ++ label, 1.0)
          | (_, neighbors) <- M.toList adjacency
          , (_, label) <- neighbors
          ]
      wlCounts = iterateLabels 4 adjacency initialLabels
  in M.unionWith (+) edgeCounts wlCounts

iterateLabels :: Int -> M.Map AtomId [(AtomId, String)] -> M.Map AtomId String -> M.Map String Double
iterateLabels maxRadius adjacency initialLabels =
  go 0 initialLabels M.empty
  where
    go radius labels counts =
      let counts' =
            foldl'
              (\acc label -> M.insertWith (+) ("wl" ++ show radius ++ ":" ++ label) 1.0 acc)
              counts
              (M.elems labels)
      in if radius >= maxRadius
           then counts'
           else
             let labels' =
                   M.mapWithKey
                     (\atomId label ->
                        let neighborhood =
                              sort
                                [ edgeLabelText ++ "->" ++ fromMaybe "" (M.lookup neighbor labels)
                                | (neighbor, edgeLabelText) <- M.findWithDefault [] atomId adjacency
                                ]
                        in label ++ "|" ++ intercalate ";" neighborhood
                     )
                     labels
             in go (radius + 1) labels' counts'

adjacencyLabels :: Molecule -> M.Map AtomId [(AtomId, String)]
adjacencyLabels molecule =
  M.fromListWith (++)
    [ entry
    | edge <- S.toList (moleculeEdges molecule)
    , let (left, right) = atomsOfEdge edge
          labelText = edgeLabel molecule edge
    , entry <- [(left, [(right, labelText)]), (right, [(left, labelText)])]
    ]

systemTokenCounts :: Molecule -> M.Map String Double
systemTokenCounts molecule =
  M.unionsWith (+)
    [ atomTokens
    , edgeTokens
    , bondingSystemTokens
    ]
  where
    systemList = allSystems molecule
    atomTokens =
      M.fromListWith (+) $
        concat
          [ [ ("atom:" ++ show (symbol (attributes atom)) ++ ":" ++ chargeBucket (formalCharge atom), 1.0)
            , ("atom_shell:" ++ atomLabel atom, 1.0)
            ]
          | atom <- M.elems (atoms molecule)
          ]
    edgeTokens =
      M.fromListWith (+) $
        concat
          [ let containing = [system | (_, system) <- systemList, edge `S.member` memberEdges system]
                chargeText =
                  case atomsOfEdge edge of
                    (leftId, rightId) ->
                      let leftCharge = maybe 0 formalCharge (M.lookup leftId (atoms molecule))
                          rightCharge = maybe 0 formalCharge (M.lookup rightId (atoms molecule))
                      in intercalate ":" (sort [show leftCharge, show rightCharge])
                baseLabel = edgeSymbolPair molecule edge ++ ":" ++ orderBucket (effectiveOrder molecule edge)
            in [ ("edge:" ++ baseLabel, 1.0)
               , ("edge_overlap:" ++ baseLabel ++ ":" ++ show (length containing), 1.0)
               , ("edge_charge:" ++ baseLabel ++ ":" ++ chargeText, 1.0)
               ]
               ++ [ ( "edge_in_system:"
                      ++ baseLabel
                      ++ ":"
                      ++ show (getNN (sharedElectrons system))
                      ++ ":"
                      ++ show (S.size (memberEdges system))
                      ++ ":"
                      ++ systemKind system
                    , 1.0
                    )
                  | system <- containing
                  ]
          | edge <- S.toList (moleculeEdges molecule)
          ]
    bondingSystemTokens =
      M.fromListWith (+) $
        concat
          [ let atomSymbols =
                  intercalate "." . sort $
                    [ show (symbol (attributes atom))
                    | atomId <- S.toList (memberAtoms system)
                    , Just atom <- [M.lookup atomId (atoms molecule)]
                    ]
                edgePairs =
                  intercalate "." . sort $
                    [ edgeSymbolPair molecule edge
                    | edge <- S.toList (memberEdges system)
                    ]
                shared = show (getNN (sharedElectrons system))
                kindText = systemKind system
                atomCount = show (S.size (memberAtoms system))
                edgeCount = show (S.size (memberEdges system))
            in [ ("system:" ++ shared ++ ":" ++ atomCount ++ ":" ++ edgeCount ++ ":" ++ kindText, 1.0)
               , ("system_atoms:" ++ shared ++ ":" ++ edgeCount ++ ":" ++ kindText ++ ":" ++ atomSymbols, 1.0)
               , ("system_edges:" ++ shared ++ ":" ++ atomCount ++ ":" ++ kindText ++ ":" ++ edgePairs, 1.0)
               ]
          | (_, system) <- systemList
          ]

atomLabel :: Atom -> String
atomLabel atom =
  let (shellCount, orbitalCount, electronCount, shellSignature) = shellStats atom
  in show (symbol (attributes atom))
      ++ ":"
      ++ chargeBucket (formalCharge atom)
      ++ ":sh"
      ++ show shellCount
      ++ ":orb"
      ++ show orbitalCount
      ++ ":e"
      ++ show electronCount
      ++ ":"
      ++ shellSignature

shellStats :: Atom -> (Int, Int, Int, String)
shellStats atom =
  case shells atom of
    Nothing -> (0, 0, 0, "")
    Just shellList ->
      let parts = concatMap shellParts shellList
          shellCount = length shellList
          orbitalCount = sum [count | (_, count, _) <- parts]
          electronCount = sum [electrons | (_, _, electrons) <- parts]
          signature = intercalate "." [text | (text, _, _) <- parts]
      in (shellCount, orbitalCount, electronCount, signature)

shellParts :: Orb.Shell -> [(String, Int, Int)]
shellParts shell =
  concat
    [ maybe [] (subshellPart "s") (Orb.sSubShell shell)
    , maybe [] (subshellPart "p") (Orb.pSubShell shell)
    , maybe [] (subshellPart "d") (Orb.dSubShell shell)
    , maybe [] (subshellPart "f") (Orb.fSubShell shell)
    ]
  where
    subshellPart label subshell =
      let counts = map Orb.electronCount (Orb.orbitals subshell)
          text =
            show (Orb.principalQuantumNumber shell)
              ++ label
              ++ concatMap show counts
      in [(text, length counts, sum counts)]

chargeBucket :: Int -> String
chargeBucket charge
  | charge <= -3 = "neg3plus"
  | charge < 0 = "neg" ++ show (abs charge)
  | charge == 0 = "neutral"
  | charge >= 3 = "pos3plus"
  | otherwise = "pos" ++ show charge

edgeLabel :: Molecule -> Edge -> String
edgeLabel molecule edge =
  let containing = [system | (_, system) <- allSystems molecule, edge `S.member` memberEdges system]
      systemBits =
        intercalate "." . sort $
          [ show (getNN (sharedElectrons system))
              ++ "e:"
              ++ show (S.size (memberEdges system))
              ++ "m:"
              ++ systemKind system
          | system <- containing
          ]
  in edgeSymbolPair molecule edge
      ++ ":"
      ++ orderBucket (effectiveOrder molecule edge)
      ++ ":overlap"
      ++ show (length containing)
      ++ ":"
      ++ systemBits

edgeSymbolPair :: Molecule -> Edge -> String
edgeSymbolPair molecule edge =
  case atomsOfEdge edge of
    (leftId, rightId) ->
      let labels =
            sort
              [ maybe "?" (show . symbol . attributes) (M.lookup leftId (atoms molecule))
              , maybe "?" (show . symbol . attributes) (M.lookup rightId (atoms molecule))
              ]
      in intercalate "-" labels

orderBucket :: Double -> String
orderBucket order
  | order <= 0.25 = "ionic_zero"
  | order < 1.25 = "single"
  | order < 1.80 = "delocalised_1p5"
  | order < 2.50 = "double"
  | order < 3.50 = "triple"
  | otherwise = "quadruple_plus"

systemKind :: BondingSystem -> String
systemKind system =
  case tag system of
    Just label -> label
    Nothing
      | S.size (memberEdges system) == 1 && getNN (sharedElectrons system) == 2 -> "single_covalent"
      | S.size (memberEdges system) == 1 && getNN (sharedElectrons system) == 4 -> "double_covalent"
      | S.size (memberEdges system) == 1 && getNN (sharedElectrons system) == 6 -> "triple_covalent"
      | S.size (memberEdges system) == 1 && getNN (sharedElectrons system) == 8 -> "quadruple_covalent"
      | getNN (sharedElectrons system) == 0 -> "zero_electron"
      | S.size (memberEdges system) > 1 -> "delocalised_bonding"
      | otherwise -> "other_bonding"

fullKernelMatrix :: V.Vector TokenViews -> U.Vector Double
fullKernelMatrix views =
  U.generate (n * n) $ \flatIndex ->
    let (row, col) = flatIndex `divMod` n
    in kernelValue (views V.! row) (views V.! col)
  where
    n = V.length views

trainKernelFromFull :: U.Vector Double -> Int -> [Int] -> U.Vector Double
trainKernelFromFull fullKernel fullSize trainIdxs =
  U.generate (n * n) $ \flatIndex ->
    let (row, col) = flatIndex `divMod` n
        value = kernelAt fullKernel fullSize (trainIdxs !! row) (trainIdxs !! col)
    in if row == col then value + noiseVariance + kernelJitter else value
  where
    n = length trainIdxs

kernelAt :: U.Vector Double -> Int -> Int -> Int -> Double
kernelAt fullKernel fullSize row col = fullKernel U.! (row * fullSize + col)

kernelValue :: TokenViews -> TokenViews -> Double
kernelValue left right =
  wlSystemKernelWeight * tanimoto (combinedTokens left) (combinedTokens right)
    + systemKernelWeight * tanimoto (systemTokens left) (systemTokens right)
    + wlKernelWeight * tanimoto (wlTokens left) (wlTokens right)

combinedTokens :: TokenViews -> M.Map String Double
combinedTokens TokenViews { wlTokens, systemTokens } =
  M.unionWith (+) wlTokens systemTokens

tanimoto :: M.Map String Double -> M.Map String Double -> Double
tanimoto left right
  | denominator <= 0.0 = 0.0
  | otherwise = dotValue / denominator
  where
    dotValue =
      M.foldlWithKey'
        (\acc key leftValue -> acc + leftValue * M.findWithDefault 0.0 key right)
        0.0
        left
    leftNorm = M.foldl' (\acc value -> acc + value * value) 0.0 left
    rightNorm = M.foldl' (\acc value -> acc + value * value) 0.0 right
    denominator = leftNorm + rightNorm - dotValue

predictOneFromFull :: U.Vector Double -> Int -> [Int] -> U.Vector Double -> U.Vector Double -> Double -> Double -> Int -> (Double, Double)
predictOneFromFull fullKernel fullSize trainIdxs cholesky alpha targetMean targetScale testIndex =
  let kStar = U.fromList [kernelAt fullKernel fullSize trainIndex testIndex | trainIndex <- trainIdxs]
      meanScaled = dotVector kStar alpha
      forward = GP.forwardSubstitute (length trainIdxs) cholesky kStar
      latentVariance = max minimumVariance (kernelAt fullKernel fullSize testIndex testIndex - dotVector forward forward)
      observedVariance = max minimumVariance (latentVariance + noiseVariance)
      meanValue = targetMean + targetScale * meanScaled
      sdValue = targetScale * sqrt observedVariance
  in (meanValue, sdValue)

data Metrics = Metrics
  { metricRmse       :: !Double
  , metricMae        :: !Double
  , metricR2         :: !Double
  , metricCoverage90 :: !Double
  , metricMeanSd     :: !Double
  } deriving (Eq, Show)

summarizePredictions :: [Double] -> [(Double, Double)] -> Metrics
summarizePredictions actual predictions =
  let residuals = zipWith (\truth (meanValue, _) -> meanValue - truth) actual predictions
      n = max 1 (length residuals)
      invN = 1.0 / fromIntegral n
      rmse = sqrt (invN * sum [residual * residual | residual <- residuals])
      mae = invN * sum (map abs residuals)
      actualMean = mean actual
      totalSumSquares = sum [(value - actualMean) * (value - actualMean) | value <- actual]
      residualSumSquares = sum [residual * residual | residual <- residuals]
      r2 = if totalSumSquares <= 0.0 then 0.0 else 1.0 - residualSumSquares / totalSumSquares
      coverage =
        invN
          * fromIntegral
              ( length
                  [ ()
                  | (truth, (meanValue, sdValue)) <- zip actual predictions
                  , abs (meanValue - truth) <= 1.6448536269514722 * sdValue
                  ]
              )
      meanSd = invN * sum [sdValue | (_, sdValue) <- predictions]
  in Metrics rmse mae r2 coverage meanSd

meanAndScale :: [Double] -> (Double, Double)
meanAndScale values =
  let meanValue = mean values
      variance =
        if null values
          then 1.0
          else sum [(value - meanValue) * (value - meanValue) | value <- values]
                / fromIntegral (length values)
      scale = max 1.0e-9 (sqrt variance)
  in (meanValue, scale)

mean :: [Double] -> Double
mean [] = 0.0
mean values = sum values / fromIntegral (length values)

dotVector :: U.Vector Double -> U.Vector Double -> Double
dotVector left right = U.sum (U.zipWith (*) left right)

printFreeSolvWLBondingResult :: FreeSolvWLBondingResult -> IO ()
printFreeSolvWLBondingResult result = do
  putStrLn "FreeSolv MolADT WL + bonding-system GP"
  putStrLn $ "  split source: " ++ resultSplitSource result
  putStrLn $ "  seed: " ++ show (resultSeed result)
  putStrLn $
    "  molecules: train+valid="
      ++ show (resultTrainCount result)
      ++ ", test="
      ++ show (resultTestCount result)
  putStrLn $ "  RMSE: " ++ printf "%.6f kcal/mol" (resultRmse result)
  putStrLn $ "  MAE: " ++ printf "%.6f kcal/mol" (resultMae result)
  putStrLn $ "  R2: " ++ printf "%.6f" (resultR2 result)
  putStrLn $ "  mean predictive SD: " ++ printf "%.6f kcal/mol" (resultMeanSd result)
  putStrLn $ "  90%% coverage: " ++ printf "%.6f" (resultCoverage90 result)

printFreeSolvWLBondingSummary :: [FreeSolvWLBondingResult] -> IO ()
printFreeSolvWLBondingSummary [] =
  putStrLn "FreeSolv MolADT WL + bonding-system GP: no split results"
printFreeSolvWLBondingSummary results = do
  putStrLn "FreeSolv MolADT WL + bonding-system GP split summary"
  putStrLn $ "  splits: " ++ show (length results)
  putStrLn $ "  RMSE mean +/- sd: " ++ printf "%.6f +/- %.6f kcal/mol" (mean rmseValues) (stddev rmseValues)
  putStrLn $ "  MAE mean +/- sd: " ++ printf "%.6f +/- %.6f kcal/mol" (mean maeValues) (stddev maeValues)
  putStrLn $ "  R2 mean +/- sd: " ++ printf "%.6f +/- %.6f" (mean r2Values) (stddev r2Values)
  putStrLn $ "  mean predictive SD: " ++ printf "%.6f kcal/mol" (mean sdValues)
  putStrLn $ "  90%% coverage mean: " ++ printf "%.6f" (mean coverageValues)
  putStrLn $
    "  best RMSE seed: "
      ++ show (resultSeed bestResult)
      ++ " ("
      ++ printf "%.6f" (resultRmse bestResult)
      ++ " kcal/mol)"
  putStrLn $
    "  worst RMSE seed: "
      ++ show (resultSeed worstResult)
      ++ " ("
      ++ printf "%.6f" (resultRmse worstResult)
      ++ " kcal/mol)"
  where
    rmseValues = map resultRmse results
    maeValues = map resultMae results
    r2Values = map resultR2 results
    sdValues = map resultMeanSd results
    coverageValues = map resultCoverage90 results
    bestResult = head (sortOn resultRmse results)
    worstResult = last (sortOn resultRmse results)

stddev :: [Double] -> Double
stddev [] = 0.0
stddev values =
  let meanValue = mean values
      variance =
        sum [(value - meanValue) * (value - meanValue) | value <- values]
          / fromIntegral (length values)
  in sqrt variance

writeResultCsv :: FilePath -> FreeSolvWLBondingResult -> IO ()
writeResultCsv path result = writeResultsCsv path [result]

writeResultsCsv :: FilePath -> [FreeSolvWLBondingResult] -> IO ()
writeResultsCsv path results =
  writeFile path $
    unlines
      ( "seed,split_source,train_valid_count,test_count,rmse,mae,r2,mean_predictive_sd,coverage_90"
      : [ intercalate ","
          [ show (resultSeed result)
          , resultSplitSource result
          , show (resultTrainCount result)
          , show (resultTestCount result)
          , show (resultRmse result)
          , show (resultMae result)
          , show (resultR2 result)
          , show (resultMeanSd result)
          , show (resultCoverage90 result)
          ]
        | result <- results
        ]
      )

splitComma :: String -> [String]
splitComma [] = [""]
splitComma text =
  case break (== ',') text of
    (left, [])       -> [trim left]
    (left, _ : rest) -> trim left : splitComma rest

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace
