# FireBin design docs

Design notes for planned work, kept next to the code. The overall product plan
lives in the workspace plan; these expand the near-term big tasks.

- [enrichment-providers.md](enrichment-providers.md) — free direct-distributor
  providers (Digi-Key, Mouser) and a self-hosted LCSC source (jlcparts); demote
  Nexar.
- [labels.md](labels.md) — scannable id labels for parts/bins/stock (PDF, ZPL,
  Brother QL) and scan-a-bin.
- [mcp-server.md](mcp-server.md) — the `firebin-mcp` server (streamable HTTP,
  `fbin_pat_` auth), tools and resources. Shipped.
- [bom-variants.md](bom-variants.md) — one PCB, several build configurations
  (Lite vs Pro, optional sensors). Backlog, options only.

## Status snapshot (2026-07-26)

Built: core API (auth, inventory schema, CRUD, search, SSE), the inventory web
app (parts/stock/locations/categories, scan-to-add), the scan + EIGP 114 parser,
the full Projects/BOM/assembly system (KiCad ingest, generated render, matching,
panels, multi-board, pick list, file management), i18n scaffolding, Digi-Key
enrichment, and the MCP server.

Deployed to the homelab: `firebin-api`, `firebin-web` and `firebin-mcp` all run
in `app-firebin`.

Not started: the remaining enrichment providers, labels, BOM variants, and the
iOS/Mac app.
