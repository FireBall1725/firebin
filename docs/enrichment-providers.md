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
- **Mouser** (`providers/mouser`). API key, simpler. Part-number and keyword
  search; pricing, availability, datasheet, some parameters. Lower daily cap.
- **LCSC via jlcparts** (`providers/jlcparts`). No good official LCSC API;
  instead use the `yaqwsx/jlcparts` dataset, a downloadable SQLite/JSON of the
  whole JLCPCB/LCSC catalog (part, MPN, manufacturer, category, params JSON,
  stock, price, datasheet, image). Host the DB, refresh on a schedule, query
  locally by LCSC part (C-number) or MPN. Free, offline, no per-lookup limit.
  Best fit for the EasyEDA/JLCPCB BOMs (LCSC C-numbers).
- **Nexar** (`providers/nexar`, exists). Keep, demote to fallback, off by default
  once the above are in.

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
