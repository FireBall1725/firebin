# BOM variants per board

Backlog. Not scheduled, not designed past the options below.

## Goal

One PCB, several build configurations. A Lite build without the sensors, a Pro
build with them. An optional barrel jack that half the units get. Today a board
has exactly one BOM, so the pick list, the shortfalls and the cost only ever
describe the fully populated build, and there is no way to ask "what do I need
to build three Lites."

## What blocks it today

Three things, in order of how much they cost to fix.

**The parser throws the optional parts away.** `internal/kicad/bom.go` skips any
symbol flagged `in_bom=no`, `on_board=no` or `dnp=yes` (the check at line 211,
and the footprint-side equivalent at line 127). A part marked DNP in KiCad is
not imported as an unfitted line, it is absent. So the data a variant feature
needs is not merely unlabelled, it was discarded at upload. Any version of this
feature starts with keeping those symbols and flagging them, and every existing
board needs re-importing before its optional parts reappear.

**`board_bom_lines` has no variant dimension.** One row per line per board, and
`quantity` is a plain int.

**`GET /boards/{id}/pick-list?quantity=` has nowhere to say which
configuration.** Same for the cost roll-up and the shortfall list.

## Shape options

**A. Variant as a filter over a single BOM.** New `board_variants(id, board_id,
name, is_default, position)`, plus a per-line membership table. The BOM stays
one list; a variant only decides which lines are fitted. `pick-list` takes
`?variant=`.

Cheap, and re-import keeps working because the BOM itself is unchanged. Cannot
express "Pro uses the 16MB module, Lite uses the 4MB one on the same footprint",
which is the case right next to the one being solved.

**B. Variant can override the part, not just omit the line.** Same tables, but
the membership row carries an optional `part_id` and `quantity` override. A
variant is then a sparse diff against the base BOM.

Handles the module-swap case, and A is the subset where every override is null.
More UI: each line needs a per-variant editor rather than a checkbox.

**C. A separate board per variant.** Works today with no code at all. The BOMs
drift the moment one gets re-imported and the other does not, every line is
duplicated N times, and the render and iBOM are uploaded per copy. Project match
rules are already project-scoped so those at least stay shared.

Leaning B, shipped in two steps: fitted-or-not first, overrides second, on the
same tables so the second step is additive. C is worth naming only because it is
what someone does by hand in the meantime.

## Open questions

- **Where do variants come from on import?** KiCad has no first-class assembly
  variants. People encode them in a custom symbol field, or lean on DNP for the
  single-variant case. Do we read a field like `Variant: Pro`, or is assignment
  purely a FireBin-side thing done after upload?
- **Re-import stability.** Line ids change on re-upload, so variant membership
  keyed on `line_id` is lost. `project_matches` already solves the same problem
  with a `match_key` of MPN or value plus footprint. Reference designator is the
  more natural key here, and is stable across a re-import unless the schematic
  is renumbered.
- **Panels.** `copies` is per board. Can a 6-up panel mix variants, or is a
  panel single-variant?
- **What does the default mean?** "Everything fitted" and "the variant flagged
  default" are different answers once a line is fitted in no variant at all.
- **Presentation.** One variant at a time in the pick list, or a matrix showing
  all variants side by side. The matrix is the better buying view, since what
  you actually order is the union across a planned build mix.

## Touches

- `api`: `internal/kicad/bom.go` (stop dropping DNP, carry the flag),
  `models.BOMLine`, a migration, the pick-list handler, board endpoints.
- `web`: board detail, the pick list, the upload wizard.
- `mcp`: `pick_list` gains a variant argument, and its description has to
  explain what a variant means or the model will guess.

## Dependencies

None hard. Worth doing before there are many boards, because the parser change
means a re-import to recover DNP lines, and that is cheaper at 2 boards than
at 40.
