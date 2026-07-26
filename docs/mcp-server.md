# MCP server (firebin-mcp)

## Goal

Let an MCP client (Claude Code, the desktop app, cron jobs) query and manage the
inventory: search parts, add a part by MPN, adjust stock, list low stock, scan a
barcode, and build a pick list. Mirrors `librarium-mcp`.

## Shape

- Separate repo/binary `firebin-mcp` (Go), a workspace sibling of `api` and
  `web`. Port 8090.
- **Transport: SSE**, not streamable HTTP. Through Traefik in the homelab,
  streamable HTTP breaks with Claude Code while SSE holds (same finding as the
  node-red MCP). Serve `/sse`.
- **Auth**: outbound to the FireBin API with a scoped `fbin_pat_` token; inbound
  gated with a bearer token. The MCP is a thin client over the REST API, so it
  inherits the API's auth and validation.
- Registers as `firebin-prod`.

## Tools

- `search_parts(query, category?)` -> matching parts with stock.
- `get_part(id)` -> full part (params, manufacturer parts, stock).
- `add_part_by_mpn(mpn, quantity?, location?)` -> enrich (via the providers) and
  create; optionally book initial stock.
- `scan_barcode(payload)` -> parse EIGP 114, resolve or draft a part.
- `adjust_stock(part, delta, location?, note?)` -> add/remove/count.
- `list_locations()` / `location_contents(barcode|id)` -> scan-a-bin.
- `low_stock()` -> parts at or below their minimum.
- `create_supplier_part(...)`.
- `pick_list(board_id, quantity)` -> the assemble pick list.

## Resources

Read-only views for parts, locations, stock, and a stats summary, so a client
can browse without a tool call.

## Deploy

Runs beside the API on the homelab (its own Deployment + Service + IngressRoute),
SSE through Traefik. Native Go MCP, so no supergateway sidecar is needed (unlike
the node-red case). Depends on the API being deployed and reachable.

## Dependencies

- The API deployed (or reachable) with a `fbin_pat_` token minted for the MCP.
- The enrichment providers, for `add_part_by_mpn` to return good data.
