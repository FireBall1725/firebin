# Searching and displaying parameters

Backlog. Not scheduled.

## Goal

Three related asks, smallest first:

1. The command palette should match on parameter values, not just name,
   keywords, IPN and MPN.
2. The parts list should be able to show a parameter as a column, so a screen
   full of capacitors shows voltage instead of thirty rows that differ only in
   a field you cannot see.
3. Numeric comparison: "25V caps", and ideally "≥ 25V caps". Value and units
   are stored in separate columns, so the number is already there.

The third is the one worth having and the one with the real work behind it.

## What the data actually looks like

Taken from `CL10A106MA8NRNC` (10 µF 0603) in the live instance. It carries 35
parameters. Four problems show up in that single part.

**The same fact appears under three names.** All of these are on it:

```
Voltage - Rated        25 V
Voltage Rating         25 V
Voltage Rating (DC)    25 V
```

Package is duplicated the same way (`Case Code (Imperial)` = 0603,
`Case/Package` = 0603, `Package / Case` = "0603 (1608 Metric)"), as is the
dielectric (`Dielectric` and `Temperature Coefficient` both X5R) and the
mounting (`Mount`, `Mounting Type`). `parameter_templates.name` is `UNIQUE`, so
these are genuinely separate templates created by different providers, not
duplicate rows. Any facet UI that lists template names shows all three voltage
entries and asks the user to pick.

**Units are inconsistent within one part.** `Height` is 800 µm, `Thickness` is
889 µm, `Length` is 1.6 mm. Comparing across parts means normalising to a base
unit, not comparing the stored number.

**Plenty of values are not scalars.**

```
Operating Temperature   "-55°C ~ 85°C"    range, units embedded, units column empty
Size / Dimension        "0.063\" L x 0.031\" W (1.60mm x 0.80mm)"
Thickness (Max)         "0.039\" (1.00mm)"
Lifecycle Status        "Production (Last Updated: 3 weeks ago)"
Tolerance               "±20"  units "%"   leading ± defeats a plain float parse
```

Roughly half the rows parse cleanly as a number plus a unit. The other half do
not, and never will.

**The list endpoint does not return parameters at all.** `GET /parts` returns
name, description, package, IPN, MPN, stock and location. No `parameters` key.
The command palette does its faceted search client-side over the list payload,
so it cannot match parameters today no matter how the UI is written.

## Shape

**Store a parsed number alongside the text.** Add `value_num DOUBLE PRECISION`
and `unit_canon TEXT` to `part_parameters`, both nullable, populated on write
when the value parses and left null when it does not. Text stays the source of
truth and is what gets displayed; the numeric pair exists only so the database
can answer a range query with an index. Backfill in a migration, reparse on
enrichment.

Parsing rules worth stating up front: strip a leading `±`, take the number,
fold the SI prefix from the units column into the value, and record the base
unit. `10 µF` becomes `1e-5` with `unit_canon = 'F'`; `25 V` becomes `25` with
`'V'`; `800 µm` becomes `8e-4` with `'m'`. Anything with a range, a comparison
operator, or two numbers stays null and is text-only. `web/src/lib/partSort.ts`
already does natural and SI-prefix ordering for part names and is the obvious
place to lift the prefix table from, though the parser has to live server-side
to be searchable.

**Canonicalise the synonyms.** A `parameter_aliases(alias_template_id,
canonical_template_id)` mapping, seeded with the known provider variants and
editable in settings. The facet UI then offers "Voltage rating" once. Without
this, feature 3 technically works and is still unusable, because the user has
to know which of three voltage templates a given part happened to get.

**Query syntax.** Extend the existing search rather than adding a second box:

```
25v caps            bare, matches any canonical parameter equal to 25 V
voltage>=25v        explicit
capacitance>=1uf voltage>=25v package:0603
```

Operators `>=`, `<=`, `>`, `<`, `=`. Unparsed terms fall through to today's
`ILIKE` over name, keywords, IPN and MPN, so nothing that works now breaks.

**Columns in the list view.** A per-category column preference: capacitors show
capacitance, voltage, dielectric; resistors show resistance, tolerance, power.
Stored per user. Requires the list endpoint to return the parameters being
displayed, which is the same payload change feature 1 needs, so do them
together.

## Sequencing

The three asks are not independent, and the cheapest one is not first.

1. Return a requested subset of parameters from `GET /parts` (`?params=`).
   Unlocks both palette matching and list columns without any schema change.
2. Aliases, so the facets are not a mess of provider synonyms.
3. `value_num` plus `unit_canon`, the parser, the backfill, and the comparison
   syntax.

Step 1 alone gets "search for 25v caps" as a substring match, which handles
most of the day-to-day use. Step 3 is what makes `≥` work.

## Open questions

- **Does the numeric index need to be per canonical unit?** Comparing 25 V
  against 10 µF is meaningless; the query has to constrain the unit too.
- **What happens to a part whose value did not parse when the user asks for
  `≥ 25V`?** Excluded silently, or surfaced as "3 parts could not be compared"?
  Silently dropping a part you own is the worse failure for an inventory.
- **Who owns the alias list?** Seeded and then hand-edited, or inferred from
  values agreeing across templates on the same part?
- **Does this want Postgres full-text or trigram indexing** for the text half,
  given search is currently a single unanchored `ILIKE '%q%'` with no index?

## Touches

- `api`: `part_parameters` migration, a value parser, the parts list query and
  its query-param surface, search parsing.
- `web`: `CommandPalette.tsx`, the parts list views, a per-category column
  preference.
- `mcp`: `search_parts` gains the same filter syntax; its description has to
  state which operators exist or the model will invent some.
