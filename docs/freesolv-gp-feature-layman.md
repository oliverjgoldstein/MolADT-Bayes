# FreeSolv GP Features In Plain English

This is the plain-English companion to the current
[FreeSolv GP feature list](freesolv-gp-feature-list.md).

The current `moladt_full30_rbf_gp` feature set is a compact MolADT multigraph
panel. It keeps simple size and polarity signals, then spends most of the
budget on explicit bonding-system and effective-order information.

## Composition And Polarity

| Feature | Meaning |
| --- | --- |
| `weight` | Molecular weight. |
| `polar` | Polarity proxy from the typed molecule. |
| `surface` | Surface-size proxy. |
| `donor_count` | Hydrogen-bond donor-like site count. |
| `acceptor_count` | Hydrogen-bond acceptor-like site count. |
| `heavy_atoms` | Number of non-hydrogen atoms. |
| `halogens` | Number of fluorine, chlorine, bromine, and iodine atoms. |
| `atom_count_c` | Number of carbon atoms. |
| `atom_count_n` | Number of nitrogen atoms. |
| `atom_count_o` | Number of oxygen atoms. |

## Multigraph Bonding Systems

| Feature | Meaning |
| --- | --- |
| `sigma_edge_count` | Number of ordinary sigma edges. |
| `effective_bond_order_sum` | Total effective bond order after bonding-system overlap is counted. |
| `effective_bond_order_mean` | Mean effective bond order per edge. |
| `effective_bond_order_max` | Strongest effective bond order in the molecule. |
| `edge_order_sigma_like_count` | Count of edges that behave like single bonds. |
| `edge_order_delocalized_count` | Count of edges with intermediate delocalized effective order. |
| `edge_order_double_like_count` | Count of edges that behave like double bonds. |
| `edge_order_triple_plus_count` | Count of edges that behave like triple or stronger bonds. |
| `bonding_system_count` | Number of explicit Dietz bonding systems. |
| `multicentre_system_count` | Number of bonding systems involving more than two atoms. |
| `pi_ring_system_count` | Number of explicit pi-ring bonding systems. |
| `system_member_edges_max` | Largest edge span of any nontrivial bonding system. |
| `system_shared_electrons_sum` | Total shared electrons across nontrivial bonding systems. |
| `system_shared_electrons_mean` | Average shared electrons across nontrivial bonding systems. |

## Geometry And Radial Structure

| Feature | Meaning |
| --- | --- |
| `ring_edge_fraction` | Fraction of edges that lie in rings. |
| `rotatable_bonds` | Count of rotatable single-bond-like heavy-atom edges. |
| `heavy_atom_degree_mean` | Mean degree of the heavy-atom graph. |
| `heavy_atom_degree_max` | Maximum degree of the heavy-atom graph. |
| `aprdf_edge_order_1p5a` | Short-range radial descriptor weighted by effective edge order. |
| `aprdf_system_edge_1p5a` | Short-range radial descriptor over explicit bonding-system edges. |
