# Part tags

Shipped. Tags are the other names a part answers to.

## The problem

A JST SH 1.0 mm 4-pin header is `SM04B-SRSS-TB`. Nobody calls it that. It is the
Qwiic connector, or the STEMMA QT connector, depending on whether you bought the
board from SparkFun or Adafruit. Neither word appears on the part, in its
description, or in any field FireBin searched.

Before this, part search read five things: `parts.name`, `parts.keywords`,
`parts.ipn`, and any linked `manufacturer_parts.mpn`. Typing "qwiic" returned
nothing. The only way to find the connector was to already know its part number,
which is the thing you opened the search box to look up.

## Why not keywords

`parts.keywords TEXT` has existed since migration 000002, carries a trigram GIN
index, and is already searched. It also had no UI at all: nothing in `web/src`
ever rendered it, and the only writers were the MCP `update_part` tool and a raw
API PATCH.

It is still the wrong home for this, for two reasons. `keywordsFor` in
`api/internal/kicad/httplib/mapping.go` whitespace-tokenizes the field to build
the blob KiCad's Symbol Chooser searches, so "STEMMA QT" cannot survive in it as
one unit. And it is the same column the enrichment providers write, so a name you
typed shares a field with whatever Digi-Key returned. `keywords` stays the raw
provider blob. Tags sit beside it.

## Shape

Two tables, migration 000037. `tags` holds the vocabulary: one row per name, with
a `slug`, an optional palette colour, and an optional description. `part_tags` is
the join, composite primary key, both foreign keys `ON DELETE CASCADE`.

Shared rows rather than an array per part, because "Qwiic" is one thing that many
parts point at. That buys a usage count, a rename that reaches every part at once,
a merge for the day two spellings escape into use, and a page that lists the whole
vocabulary. `projects.tags TEXT[]` from migration 000012 is the older and weaker
pattern; it is left alone. The new table is named `tags`, not `part_tags`, so a
`project_tags` join can adopt the same vocabulary later without a rename.

**The slug is the load-bearing part.** It is computed in Go by `tags.Slug`:
lowercase the name, drop everything that is not a Unicode letter or digit. "STEMMA
QT", "stemma-qt" and "StemmaQT" all fold to `stemmaqt` and are therefore one tag.
A vocabulary that splits into three spellings finds a third of your parts each,
and the shared-row design is worth nothing if the sharing does not happen.

Letters are tested by Unicode class rather than an ASCII range, so "Größe" keeps
its letters instead of folding to `grse`. The cost is that "café" and "cafe" stay
distinct. That is the better failure: mangling a name is worse than declining to
merge two that genuinely differ.

Colours are palette slot names (`slate`, `red`, `amber`, `green`, `teal`, `blue`,
`violet`, `pink`), not hex values. `themes.css` defines 25 tokens per theme across
a dozen themes, and a stored hex would be unreadable in half of them. The chip CSS
mixes each slot's hue with the current `--text` for the foreground and `--panel-2`
for the fill, so one definition follows whatever theme is active.

## Search

`GET /parts` and `GET /parts/search` carried byte-identical copies of the
free-text predicate, at `repository/part.go:120` and
`repository/part_parametric.go:71`. That is the arrangement where a new
searchable field gets added to one and forgotten in the other, and "qwiic" then
finds the part from the parts page but returns nothing the moment a package
filter is typed. Both now call `partSearchClause` in `repository/part_search.go`,
which is the only place the tag arm exists.

Matching is still a single unanchored `ILIKE` per field. `tags.name` carries its
own trigram GIN index, matching the existing style.

`GET /parts?tag=<slug>` is a separate exact filter, applied in SQL rather than to
the results. `List` caps at 500 rows, so filtering the response would answer
"everything tagged Qwiic" with whatever survived an alphabetical cut. An inventory
that hides parts you own is the failure worth avoiding.

Tags load through a batched second query keyed on the scanned ids, not as a column
on `partCols`. `partCols` is read by four hand-written scan sites, and adding a
column without updating all four compiles cleanly, passes vet, and then returns
500 on the main catalogue endpoint. `repository/part_list_test.go` exists because
that reached a running server once already.

## Writes

Tags are not a field on the part PATCH. That request struct is mirrored in three
codebases, `api/internal/api/handlers/parts.go`, `mcp/internal/tools/parts.go`,
and `web/src/lib/api.ts`, and the API decodes it with `DisallowUnknownFields`. A
field added to one and missed in another writes its zero value; the header comment
on `UpdatePart` records that happening twice, once to `keywords` and once to
`reference_only`. Tags get `PUT /parts/{id}/tags` instead and stay out of that
arrangement.

Rename refuses to merge. Renaming "STEMMA QT" onto "Qwiic" returns 409 naming the
other tag, and `POST /tags/{id}/merge` is the deliberate call. Collapsing two tags
on a typo would move every part on one of them with nothing to undo it. Delete is
admin-only, because it is the one operation that reaches every part at once.

## Where a tag counts

Six places, all reading the same vocabulary.

The parts page and `GET /parts/search` match tag names in the shared clause. The
command palette filters client-side over `GET /parts`, which is why tags ride on
the list payload rather than only on a single read; a row that matched on a tag
says so in its subtitle, because searching "qwiic" and being handed
"SM04B-SRSS-TB" with no explanation reads as a misfire.

MCP gains `list_tags` and `tag_part`, and `search_parts` gains a `tag` argument.
`tag_part` adds and removes rather than replacing: a model told "call this one
qwiic" knows one name and nothing about the rest of the set, and a replace from
that position silently drops the rest. The assistant gets the same two tools,
wired in `assistant_wiring.go`, which is the whole permission boundary for what
the assistant can touch.

KiCad's Symbol Chooser does not search custom fields. Tags fold into
`keywordsFor` alongside the MPNs and SKUs, so typing "stemma" in the chooser hits.
Multi-word tags tokenize there, which is correct for that surface.

BOM ingest gets a new bottom rung in `resolveMatch`:

```
FireBin PN → project rule → MPN → supplier SKU → value+footprint → tag
```

Last, and the only rung that declines an ambiguous hit. Every rung above it names
one part by construction. A tag names a kind of part and may cover a dozen, so a
tag match is accepted only when exactly one part carries it. Auto-picking one of
five Qwiic connectors and reporting the line as matched is worse than leaving it
unmatched: an unmatched line asks to be looked at, and a wrongly matched one gets
ordered. Matching is on whole words, because a two-letter tag matched as a
substring would hit almost every line in a BOM.

## The dictionary

A user-maintained vocabulary only helps after you have already done the lookup
once. The complaint that produced this feature was not knowing which JST is the
Qwiic one, and a tag you have to know to type does not answer that.

`api/internal/tags/dictionary.json` holds four entries: Qwiic and STEMMA QT for
the JST SH 1.0 mm 4-pin header, Grove for the 4-pin 2.0 mm connector, NeoPixel for
the WS2812 and SK6812 family, and DuPont for 2.54 mm headers. Each entry matches
on MPN prefix or on a set of terms that must all appear, and each carries a `why`
string that is shown to the user. A suggestion that cannot say why it fired is
indistinguishable from a guess.

`GET /parts/{id}/tag-suggestions` returns the hits minus anything the part already
carries, folded by slug so a part tagged "stemma-qt" is not offered "STEMMA QT"
again. Nothing is ever applied without a click. A wrong suggestion you dismiss
costs a second; a wrong fact added to your inventory costs however long it takes
to notice. Dismissals are kept in `localStorage`, because declining a hint is a
preference about a hint, not a fact about the part.

The entry list is kept short on purpose. A dictionary that fires on ordinary parts
trains you to ignore it, at which point it is worse than not existing;
`TestSuggestsNothingForAnUnrelatedPart` pins that a 10k resistor, a CH340C, a 100
nF capacitor and an IDC header all suggest nothing.

## Open questions

- **Should tags be inheritable from a category?** Tagging one JST SH part does not
  tag the other four. A tag attached to a category and inherited by its parts
  would fix that, and would also make "everything tagged Qwiic" ambiguous about
  whether a part carries the tag or inherits it.
- **Should `projects.tags` move onto this table?** One vocabulary across parts and
  projects is the tidier answer. It is a data migration on a column that has
  worked since 000012, so it needs a reason beyond tidiness.
- **Does BOM tag matching want to report ambiguity?** Today a tag covering three
  parts leaves the line unmatched and silent. Saying "three parts carry this tag"
  would turn a dead end into a choice.
