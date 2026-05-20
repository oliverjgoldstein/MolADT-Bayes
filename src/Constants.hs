-- | Centralised physical and chemical constants used throughout the
-- molecular models.  Having a dedicated module keeps the domain knowledge
-- (bond lengths, valence limits, atomic metadata) in one place so other
-- modules can focus on behaviour.
module Constants where

import Chem.Molecule (AtomicSymbol(..), ElementAttributes(..), Angstrom(..), mkAngstrom)
import Chem.Dietz ()
import qualified Orbital as Orb
import qualified Data.Map.Strict as M

-- | Takes the bond order and two atomic symbols and gives the equilibrium
-- bond length between them (in Angstrom).  Only a small subset of common
-- covalent bonds are included; the lookup is symmetric in the atom labels.
type EquilibriumBondLength = Angstrom

equilibriumBondLengths :: Integer -> AtomicSymbol -> AtomicSymbol -> Maybe EquilibriumBondLength
equilibriumBondLengths bondOrder symbol1 symbol2 =
    M.lookup (bondOrder, s1, s2) bondLengthMap
  where
    (s1, s2) = normalize symbol1 symbol2

-- | Order a pair of atomic symbols to normalise map lookups.
normalize :: AtomicSymbol -> AtomicSymbol -> (AtomicSymbol, AtomicSymbol)
normalize a b
    | a <= b    = (a, b)
    | otherwise = (b, a)

-- | Lookup table for equilibrium bond lengths keyed by bond order and the
-- normalised pair of atomic symbols.
bondLengthMap :: M.Map (Integer, AtomicSymbol, AtomicSymbol) EquilibriumBondLength
bondLengthMap = M.fromList $ concat [order1, order2, order3]
  where
    order1 =
      [ ((1, H, H), mkAngstrom 0.74)
      , ((1, H, C), mkAngstrom 1.09)
      , ((1, H, N), mkAngstrom 1.01)
      , ((1, H, O), mkAngstrom 0.96)
      , ((1, H, Fe), mkAngstrom 1.52)
      , ((1, H, B), mkAngstrom 1.19)
      , ((1, C, C), mkAngstrom 1.54)
      , ((1, C, N), mkAngstrom 1.47)
      , ((1, C, O), mkAngstrom 1.43)
      , ((1, C, Fe), mkAngstrom 1.84)
      , ((1, C, B), mkAngstrom 1.55)
      , ((1, N, N), mkAngstrom 1.45)
      , ((1, N, O), mkAngstrom 1.40)
      , ((1, N, Fe), mkAngstrom 1.76)
      , ((1, N, B), mkAngstrom 1.55)
      , ((1, O, O), mkAngstrom 1.48)
      , ((1, O, Fe), mkAngstrom 1.70)
      , ((1, O, B), mkAngstrom 1.49)
      , ((1, Fe, Fe), mkAngstrom 2.48)
      , ((1, Fe, B), mkAngstrom 2.03)
      , ((1, B, B), mkAngstrom 1.59)
      ]
    order2 =
      [ ((2, H, H), mkAngstrom 0.74)
      , ((2, H, C), mkAngstrom 1.06)
      , ((2, H, N), mkAngstrom 1.01)
      , ((2, H, O), mkAngstrom 0.96)
      , ((2, H, Fe), mkAngstrom 1.52)
      , ((2, H, B), mkAngstrom 1.19)
      , ((2, C, C), mkAngstrom 1.34)
      , ((2, C, N), mkAngstrom 1.27)
      , ((2, C, O), mkAngstrom 1.20)
      , ((2, C, Fe), mkAngstrom 1.64)
      , ((2, C, B), mkAngstrom 1.37)
      , ((2, N, N), mkAngstrom 1.25)
      , ((2, N, O), mkAngstrom 1.20)
      , ((2, N, Fe), mkAngstrom 1.64)
      , ((2, N, B), mkAngstrom 1.33)
      , ((2, O, O), mkAngstrom 1.21)
      , ((2, O, Fe), mkAngstrom 1.58)
      , ((2, O, B), mkAngstrom 1.26)
      , ((2, Fe, Fe), mkAngstrom 2.26)
      , ((2, Fe, B), mkAngstrom 1.89)
      , ((2, B, B), mkAngstrom 1.59)
      ]
    order3 =
      [ ((3, H, H), mkAngstrom 0.74)
      , ((3, H, C), mkAngstrom 1.06)
      , ((3, H, N), mkAngstrom 1.01)
      , ((3, H, O), mkAngstrom 0.96)
      , ((3, H, Fe), mkAngstrom 1.52)
      , ((3, H, B), mkAngstrom 1.19)
      , ((3, C, C), mkAngstrom 1.20)
      , ((3, C, N), mkAngstrom 1.14)
      , ((3, C, O), mkAngstrom 1.13)
      , ((3, C, Fe), mkAngstrom 1.44)
      , ((3, C, B), mkAngstrom 1.19)
      , ((3, N, N), mkAngstrom 1.10)
      , ((3, N, O), mkAngstrom 1.06)
      , ((3, N, Fe), mkAngstrom 1.50)
      , ((3, N, B), mkAngstrom 1.20)
      , ((3, O, O), mkAngstrom 1.21)
      , ((3, O, Fe), mkAngstrom 1.58)
      , ((3, O, B), mkAngstrom 1.20)
      , ((3, Fe, Fe), mkAngstrom 2.26)
      , ((3, Fe, B), mkAngstrom 1.89)
      , ((3, B, B), mkAngstrom 1.59)
      ]

-- | Typical minimum and maximum number of electrons used in bonding for an
-- element.  The second component provides the upper limit used during
-- validation when checking that an atom does not exceed its usual electron
-- count according to a simple valence heuristic.
nominalValence :: AtomicSymbol -> (Int, Int)
nominalValence symbol = case symbol of
    H  -> (2, 2)
    C  -> (8, 8)
    N  -> (6, 6)
    O  -> (4, 4)
    F  -> (2, 2)
    P  -> (6, 10)
    Si -> (8, 8)
    S  -> (4, 12)
    Cl -> (2, 2)
    Br -> (2, 2)
    B  -> (6, 6)
    Fe -> (0, 12)
    I  -> (2, 2)
    Na -> (2, 2)
    _  -> (0, 16)

-- | Official element symbols, ordered by atomic number.
allAtomicSymbols :: [AtomicSymbol]
allAtomicSymbols =
  [ H, He, Li, Be, B, C, N, O, F, Ne
  , Na, Mg, Al, Si, P, S, Cl, Ar
  , K, Ca, Sc, Ti, V, Cr, Mn, Fe, Co, Ni, Cu, Zn
  , Ga, Ge, As, Se, Br, Kr
  , Rb, Sr, Y, Zr, Nb, Mo, Tc, Ru, Rh, Pd, Ag, Cd
  , In, Sn, Sb, Te, I, Xe
  , Cs, Ba, La, Ce, Pr, Nd, Pm, Sm, Eu, Gd, Tb, Dy
  , Ho, Er, Tm, Yb, Lu
  , Hf, Ta, W, Re, Os, Ir, Pt, Au, Hg, Tl, Pb, Bi
  , Po, At, Rn, Fr, Ra, Ac, Th, Pa, U, Np, Pu, Am
  , Cm, Bk, Cf, Es, Fm, Md, No, Lr, Rf, Db, Sg, Bh
  , Hs, Mt, Ds, Rg, Cn, Nh, Fl, Mc, Lv, Ts, Og
  ]

-- | Maximum number of bonds typically formed by an element, derived from the
-- upper electron count in 'nominalValence'.
getMaxBondsSymbol :: AtomicSymbol -> Double
getMaxBondsSymbol sym =
    let (_, maxElectrons) = nominalValence sym
    in fromIntegral maxElectrons / 2.0

-- | Tabulate atomic numbers, atomic weights, and default shell data for all
-- 118 currently official elements. Atomic weights use CIAAW 2024 standard
-- atomic weights where a standard value exists. Radioactive elements without
-- a standard atomic weight use NIST SP 966 June 2024 mass numbers for the
-- longest-lived isotope.
elementAttributes :: AtomicSymbol -> ElementAttributes
elementAttributes atomSymbol =
  case M.lookup atomSymbol elementDataMap of
    Just (atomicNumberValue, atomicWeightValue) ->
      ElementAttributes atomSymbol atomicNumberValue atomicWeightValue (M.lookup atomSymbol elementShellMap)
    Nothing -> error ("Missing element attributes for " ++ show atomSymbol)

elementDataMap :: M.Map AtomicSymbol (Int, Double)
elementDataMap = M.fromList
  [ (H, (1, 1.008))
  , (He, (2, 4.002602))
  , (Li, (3, 6.94))
  , (Be, (4, 9.0121831))
  , (B, (5, 10.81))
  , (C, (6, 12.011))
  , (N, (7, 14.007))
  , (O, (8, 15.999))
  , (F, (9, 18.998403162))
  , (Ne, (10, 20.1797))
  , (Na, (11, 22.98976928))
  , (Mg, (12, 24.305))
  , (Al, (13, 26.9815384))
  , (Si, (14, 28.085))
  , (P, (15, 30.973761998))
  , (S, (16, 32.06))
  , (Cl, (17, 35.45))
  , (Ar, (18, 39.95))
  , (K, (19, 39.0983))
  , (Ca, (20, 40.078))
  , (Sc, (21, 44.955907))
  , (Ti, (22, 47.867))
  , (V, (23, 50.9415))
  , (Cr, (24, 51.9961))
  , (Mn, (25, 54.938043))
  , (Fe, (26, 55.845))
  , (Co, (27, 58.933194))
  , (Ni, (28, 58.6934))
  , (Cu, (29, 63.546))
  , (Zn, (30, 65.38))
  , (Ga, (31, 69.723))
  , (Ge, (32, 72.630))
  , (As, (33, 74.921595))
  , (Se, (34, 78.971))
  , (Br, (35, 79.904))
  , (Kr, (36, 83.798))
  , (Rb, (37, 85.4678))
  , (Sr, (38, 87.62))
  , (Y, (39, 88.905838))
  , (Zr, (40, 91.222))
  , (Nb, (41, 92.90637))
  , (Mo, (42, 95.95))
  , (Tc, (43, 97.0))
  , (Ru, (44, 101.07))
  , (Rh, (45, 102.90549))
  , (Pd, (46, 106.42))
  , (Ag, (47, 107.8682))
  , (Cd, (48, 112.414))
  , (In, (49, 114.818))
  , (Sn, (50, 118.710))
  , (Sb, (51, 121.760))
  , (Te, (52, 127.60))
  , (I, (53, 126.90447))
  , (Xe, (54, 131.293))
  , (Cs, (55, 132.90545196))
  , (Ba, (56, 137.327))
  , (La, (57, 138.90547))
  , (Ce, (58, 140.116))
  , (Pr, (59, 140.90766))
  , (Nd, (60, 144.242))
  , (Pm, (61, 145.0))
  , (Sm, (62, 150.36))
  , (Eu, (63, 151.964))
  , (Gd, (64, 157.249))
  , (Tb, (65, 158.925354))
  , (Dy, (66, 162.500))
  , (Ho, (67, 164.930329))
  , (Er, (68, 167.259))
  , (Tm, (69, 168.934219))
  , (Yb, (70, 173.045))
  , (Lu, (71, 174.96669))
  , (Hf, (72, 178.486))
  , (Ta, (73, 180.94788))
  , (W, (74, 183.84))
  , (Re, (75, 186.207))
  , (Os, (76, 190.23))
  , (Ir, (77, 192.217))
  , (Pt, (78, 195.084))
  , (Au, (79, 196.966570))
  , (Hg, (80, 200.592))
  , (Tl, (81, 204.38))
  , (Pb, (82, 207.2))
  , (Bi, (83, 208.98040))
  , (Po, (84, 209.0))
  , (At, (85, 210.0))
  , (Rn, (86, 222.0))
  , (Fr, (87, 223.0))
  , (Ra, (88, 226.0))
  , (Ac, (89, 227.0))
  , (Th, (90, 232.0377))
  , (Pa, (91, 231.03588))
  , (U, (92, 238.02891))
  , (Np, (93, 237.0))
  , (Pu, (94, 244.0))
  , (Am, (95, 243.0))
  , (Cm, (96, 247.0))
  , (Bk, (97, 247.0))
  , (Cf, (98, 251.0))
  , (Es, (99, 252.0))
  , (Fm, (100, 257.0))
  , (Md, (101, 258.0))
  , (No, (102, 259.0))
  , (Lr, (103, 262.0))
  , (Rf, (104, 267.0))
  , (Db, (105, 268.0))
  , (Sg, (106, 269.0))
  , (Bh, (107, 270.0))
  , (Hs, (108, 269.0))
  , (Mt, (109, 277.0))
  , (Ds, (110, 281.0))
  , (Rg, (111, 282.0))
  , (Cn, (112, 285.0))
  , (Nh, (113, 286.0))
  , (Fl, (114, 290.0))
  , (Mc, (115, 290.0))
  , (Lv, (116, 293.0))
  , (Ts, (117, 294.0))
  , (Og, (118, 294.0))
  ]

elementShellMap :: M.Map AtomicSymbol Orb.Shells
elementShellMap = M.fromList
  [ (O, Orb.oxygen)
  , (H, Orb.hydrogen)
  , (N, Orb.nitrogen)
  , (C, Orb.carbon)
  , (B, Orb.boron)
  , (Fe, Orb.iron)
  , (F, Orb.fluorine)
  , (Cl, Orb.chlorine)
  , (S, Orb.sulfur)
  , (Br, Orb.bromine)
  , (P, Orb.phosphorus)
  , (Si, Orb.silicon)
  , (I, Orb.iodine)
  , (Na, Orb.sodium)
  ]
