# Architecture Decision Records

Lightweight ADRs for `reaper-scripts`. One file per decision, numbered
sequentially, never renumbered or deleted — superseded decisions get a
new ADR that links back.

## Format

Each ADR is a single Markdown file: `NNNN-short-title.md`.

- **Status**: `proposed` | `accepted` | `superseded by ADR-NNNN` | `rejected`
- **Context**: the problem/constraints that forced a decision
- **Decision**: what was decided, stated plainly
- **Consequences**: what this makes easier/harder, and open follow-ups

Unlike `docs/` and `claudedocs/` (gitignored scratch/backlog notes), ADRs
are committed — they're the durable record of *why*, not working notes.

## Index

| # | Title | Status |
|---|---|---|
| [0001](0001-multiband-crossover-filter-topology.md) | Multiband crossover/filter topology for restoration | accepted |
