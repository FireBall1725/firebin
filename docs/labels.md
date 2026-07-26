# Labels and scan-a-bin

## Goal

Print scannable labels for parts, bins/locations, and stock items, and scan a
bin to list its contents. This is what makes a physical inventory usable: you
label a drawer, and later scan it to see what is in it or to confirm you pulled
the right part.

## Scannable IDs ("ID Anything")

Parts, locations, and stock items already carry a `barcode` column (unique,
nullable). A label prints that id as both a 1D and a 2D symbol:

- **Code 128** for 1D scanners.
- **QR or Data Matrix** for phone cameras and 2D scanners.

Payload: a prefixed id so a scan resolves unambiguously, e.g. `fbin:loc:<uuid>`,
`fbin:part:<uuid>`, `fbin:stock:<uuid>`. A single lookup endpoint parses the
prefix and returns the entity. Auto-generate the `barcode` on create when empty.

## Label rendering (`internal/labels`)

Render a template (part / location / stock) to a chosen format:

```go
type Label struct {
    Title    string   // part name / bin name
    Subtitle string   // package, category, or location path
    Fields   []string // extra lines (value, MPN, qty)
    Code     string   // the scannable id payload
    Size     LabelSize
}
```

Backends:

- **PDF** (any printer). A single label or an N-up sheet on US Letter / A4.
  Universal; ship this first.
- **Zebra ZPL** (text). Emit ZPL for the label; send to a networked Zebra.
  Small effort after PDF.
- **Brother QL** (raster). Build the raster + the QL protocol for common tape
  sizes (29mm, 62mm continuous and die-cut). More work; last.

Barcode generation: a Go library (e.g. `boombuler/barcode`) for Code128 / QR /
Data Matrix, drawn into the PDF/PNG or encoded for ZPL.

## API

- `GET /parts/{id}/label?format=pdf&template=default&size=...` (and the same for
  locations and stock items). Returns the rendered bytes.
- `POST /labels/render` for batch / N-up sheets: a list of ids + template +
  format.
- Default templates per entity and per common label size; a place to store
  custom templates later.

## Scan-a-bin

`GET /locations/scan?barcode=...` already exists and returns the bin. Extend the
response to include its contents (`ListForLocation`) and surface it as a scan
mode in the web/app: scan a drawer, see the parts and quantities in it.

## Print delivery

The API produces the bytes; delivery depends on the printer:

- **PDF**: download and print from the browser (works anywhere, no driver).
- **Zebra / Brother QL on the network**: POST the ZPL/raster to the printer's IP,
  or to a small print endpoint configured in settings. Browsers cannot talk to
  USB label printers directly, so networked printers or a print agent are the
  path for the homelab.

## Web

- A "Print label" action on part, location, and stock views, with a preview.
- A label designer is a later nicety; start with fixed default templates.

## Scope phasing

1. Scannable id generation + the resolve endpoint.
2. PDF single + N-up (universal).
3. Scan-a-bin (extends the existing location scan).
4. ZPL, then Brother QL raster.

## Dependencies

Networked label printer(s) for direct printing; PDF path needs nothing.
