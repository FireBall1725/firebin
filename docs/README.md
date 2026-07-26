# FireBin design docs

Design notes for planned work, kept next to the code. The overall product plan
lives in the workspace plan; these expand the near-term big tasks.

- [enrichment-providers.md](enrichment-providers.md) — free direct-distributor
  providers (Digi-Key, Mouser) and a self-hosted LCSC source (jlcparts); demote
  Nexar.
- [labels.md](labels.md) — scannable id labels for parts/bins/stock (PDF, ZPL,
  Brother QL) and scan-a-bin.
- [mcp-server.md](mcp-server.md) — the `firebin-mcp` server (SSE, `fbin_pat_`
  auth), tools and resources.

## Status snapshot (2026-07-23)

Built: core API (auth, inventory schema, CRUD, search, SSE), the inventory web
app (parts/stock/locations/categories, scan-to-add), the scan + EIGP 114 parser
(Nexar-only enrichment), the full Projects/BOM/assembly system (KiCad ingest,
generated render, matching, panels, multi-board, pick list, file management),
and i18n scaffolding.

Not started: everything in the three docs above, plus the iOS/Mac app and
deployment to the homelab (runs in local dev today).
