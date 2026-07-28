# Enrichment providers

## Goal

Enrich a part (parameters, datasheet, image, pricing, stock) from its MPN or a
scanned distributor SKU, cheaply and with good data. Today only the Nexar
(Octopart) provider exists; its free tier is 100 lookups/month and the cheap
fields are thin. Add free direct-distributor providers and a self-hosted LCSC
source, and demote Nexar to a last resort.

## Provider model

One interface, several backends (`internal/providers/`):

```go
type Provider interface {
    Name() string
    // ByMPN enriches from a manufacturer part number.
    ByMPN(ctx context.Context, mpn string) (*Enriched, error)
    // BySKU enriches from a distributor SKU (the exact hit after a scan).
    BySKU(ctx context.Context, sku string) (*Enriched, error)
    Enabled() bool
}
```

Normalized result (map each provider's fields onto this):

```go
type Enriched struct {
    MPN          string
    Manufacturer string
    Description  string
    CategoryHint string
    Package      string            // footprint, e.g. 0603, SOT-23
    Parameters   []Param            // {Name, Value, Unit}
    DatasheetURL string
    ImageURL     string
    Suppliers    []SupplierRef      // {Supplier, SKU, URL, MOQ, Pricing[]}
    Stock        int
}
```

`scrubEnriched` (the GBK-mojibake fix) already runs on descriptions; keep it in
the normalization step for every provider, not just Nexar.

## Providers to add

- **Digi-Key** (`providers/digikey`). OAuth2 client-credentials. Product search +
  product details endpoints. Richest single source: full parametric attributes,
  datasheet, image, price breaks, live stock. Config: client id + secret. This
  is the default for MPN lookups.
- **Mouser** (`providers/mouser`). BUILT. API key, no OAuth. Part-number
  search; pricing, availability, datasheet, some parameters. Lower daily cap.
- **LCSC** (`providers/lcsc` or `providers/jlcparts`). Deferred, not started.
  See "LCSC, measured" below: the assumption this line was written on has
  changed, and the jlcparts route is a great deal more work than the other two
  providers.
- **Nexar** (`providers/nexar`, exists). Keep, demote to fallback, off by default
  once the above are in.

## LCSC, measured (2026-07-27)

This section replaces the original "no good official LCSC API" claim, which is
no longer accurate.

**There is now an official LCSC API.** Documented at `lcsc.com/docs/openapi`,
with access granted by application at `lcsc.com/agent` against an existing LCSC
account. LCSC does not publish the eligibility terms, so whether a personal
account qualifies is unknown until someone applies. If it is granted, LCSC
becomes another ~300-line provider like Digi-Key and Mouser, and none of the
work below is needed.

**The jlcparts dataset is real but heavy.** Measured against the repo's
`gh-pages` branch on 2026-07-27:

- 4,080 files, **1.27 GB compressed**, several GB once expanded.
- A 50 MB-chunked split zip (`cache.z01`…) plus **2,298** gzipped JSONL chunks,
  one per category shard.
- No GitHub releases; the data is the branch. `yaqwsx/jlcparts` is MIT, 803
  stars, and actively maintained (pushed the day these numbers were taken).

So "host the DB, refresh on a schedule" means a download pipeline, several GB on
the Longhorn volume, a River refresh job, and a local index by C-number and MPN.
That is a subsystem, not a provider. Note also that the code is MIT but the data
is JLCPCB's catalogue, which is a separate question worth answering before
redistributing it inside a self-hosted product.

**Sequence when this comes up again:** apply for the official API first, because
it costs one form and can remove the entire pipeline. Fall back to jlcparts only
once refused, knowing the cost was necessary. A third option, the unofficial
`lcsc.com/api/products/search` endpoint used by community tools, needs a CSRF
token and cookies and is not something to build a product feature on.

## Resolution strategy

The scan flow already knows the distributor and SKU (EIGP 114), so skip the
aggregator:

- **Scan** (`/scan`): route by the parsed distributor to that provider's
  `BySKU` for an exact hit. Digi-Key SKU to Digi-Key, Mouser to Mouser, LCSC to
  jlcparts.
- **Bare MPN** (manual add / `add_part_by_mpn`): try enabled providers in
  priority order (Digi-Key, Mouser, jlcparts, then Nexar); first good hit wins.
  Optionally merge missing fields from a second provider.

Cache-first: store enrichment results keyed by (provider, mpn/sku) so repeated
lookups do not spend quota. A short TTL on pricing/stock, long on parametrics.

## Config and rollout

- Per-provider secrets and an on/off toggle in instance settings; a configurable
  priority order.
- Rollout: Digi-Key first (richest), then jlcparts (covers the LCSC parts we
  already ingest), then Mouser, then flip Nexar off by default.

## Open questions

- Enrich synchronously on scan vs. as a background job (River is not wired yet).
  Start synchronous with a cache; move to a job if latency or quotas bite.
- How to host/refresh the jlcparts DB (pull their released build on a cron vs.
  build it ourselves). Pulling the release is simpler.

## Dependencies

Independent of deployment. jlcparts needs somewhere to store the DB file
(the API's attachment/data volume).
