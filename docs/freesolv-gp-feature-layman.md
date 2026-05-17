# FreeSolv GP Features In Plain English

This is the plain-English companion to the current
[FreeSolv GP feature list](freesolv-gp-feature-list.md).

The current model uses 30 compact features rather than the older sparse WL token
vocabulary.

## Atom Bag Features

| Feature | Meaning |
| --- | --- |
| `smiles_atom_count_c` | Number of carbon atoms. |
| `smiles_atom_count_n` | Number of nitrogen atoms. |
| `smiles_atom_count_o` | Number of oxygen atoms. |
| `smiles_atom_count_f` | Number of fluorine atoms. |
| `smiles_atom_count_p` | Number of phosphorus atoms. |
| `smiles_atom_count_s` | Number of sulfur atoms. |
| `smiles_atom_count_cl` | Number of chlorine atoms. |
| `smiles_atom_count_br` | Number of bromine atoms. |
| `smiles_atom_count_i` | Number of iodine atoms. |
| `smiles_atom_count_h` | Number of hydrogen atoms. |

## Graph Baseline Additions

| Feature | Meaning |
| --- | --- |
| `smiles_bond_count_single` | Number of single bonds in the decoded SMILES graph. |
| `smiles_bond_count_aromatic` | Number of aromatic bonds in the decoded SMILES graph. |
| `smiles_bond_count_double` | Number of double bonds in the decoded SMILES graph. |
| `smiles_bond_count_triple` | Number of triple bonds in the decoded SMILES graph. |
| `smiles_bond_count_total` | Total number of graph bonds. |
| `smiles_heavy_atom_count` | Number of non-hydrogen atoms. |
| `smiles_component_count` | Number of disconnected molecular components. |
| `smiles_cycle_rank` | Simple graph cycle count. |
| `smiles_heavy_degree_mean` | Mean degree of the heavy-atom graph. |
| `smiles_heavy_degree_max` | Maximum degree of the heavy-atom graph. |

## MolADT Additions

| Feature | Meaning |
| --- | --- |
| `weight` | Molecular weight from the typed molecule. |
| `polar` | Polarity proxy from MolADT descriptors. |
| `surface` | Surface-size proxy from MolADT descriptors. |
| `donor_count` | Count of hydrogen-bond donor-like sites. |
| `acceptor_count` | Count of hydrogen-bond acceptor-like sites. |
| `bonding_system_count` | Number of explicit Dietz bonding systems. |
| `multicentre_system_count` | Number of bonding systems involving more than two atoms. |
| `pi_ring_system_count` | Number of explicit pi-ring bonding systems. |
| `system_shared_electrons_sum` | Total shared electrons across bonding systems. |
| `aprdf_system_edge_1p5a` | Short-range radial descriptor over bonding-system edges. |
