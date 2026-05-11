module Main where

import           BenchmarkModel
  ( BenchmarkInferenceMethod(..)
  , defaultProcessedDataDir
  , defaultSamplingConfig
  , parseInferenceMethod
  , runBenchmarkRegressionWith
  )
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import           Chem.IO.MoleculeViewer
  ( moleculeViewerURI
  , openMoleculeViewer
  , writeMoleculeViewerCollectionHTML
  , writeMoleculeViewerHTML
  )
import           Chem.IO.SDF (readSDF)
import           Chem.IO.MoleculeJSON (moleculeFromJSON, moleculeToJSON)
import           Chem.IO.SMILES (moleculeToSMILES, parseSMILES)
import           Chem.IO.SDFTiming (measureSdfTiming, renderTimingReport)
import           Chem.Molecule (Molecule, atoms, moleculeEdges, prettyPrintMolecule, systems)
import           Chem.Validate (validateMolecule)
import           ExampleMolecules.Diborane (diboranePretty)
import           ExampleMolecules.Benzene (benzenePretty)
import           ExampleMolecules.Ferrocene (ferrocenePretty)
import           ExampleMolecules.Morphine (morphinePretty)
import           FreeSolvInverseDesign
  ( InverseDesignConfig(..)
  , defaultInverseDesignConfig
  , parseSeedMoleculeName
  , printSearchResult
  , runFreeSolvInverseDesign
  )
import           FreeSolvWLBondingGP
  ( FreeSolvWLBondingConfig(..)
  , defaultFreeSolvWLBondingConfig
  , printFreeSolvWLBondingResult
  , printFreeSolvWLBondingSummary
  , runFreeSolvWLBondingGP
  , runFreeSolvWLBondingGPSplits
  , writeFreeSolvWLBondingFeatureDoc
  )
import qualified Data.Char as Char
import           Data.List (isPrefixOf, isSuffixOf)
import           Data.Maybe (isJust)
import           System.Environment (getArgs, lookupEnv)
import           System.FilePath (takeBaseName, (</>))
import           Text.Megaparsec (errorBundlePretty)
import           Text.Read (readMaybe)
import           SampleMolecules (methane, sodiumChloride, water)

main :: IO ()
main = do
  args <- getArgs
  processedDataDir <- resolveProcessedDataDir
  case args of
    [] -> runDemo processedDataDir
    ["demo"] -> runDemo processedDataDir
    ["parse", path] -> runParse path
    ["parse-smiles", smilesText] -> runParseSMILES smilesText
    ["parse-sdf-timing", path] -> runParseSdfTiming path Nothing
    ["parse-sdf-timing", path, limitText] -> runParseSdfTiming path (readMaybe limitText)
    ["pretty-example", "--help"] -> putStrLn usage
    "pretty-example" : name : prettyArgs -> runPrettyExample name prettyArgs
    ["view-html", "--help"] -> putStrLn usage
    "view-html" : viewArgs -> runViewHtmlCli viewArgs
    ["view-examples", "--help"] -> putStrLn usage
    "view-examples" : viewExampleArgs -> runViewExamplesCli viewExampleArgs
    ["to-smiles", path] -> runToSMILES path
    ["to-json", path] -> runToJSON path
    ["from-json", path] -> runFromJSON path
    ["infer-benchmark", datasetPrefix, methodName] ->
      runInferBenchmark processedDataDir datasetPrefix methodName Nothing
    ["infer-benchmark", datasetPrefix, methodName, limitText] ->
      runInferBenchmark processedDataDir datasetPrefix methodName (readMaybe limitText)
    "freesolv-wl-system-gp" : wlArgs ->
      runFreeSolvWLBondingCli processedDataDir wlArgs
    "freesolv-wl-system-features" : featureArgs ->
      runFreeSolvWLBondingFeatureCli processedDataDir featureArgs
    "inverse-design" : inverseArgs ->
      runInverseDesignCli processedDataDir inverseArgs
    _ -> putStrLn usage

usage :: String
usage = unlines
  [ "Usage:"
  , "  stack run moladtbayes -- demo"
  , "  stack run moladtbayes -- parse molecules/benzene.sdf"
  , "  stack run moladtbayes -- parse-smiles \"c1ccccc1\""
  , "  stack run moladtbayes -- parse-sdf-timing path/to/file.sdf_or_sdf_directory"
  , "  stack run moladtbayes -- parse-sdf-timing path/to/file.sdf_or_sdf_directory 1000"
  , "  stack run moladtbayes -- pretty-example benzene"
  , "  stack run moladtbayes -- pretty-example morphine"
  , "  stack run moladtbayes -- pretty-example sodium_chloride"
  , "  stack run moladtbayes -- pretty-example ferrocene --viewer-output results/viewer/ferrocene.viewer.html"
  , "  stack run moladtbayes -- view-examples --output results/viewer/haskell-examples.viewer.html --open-viewer"
  , "  stack run moladtbayes -- view-html molecules/benzene.sdf --output results/viewer/benzene.viewer.html"
  , "  stack run moladtbayes -- view-html benzene.moladt.json --format json --output results/viewer/benzene.viewer.html"
  , "  stack run moladtbayes -- to-smiles molecules/benzene.sdf"
  , "  stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json"
  , "  stack run moladtbayes -- from-json benzene.moladt.json"
  , "  stack run moladtbayes -- freesolv-wl-system-gp --seed 18"
  , "  stack run moladtbayes -- freesolv-wl-system-gp --split-json data/freesolv_wl_system_seed18_split.json"
  , "  stack run moladtbayes -- freesolv-wl-system-gp --all-splits --split-json data/freesolv_wl_system_20_splits.json --output results/freesolv_20split/run_manual/freesolv_wl_system_20split.csv"
  , "  stack run moladtbayes -- freesolv-wl-system-features --output docs/freesolv-gp-feature-list.md"
  , "  stack run moladtbayes -- infer-benchmark freesolv_moladt_featurized mh:0.2"
  , "  stack run moladtbayes -- inverse-design --target -5.0 --seed-molecule water"
  , ""
  , "Optional environment variable:"
  , "  MOLADT_PROCESSED_DATA_DIR=/path/to/data/processed"
  ]

resolveProcessedDataDir :: IO FilePath
resolveProcessedDataDir = do
  mProcessedDataDir <- lookupEnv "MOLADT_PROCESSED_DATA_DIR"
  pure (maybe defaultProcessedDataDir id mProcessedDataDir)

runDemo :: FilePath -> IO ()
runDemo processedDataDir = do
  putStrLn "Parsing molecules/benzene.sdf"
  benzeneParsed <- readSDF "molecules/benzene.sdf"
  case benzeneParsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right benzene ->
      case validateMolecule benzene of
        Left err -> do
          putStrLn "Benzene invalid:"
          putStrLn err
        Right _ -> do
          putStrLn $ "Benzene validated (" ++ show (length (atoms benzene)) ++ " atoms)."
          printSmiles "Benzene SMILES" benzene
          putStrLn "Parsing molecules/water.sdf"
          waterParsed <- readSDF "molecules/water.sdf"
          case waterParsed of
            Left err2 -> putStrLn (errorBundlePretty err2)
            Right water ->
              case validateMolecule water of
                Left err3 -> do
                  putStrLn "Water invalid:"
                  putStrLn err3
                Right _ -> do
                  printSmiles "Water SMILES" water
                  let samplingConfig = defaultSamplingConfig
                      gpMethod = UseMH 0.2
                  putStrLn $ "Processed data directory: " ++ processedDataDir
                  putStrLn "Running aligned FreeSolv / MolADT featurized GP smoke benchmark (MH):"
                  runBenchmarkRegressionWith samplingConfig gpMethod processedDataDir "freesolv_moladt_featurized" (Just 128)

runParse :: FilePath -> IO ()
runParse path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule -> do
      renderValidated molecule
      printSmiles "SMILES" molecule

runParseSMILES :: String -> IO ()
runParseSMILES smilesText =
  case parseSMILES smilesText >>= validateMolecule of
    Left err -> putStrLn err
    Right molecule -> renderValidated molecule

runParseSdfTiming :: FilePath -> Maybe Int -> IO ()
runParseSdfTiming path mLimit = do
  result <- measureSdfTiming path mLimit
  case result of
    Left err -> putStrLn err
    Right stages -> putStrLn (renderTimingReport stages)

runPrettyExample :: String -> [String] -> IO ()
runPrettyExample rawName rawArgs =
  case parsePrettyExampleArgs rawArgs of
    Left err -> putStrLn err
    Right options ->
      case lookupPrettyExample rawName of
        Nothing ->
          putStrLn $
            "Unknown built-in example `"
            ++ rawName
            ++ "`. Choose one of: benzene, diborane, ferrocene, morphine, sodium_chloride."
        Just (title, note, molecule) -> do
          putStrLn title
          putStrLn note
          putStrLn ""
          renderValidated molecule
          let shouldWriteViewer =
                prettyOpenViewer options || isJust (prettyViewerOutput options)
          if shouldWriteViewer
            then writeViewerAndMaybeOpen
                   (maybe (defaultExampleViewerOutput rawName) id (prettyViewerOutput options))
                   title
                   molecule
                   (prettyOpenViewer options)
            else pure ()

runViewHtmlCli :: [String] -> IO ()
runViewHtmlCli rawArgs =
  case rawArgs of
    [] -> putStrLn usage
    path : optionArgs ->
      case parseViewHtmlArgs path optionArgs of
        Left err -> putStrLn err
        Right options -> do
          loaded <- loadViewerMolecule (viewInputFormat options) path
          case loaded of
            Left err -> putStrLn err
            Right molecule ->
              case validateMolecule molecule of
                Left err -> putStrLn err
                Right validMolecule ->
                  writeViewerAndMaybeOpen
                    (viewOutputPath options)
                    (viewTitle options)
                    validMolecule
                    (viewOpenViewer options)

runViewExamplesCli :: [String] -> IO ()
runViewExamplesCli rawArgs =
  case parseViewExamplesArgs rawArgs of
    Left err -> putStrLn err
    Right options ->
      let selectedExamples =
            case viewExampleNames options of
              [] -> Right defaultViewerExamples
              names -> mapMaybeViewExamples names
      in case selectedExamples of
           Left err -> putStrLn err
           Right examples ->
             writeViewerCollectionAndMaybeOpen
               (viewExamplesOutputPath options)
               (viewExamplesTitle options)
               examples
               (viewExamplesOpenViewer options)

runToSMILES :: FilePath -> IO ()
runToSMILES path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case validateMolecule molecule of
        Left err2 -> putStrLn err2
        Right validMolecule ->
          case moleculeToSMILES validMolecule of
            Left err3 -> putStrLn err3
            Right smilesText -> putStrLn smilesText

runToJSON :: FilePath -> IO ()
runToJSON path = do
  parsed <- readSDF path
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case validateMolecule molecule of
        Left err2 -> putStrLn err2
        Right validMolecule -> BL8.putStrLn (moleculeToJSON validMolecule)

runFromJSON :: FilePath -> IO ()
runFromJSON path = do
  payload <- BL.readFile path
  case moleculeFromJSON payload of
    Left err -> putStrLn err
    Right molecule -> renderValidated molecule

writeViewerAndMaybeOpen :: FilePath -> String -> Molecule -> Bool -> IO ()
writeViewerAndMaybeOpen outputPath title molecule shouldOpen = do
  written <- writeMoleculeViewerHTML outputPath title molecule
  putStrLn $
    "Viewer molecule: "
      ++ show (length (atoms molecule))
      ++ " atoms, "
      ++ show (length (moleculeEdges molecule))
      ++ " edges, "
      ++ show (length (systems molecule))
      ++ " bonding systems."
  putStrLn ("Viewer HTML: " ++ written)
  uri <- moleculeViewerURI written
  putStrLn ""
  putStrLn ("Viewer URL: " ++ uri)
  putStrLn ""
  if shouldOpen
    then do
      opened <- openMoleculeViewer written
      if opened
        then putStrLn ("Viewer opened: " ++ uri)
        else do
          putStrLn "Viewer open request failed."
          putStrLn ""
          putStrLn ("Open this URL manually: " ++ uri)
          putStrLn ""
    else pure ()

writeViewerCollectionAndMaybeOpen :: FilePath -> String -> [(String, Molecule)] -> Bool -> IO ()
writeViewerCollectionAndMaybeOpen outputPath title molecules shouldOpen = do
  written <- writeMoleculeViewerCollectionHTML outputPath title molecules
  putStrLn $
    "Viewer molecules: "
      ++ show (length molecules)
      ++ " examples."
  putStrLn ("Viewer HTML: " ++ written)
  uri <- moleculeViewerURI written
  putStrLn ""
  putStrLn ("Viewer URL: " ++ uri)
  putStrLn ""
  if shouldOpen
    then do
      opened <- openMoleculeViewer written
      if opened
        then putStrLn ("Viewer opened: " ++ uri)
        else do
          putStrLn "Viewer open request failed."
          putStrLn ""
          putStrLn ("Open this URL manually: " ++ uri)
          putStrLn ""
    else pure ()

renderValidated :: Molecule -> IO ()
renderValidated molecule =
  case validateMolecule molecule of
    Left err -> putStrLn err
    Right validMolecule -> putStrLn (prettyPrintMolecule validMolecule)

runInferBenchmark :: FilePath -> String -> String -> Maybe Int -> IO ()
runInferBenchmark processedDataDir datasetPrefix methodName mLimit =
  if not ("freesolv_" `isPrefixOf` datasetPrefix)
    then
      putStrLn $
        "Unsupported benchmark dataset `"
        ++ datasetPrefix
        ++ "`. The Haskell benchmark consumer is now scoped to FreeSolv only; "
        ++ "use `freesolv_moladt_featurized`."
    else
      case parseInferenceMethod defaultSamplingConfig methodName of
        Nothing ->
          putStrLn $
            "Unknown inference method `" ++ methodName
            ++ "`. Use `lwis`, `lwis:<particles>`, `mh`, or `mh:<jitter>`."
        Just method ->
          runBenchmarkRegressionWith defaultSamplingConfig method processedDataDir datasetPrefix mLimit

runFreeSolvWLBondingCli :: FilePath -> [String] -> IO ()
runFreeSolvWLBondingCli processedDataDir rawArgs =
  case parseFreeSolvWLBondingArgs processedDataDir rawArgs of
    Left err -> putStrLn err
    Right config -> do
      if wlAllSplits config
        then do
          results <- runFreeSolvWLBondingGPSplits config
          printFreeSolvWLBondingSummary results
        else do
          result <- runFreeSolvWLBondingGP config
          printFreeSolvWLBondingResult result

parseFreeSolvWLBondingArgs :: FilePath -> [String] -> Either String FreeSolvWLBondingConfig
parseFreeSolvWLBondingArgs processedDataDir rawArgs =
  go rawArgs (defaultFreeSolvWLBondingConfig processedDataDir)
  where
    go [] config = Right config
    go ["--help"] _ = Left usage
    go ("--seed" : value : rest) config =
      case readMaybe value of
        Nothing -> Left "Invalid --seed value. Example: --seed 18"
        Just seedValue -> go rest config { wlSeed = seedValue }
    go ("--split-json" : path : rest) config =
      go rest config { wlSplitJson = Just path }
    go ("--all-splits" : rest) config =
      go rest config { wlAllSplits = True }
    go ("--raw-sdf-dir" : path : rest) config =
      go rest config { wlRawSdfDir = path }
    go ("--output" : path : rest) config =
      go rest config { wlOutputCsv = Just path }
    go (flag : _) _ =
      Left $
        "Unknown freesolv-wl-system-gp option `"
        ++ flag
        ++ "`. Use --seed, --split-json, --all-splits, --raw-sdf-dir, and/or --output."

runFreeSolvWLBondingFeatureCli :: FilePath -> [String] -> IO ()
runFreeSolvWLBondingFeatureCli processedDataDir rawArgs =
  case parseFreeSolvWLBondingFeatureArgs processedDataDir rawArgs of
    Left err -> putStrLn err
    Right (config, outputPath) -> do
      writeFreeSolvWLBondingFeatureDoc config outputPath
      putStrLn ("Wrote Haskell FreeSolv GP feature list: " ++ outputPath)

parseFreeSolvWLBondingFeatureArgs :: FilePath -> [String] -> Either String (FreeSolvWLBondingConfig, FilePath)
parseFreeSolvWLBondingFeatureArgs processedDataDir rawArgs =
  go rawArgs (defaultFreeSolvWLBondingConfig processedDataDir) "docs/freesolv-gp-feature-list.md"
  where
    go [] config outputPath = Right (config, outputPath)
    go ["--help"] _ _ = Left usage
    go ("--raw-sdf-dir" : path : rest) config outputPath =
      go rest config { wlRawSdfDir = path } outputPath
    go ("--output" : path : rest) config _ =
      go rest config path
    go (flag : _) _ _ =
      Left $
        "Unknown freesolv-wl-system-features option `"
        ++ flag
        ++ "`. Use --raw-sdf-dir and/or --output."

runInverseDesignCli :: FilePath -> [String] -> IO ()
runInverseDesignCli processedDataDir rawArgs =
  case parseInverseDesignArgs rawArgs of
    Left err -> putStrLn err
    Right config -> do
      result <- runFreeSolvInverseDesign processedDataDir config
      printSearchResult result

parseInverseDesignArgs :: [String] -> Either String InverseDesignConfig
parseInverseDesignArgs rawArgs = go rawArgs defaultInverseDesignConfig
  where
    go [] config = Right config
    go ["--help"] _ = Left usage
    go ("--target" : value : rest) config =
      case readMaybe value of
        Nothing ->
          Left "Invalid --target value. Example: --target -5.0"
        Just targetValue ->
          go rest config { configTarget = Just targetValue }
    go ("--seed-molecule" : value : rest) config =
      case parseSeedMoleculeName value of
        Nothing ->
          Left "Invalid --seed-molecule value. Use water or methane."
        Just seedName ->
          go rest config { configSeedMolecule = seedName }
    go (flag : _) _ =
      Left $
        "Unknown inverse-design option `"
        ++ flag
        ++ "`. Use only --target and --seed-molecule."

data PrettyExampleOptions = PrettyExampleOptions
  { prettyViewerOutput :: Maybe FilePath
  , prettyOpenViewer :: Bool
  }

defaultPrettyExampleOptions :: PrettyExampleOptions
defaultPrettyExampleOptions =
  PrettyExampleOptions
    { prettyViewerOutput = Nothing
    , prettyOpenViewer = False
    }

parsePrettyExampleArgs :: [String] -> Either String PrettyExampleOptions
parsePrettyExampleArgs rawArgs = go rawArgs defaultPrettyExampleOptions
  where
    go [] options = Right options
    go ["--help"] _ = Left usage
    go ("--viewer-output" : outputPath : rest) options =
      go rest options { prettyViewerOutput = Just outputPath }
    go ("--open-viewer" : rest) options =
      go rest options { prettyOpenViewer = True }
    go (flag : _) _ =
      Left $
        "Unknown pretty-example option `"
        ++ flag
        ++ "`. Use --viewer-output and/or --open-viewer."

data ViewInputFormat = ViewInputSDF | ViewInputJSON

data ViewHtmlOptions = ViewHtmlOptions
  { viewOutputPath :: FilePath
  , viewTitle :: String
  , viewInputFormat :: ViewInputFormat
  , viewOpenViewer :: Bool
  }

parseViewHtmlArgs :: FilePath -> [String] -> Either String ViewHtmlOptions
parseViewHtmlArgs path rawArgs = go rawArgs defaultOptions
  where
    defaultOptions =
      ViewHtmlOptions
        { viewOutputPath = defaultViewerOutput path
        , viewTitle = defaultViewerTitle path
        , viewInputFormat = inferViewInputFormat path
        , viewOpenViewer = False
        }

    go [] options = Right options
    go ["--help"] _ = Left usage
    go ("--output" : outputPath : rest) options =
      go rest options { viewOutputPath = outputPath }
    go ("--title" : titleText : rest) options =
      go rest options { viewTitle = titleText }
    go ("--format" : formatText : rest) options =
      case parseViewInputFormat formatText of
        Nothing ->
          Left "Invalid --format value. Use sdf or json."
        Just inputFormat ->
          go rest options { viewInputFormat = inputFormat }
    go ("--open-viewer" : rest) options =
      go rest options { viewOpenViewer = True }
    go (flag : _) _ =
      Left $
        "Unknown view-html option `"
        ++ flag
        ++ "`. Use --output, --title, --format, and/or --open-viewer."

data ViewExamplesOptions = ViewExamplesOptions
  { viewExamplesOutputPath :: FilePath
  , viewExamplesTitle :: String
  , viewExamplesOpenViewer :: Bool
  , viewExampleNames :: [String]
  }

parseViewExamplesArgs :: [String] -> Either String ViewExamplesOptions
parseViewExamplesArgs rawArgs = go rawArgs defaultOptions
  where
    defaultOptions =
      ViewExamplesOptions
        { viewExamplesOutputPath = "results" </> "viewer" </> "haskell-examples.viewer.html"
        , viewExamplesTitle = "MolADT Haskell examples"
        , viewExamplesOpenViewer = False
        , viewExampleNames = []
        }

    go [] options = Right options
    go ["--help"] _ = Left usage
    go ("--output" : outputPath : rest) options =
      go rest options { viewExamplesOutputPath = outputPath }
    go ("--title" : titleText : rest) options =
      go rest options { viewExamplesTitle = titleText }
    go ("--open-viewer" : rest) options =
      go rest options { viewExamplesOpenViewer = True }
    go ("--examples" : namesText : rest) options =
      go rest options { viewExampleNames = splitNames namesText }
    go (flag : _) _ =
      Left $
        "Unknown view-examples option `"
        ++ flag
        ++ "`. Use --output, --title, --examples, and/or --open-viewer."

splitNames :: String -> [String]
splitNames text =
  filter (not . null) (splitOnComma text)
  where
    splitOnComma [] = [""]
    splitOnComma value =
      case break (== ',') value of
        (left, []) -> [left]
        (left, _ : rest) -> left : splitOnComma rest

parseViewInputFormat :: String -> Maybe ViewInputFormat
parseViewInputFormat rawValue =
  case map Char.toLower rawValue of
    "sdf" -> Just ViewInputSDF
    "json" -> Just ViewInputJSON
    _ -> Nothing

inferViewInputFormat :: FilePath -> ViewInputFormat
inferViewInputFormat path =
  if ".json" `isSuffixOf` map Char.toLower path
    then ViewInputJSON
    else ViewInputSDF

loadViewerMolecule :: ViewInputFormat -> FilePath -> IO (Either String Molecule)
loadViewerMolecule inputFormat path =
  case inputFormat of
    ViewInputSDF -> do
      parsed <- readSDF path
      pure $
        case parsed of
          Left err -> Left (errorBundlePretty err)
          Right molecule -> Right molecule
    ViewInputJSON -> do
      payload <- BL.readFile path
      pure (moleculeFromJSON payload)

defaultViewerOutput :: FilePath -> FilePath
defaultViewerOutput path =
  "results" </> "viewer" </> takeBaseName path ++ ".viewer.html"

defaultExampleViewerOutput :: String -> FilePath
defaultExampleViewerOutput rawName =
  "results" </> "viewer" </> exampleSlug rawName ++ ".viewer.html"

defaultViewerTitle :: FilePath -> String
defaultViewerTitle path =
  case takeBaseName path of
    "" -> "MolADT viewer"
    baseName -> baseName ++ " MolADT viewer"

exampleSlug :: String -> String
exampleSlug =
  map slugChar
  where
    slugChar char
      | Char.isAlphaNum char = Char.toLower char
      | otherwise = '-'

printSmiles :: String -> Molecule -> IO ()
printSmiles label molecule =
  case moleculeToSMILES molecule of
    Left err -> putStrLn (label ++ ": " ++ err)
    Right smilesText -> putStrLn (label ++ ": " ++ smilesText)

lookupPrettyExample :: String -> Maybe (String, String, Molecule)
lookupPrettyExample rawName =
  case map Char.toLower rawName of
    "benzene" ->
      Just
        ( "Benzene (C6H6)"
        , "Dietz-style ADT with each sigma edge as an unnamed 2e bonding system plus a six-electron pi_ring system."
        , benzenePretty
        )
    "diborane" ->
      Just
        ( "Diborane (B2H6)"
        , "Dietz-style ADT with two explicit 3c-2e bridging hydrogen bonding systems."
        , diboranePretty
        )
    "ferrocene" ->
      Just
        ( "Ferrocene (Fe(C5H5)2)"
          , "Dietz-style ADT with two Fe-centred cyclopentadienyl delocalised systems."
        , ferrocenePretty
        )
    "sodium-chloride" ->
      sodiumChlorideExample
    "sodium_chloride" ->
      sodiumChlorideExample
    "morphine" ->
      Just
        ( "Morphine (explicit Dietz skeleton)"
        , "Dietz-style ADT that turns the five classic SMILES ring closures into sigma edges, keeps the phenyl ring as an explicit pi system, and preserves the five atom-centered stereochemistry flags from the standard boundary string."
        , morphinePretty
        )
    _ -> Nothing
  where
    sodiumChlorideExample =
      Just
        ( "Sodium chloride (NaCl)"
        , "Dietz-style ADT with Na+ and Cl- formal charges plus one 0e ionic bonding system over the Na-Cl edge."
        , sodiumChloride
        )

defaultViewerExamples :: [(String, Molecule)]
defaultViewerExamples =
  [ ("Benzene", benzenePretty)
  , ("Diborane", diboranePretty)
  , ("Ferrocene", ferrocenePretty)
  , ("Morphine", morphinePretty)
  , ("Sodium chloride", sodiumChloride)
  , ("Water", water)
  , ("Methane", methane)
  ]

mapMaybeViewExamples :: [String] -> Either String [(String, Molecule)]
mapMaybeViewExamples names = traverse lookupViewerExample names

lookupViewerExample :: String -> Either String (String, Molecule)
lookupViewerExample rawName =
  case map Char.toLower rawName of
    "benzene" -> Right ("Benzene", benzenePretty)
    "diborane" -> Right ("Diborane", diboranePretty)
    "ferrocene" -> Right ("Ferrocene", ferrocenePretty)
    "morphine" -> Right ("Morphine", morphinePretty)
    "sodium-chloride" -> Right ("Sodium chloride", sodiumChloride)
    "sodium_chloride" -> Right ("Sodium chloride", sodiumChloride)
    "water" -> Right ("Water", water)
    "methane" -> Right ("Methane", methane)
    _ ->
      Left $
        "Unknown viewer example `"
        ++ rawName
        ++ "`. Choose from benzene, diborane, ferrocene, morphine, sodium_chloride, water, methane."
