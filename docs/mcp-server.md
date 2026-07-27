# MCP server (firebin-mcp)

Shipped. Repo: [firebin-mcp](https://github.com/FireBall1725/firebin-mcp), a
workspace sibling of `api` and `web` at `~/Repos/firebin/mcp`.

## Goal

Let an MCP client (Claude Code, the desktop app, cron jobs) query and manage the
inventory: search parts, add a part by MPN, adjust stock, list low stock, scan a
barcode, and build a pick list. Mirrors `librarium-mcp`.

## Shape

- Separate repo/binary `firebin-mcp` (Go), module
  `github.com/firelabsca/firebin-mcp`. Port 8090.
- **Transport: streamable HTTP**, served at `/mcp`, registered as
  `"type": "http"`.

  An earlier draft of this doc called for SSE on the grounds that streamable
  HTTP breaks with Claude Code through Traefik. That was the node-red finding,
  and it no longer holds: `librarium-mcp` runs streamable HTTP through the same
  `internal` ingress class today. Built and deployed on streamable HTTP.
- **Auth**: outbound to the FireBin API with an `fbin_pat_` token; inbound gated
  with an `fbin_mcp_` bearer, compared in constant time. The MCP is a thin
  client over the REST API, so it inherits the API's auth and validation.

  Scoping is by **account role, not token scopes**. `firebin-api` stores a
  `scopes` array per PAT and no middleware reads it (`ctxScopes` is set in
  `internal/api/middleware/auth.go` and read nowhere), so a PAT carries the full
  authority of its owner. The deployed token belongs to a dedicated `mcp` user
  with role `member`, which leaves `RequireAdmin` blocking `/users`,
  `/settings/*`, `/export`, `/import` and `/stock/cleanup-empty`.
- Registers as `firebin-prod`.

## Tools

Nineteen, split read and write. The catalogue and the reasoning for each
exclusion live in the package comment of `internal/tools/tools.go`.

Reads: `search_parts`, `get_part`, `list_locations`, `location_contents`,
`low_stock`, `inventory_stats`, `list_categories`, `stock_history`,
`recent_activity`, `lookup_mpn`, `list_projects`, `get_project`, `pick_list`.

Writes: `scan_barcode`, `adjust_stock`, `move_stock`, `add_part_by_mpn`,
`update_part`, `create_location`.

Beyond the original list: `list_categories` and `list_projects`/`get_project`
resolve the ids the other tools need, `lookup_mpn` reads distributor data
without writing, and `stock_history`/`recent_activity` answer "when did this
change". `create_supplier_part` was dropped; the enrichment path already
attaches distributor SKUs and pricing, so it had no caller.

Two constraints shaped the implementation:

- **The API paginates nothing.** `GET /parts` returns the whole inventory, and a
  `Part` carries its variants, parameters, manufacturer parts, supplier SKUs and
  price breaks inline. Every list tool projects to a trimmed struct, caps its
  output, and reports `total` and `truncated`.
- **`PATCH` is a full-object replacement** decoded with
  `DisallowUnknownFields`. `update_part` reads the part, maps it into the API's
  `partRequest` field by field, applies the caller's changes, then re-reads:
  the PATCH response omits the catalog, which otherwise reads as though the
  update destroyed it.

`add_part_by_mpn` is ordered around a backend constraint:
`POST /parts/{id}/enrich` returns 400 `part has no MPN to look up` unless a
manufacturer part already exists. So it enriches first (a bad part number fails
before anything is written), creates the part, attaches the MPN, applies
enrichment, books opening stock, and re-reads. Everything after creation is
best-effort and reported in `warnings[]` rather than left as an orphan.

`pick_list` keeps shortfalls and unmatched BOM lines separate. Unmatched lines
are unknown quantities, so `can_build` stays false even when nothing is short.

## Resources

`firebin://parts`, `firebin://part/{id}`, `firebin://locations`,
`firebin://location/{id}`, `firebin://categories`, `firebin://stats`. These pass
the API's JSON through untrimmed, unlike the tools. A tool is called in a loop
and has to stay cheap; a resource is pulled deliberately by a client that wants
the whole row.

## Deploy

Runs beside the API in `app-firebin` with its own Deployment, Service, Ingress,
and a 1Gi Longhorn PVC at `/data`. Reaches the API in-cluster at
`http://firebin-api:8080`, not through `firebin-web`'s nginx. Native Go MCP, so
no supergateway sidecar (unlike the node-red case).

Chart: `homelab-applications/firebin-mcp`. ArgoCD app:
`homelab-config/apps/firebin-mcp`. Two SealedSecrets carry the tokens.

## Dependencies

- The API deployed and reachable, with an `fbin_pat_` token minted for the MCP.
- The enrichment providers, for `add_part_by_mpn` and `lookup_mpn` to return
  good data.
