# Parsing and Rendering

MolADT treats SDF, SMILES, and JSON as boundary formats.

The typed `Molecule` value is the internal object.

## SDF To MolADT

```bash
stack run moladtbayes -- parse molecules/benzene.sdf
```

This reads one SDF record, validates it, and prints the structured MolADT
report.

Supported SDF input is intentionally practical:

- V2000 atom and bond blocks
- core V3000 CTAB atom and bond blocks
- atom coordinates
- atom-local formal charges

This is a parser for ordinary structure exports, not a full MDL query toolkit.
Single, double, triple, and non-aromatic quadruple bond table entries are lifted
into one-edge bonding systems with 2, 4, 6, and 8 shared electrons, displayed as
`single covalent`, `double covalent`, `triple covalent`, and `quadruple covalent`.
When a single edge connects charged `Na+` to a supported charged anion (`F`,
`Cl`, `Br`, `I`, `O`, `N`, or `S`), the parser stores the edge as a 0e `ionic`
bonding system and keeps formal charge on the atoms.

Programmatic version:

```haskell
import Chem.IO.SDF (readSDF)
import Chem.Validate (validateMolecule)
import Text.Megaparsec (errorBundlePretty)

main :: IO ()
main = do
  parsed <- readSDF "molecules/benzene.sdf"
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case validateMolecule molecule of
        Left validationErr -> putStrLn validationErr
        Right validMolecule -> print validMolecule
```

## MolADT JSON

```bash
stack run moladtbayes -- to-json molecules/benzene.sdf > benzene.moladt.json
stack run moladtbayes -- from-json benzene.moladt.json
```

JSON is the shared boundary with the Python repo. Use it when Haskell and Python
need to exchange the same typed molecule shape.

Programmatic round trip:

```haskell
import Chem.IO.MoleculeJSON (moleculeFromJSON, moleculeToJSON)
import Chem.IO.SDF (readSDF)
import Chem.Molecule (atoms)
import Text.Megaparsec (errorBundlePretty)

main :: IO ()
main = do
  parsed <- readSDF "molecules/benzene.sdf"
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule ->
      case moleculeFromJSON (moleculeToJSON molecule) of
        Left jsonErr -> putStrLn jsonErr
        Right roundTripped -> print (length (atoms roundTripped))
```

## Viewer

The Haskell CLI can write the same standalone MolADT viewer shape as the Python
repo. The output is one HTML file, so it can be attached to a result, opened in a
browser, or shared without a server.

```bash
stack run moladtbayes -- view-html molecules/benzene.sdf --output results/viewer/benzene.viewer.html
stack run moladtbayes -- view-html benzene.moladt.json --format json --output results/viewer/benzene.viewer.html
stack run moladtbayes -- pretty-example ferrocene --viewer-output results/viewer/ferrocene.viewer.html
```

Programmatic version:

```haskell
import Chem.IO.MoleculeViewer (writeMoleculeViewerHTML)
import Chem.IO.SDF (readSDF)
import Text.Megaparsec (errorBundlePretty)

main :: IO ()
main = do
  parsed <- readSDF "molecules/benzene.sdf"
  case parsed of
    Left err -> putStrLn (errorBundlePretty err)
    Right molecule -> do
      _ <- writeMoleculeViewerHTML
        "results/viewer/benzene.viewer.html"
        "Benzene MolADT viewer"
        molecule
      pure ()
```

The viewer panel lists explicit bonding systems, including the one-edge systems
for ordinary bonds, so molecules like diborane and ferrocene are inspectable as
ADTs rather than flattened bond tables. Charge is shown as blue/red halos around
charged atoms, and ionic edges draw a blue-to-red gradient between charged
atoms. The CLI prints a portable `file://` URL for the written viewer, so the
same output works as a manual fallback if OS auto-open fails. Ordinary covalent
edges are dark grey single/double/triple/quadruple line sets and are not
repeated as page labels; non-standard systems use a separate coloured overlay.

## SMILES To MolADT

```bash
stack run moladtbayes -- parse-smiles "c1ccccc1"
```

The parser supports a conservative chemistry subset and lifts it into MolADT.
Aromatic six-membered rings can become explicit `pi_ring` Dietz systems, while
ordinary single/double/triple/quadruple SMILES bonds become `single covalent`,
`double covalent`, `triple covalent`, and `quadruple covalent` edge systems.
The supported charged sodium-halide pattern also round-trips: `[Na+][Cl-]`
becomes charged atoms plus a 0e `ionic` system and renders back to
`[Na+][Cl-]`.
Named or multi-edge systems receive the first stable `SystemId` values, so
benzene has `SystemId 1` for `pi_ring` followed by the ordinary one-edge
covalent systems.

## MolADT To SMILES

```bash
stack run moladtbayes -- to-smiles molecules/benzene.sdf
```

Rendering is deliberately narrower than parsing. It is for validated classical
structures inside the supported subset.

## Timing

```bash
make haskell-parse-sdf-timing
```

This compares raw SDF file reads with local `SDF -> MolADT` parsing on the
cached sibling Python ZINC timing corpus.

Next: [SMILES scope and validation](smiles-scope-and-validation.md),
[CLI and demo](cli-and-demo.md).
