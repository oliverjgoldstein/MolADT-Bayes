# FreeSolv GP Feature List

This mirrors the current fixed 30-feature Python contract for
`moladt_full30_rbf_gp`. It replaces the previous 20 SMILES-graph features plus
10 MolADT additions with a MolADT-native panel that uses explicit bonding
systems, effective bond orders, and bonding-system radial structure.

The Haskell default benchmark still consumes the broader
`freesolv_moladt_featurized` exported matrix and caps its exported-matrix RBF
GP at 30 screened features. The fixed paper-facing Python feature contract is:

- A: `atom_bag10_rbf_gp`, ten SMILES atom-count features
- B: `adjacency_graph20_rbf_gp`, twenty SMILES adjacency-graph features
- C: `moladt_full30_rbf_gp`, the 30 MolADT multigraph features below

The committed May 12, 2026 Python ablation artifact is historical for the
previous C-row feature contract. Re-run the Python `make freesolv-ablation`
target before citing updated C-row RMSE for this feature contract.

The legacy WL token vocabulary can still be generated with:

```bash
stack run moladtbayes -- freesolv-wl-system-features --output docs/freesolv-wl-token-feature-list.md
```

## Composition And Polarity

1. `weight`
2. `polar`
3. `surface`
4. `donor_count`
5. `acceptor_count`
6. `heavy_atoms`
7. `halogens`
8. `atom_count_c`
9. `atom_count_n`
10. `atom_count_o`

## Multigraph Bonding Systems

11. `sigma_edge_count`
12. `effective_bond_order_sum`
13. `effective_bond_order_mean`
14. `effective_bond_order_max`
15. `edge_order_sigma_like_count`
16. `edge_order_delocalized_count`
17. `edge_order_double_like_count`
18. `edge_order_triple_plus_count`
19. `bonding_system_count`
20. `multicentre_system_count`
21. `pi_ring_system_count`
22. `system_member_edges_max`
23. `system_shared_electrons_sum`
24. `system_shared_electrons_mean`

## Geometry And Radial Structure

25. `ring_edge_fraction`
26. `rotatable_bonds`
27. `heavy_atom_degree_mean`
28. `heavy_atom_degree_max`
29. `aprdf_edge_order_1p5a`
30. `aprdf_system_edge_1p5a`
