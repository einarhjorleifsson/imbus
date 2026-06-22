# IMBUS Project — WP2 Data Standardisation

## Project overview

IMBUS (Implementing More and Better Use of ICES Survey Data) is a 24-month EU-funded project
(Sep 2025 – Aug 2027). This repository is the documentation site for **WP2 — Data
Standardisation**, led by Einar Hjörleifsson (subcontracted to DTU Aqua).

The companion R package `{obus}` (separate repo at `~/R/Pakkar/obus/`) implements the
technical data access and processing functions described here. **{obus} is explicitly
experimental and interim** — a proof-of-concept for the WP2 period. Its functionality is
intended to be upstreamed into the official `icesDatras` R package under WP5/D5.3 (M18).

## Deliverable framework

| Deliverable | WP | Type | Due | Description |
|-------------|-----|------|-----|-------------|
| D2.1 | 2 | R | M6 | User requirements — **delivered April 2026** (n=55) |
| **D2.2** | 2 | R | **M11** | Data formats and meta-data (main WP2 text deliverable) |
| D2.3 | 2 | DATA | M12 | Integrated data product (parquet files) |
| D2.4 | 2 | DATA | M12 | Data on ICES open access web portal |
| D5.1 | 5 | DATA | M6 | ICES data supply for WP2 quality assurance (feeds D2.3) |
| D5.3 | 5 | DEM | M18 | IMBUS–DATRAS GitHub repo; integrates D2.3/{obus} into `icesDatras` |

D2.2 and D2.3 are **separate documents** (`deliverables/D2.2_data_formats_metadata.qmd` and
`deliverables/D2.3_imbus_product_specification.qmd`):
- **D2.2** documents the current DATRAS exchange format (HH/HL/CA) field by field, its
  metadata, and known issues.
- **D2.3** is the technical specification for the proposed IMBUS parquet product, data tiers,
  {obus} access, and CPUE pathways.

D2.4 is a data deliverable (deployment to the ICES portal) with no separate text document.
D5.3 (ICES, M18) is the long-term institutionalisation step that supersedes the interim
{obus}/personal-server arrangement.

## Repository structure

**Deliverables:**
- `deliverables/D2.1_user_requirements.qmd` — **Stub** (link to delivered D2.1; content hosted externally)
- `deliverables/D2.2_data_formats_metadata.qmd` — Main deliverable: field-by-field format
  specification and metadata for ICES DATRAS exchange tables (HH, HL, CA). **DRAFT, due July 2026.**
- `deliverables/D2.3_imbus_product_specification.qmd` — Companion deliverable: technical
  specification for the proposed IMBUS parquet product, data tiers, {obus} access, CPUE pathways.
- `deliverables/D2.2 data formats meta-data descriptions.docx` — Word template with chapter
  hierarchy that D2.2 follows.

**Background and context:**
- `IMBUS/IMBUS_proposal_summary.qmd` — Proposal context, WP2 objectives, user requirements
  from D2.1 (n=55 survey respondents).
- `IMBUS/wp2_progress_review.qmd` — WP2 progress assessment against proposal milestones (June 2026).

**DATRAS documentation and analysis:**
- `DATRAS/DATRAS_FAQ.qmd` — Restructured ICES DATRAS FAQs (v3.0, 2014) with updated field names,
  DataType P coverage, current survey list, and [IMBUS]-marked additions from WP2.
- `DATRAS/DATRAS_Technical_Reference.qmd` — DATRAS field names, types, units, sentinel values.
- `DATRAS/issues.qmd` — **Consolidated document** (June 2026): known data issues, format ambiguities,
  QC findings, HL constancy violations, survey quirks, and product coverage limitations. Combines
  content from prior `DATRAS_data_issues.qmd` and `miscellaneous.qmd` with reproducible R code.
- `DATRAS/sex_determination.qmd` — Analysis of sex recording patterns across surveys (supports
  the `sex`/`SpeciesSex` naming decision in D2.2).
- `DATRAS/cpue_derivation.qmd` — Analysis comparing ICES CPUEL product vs HL-derived CPUE;
  documents three structural problems with CPUEL and proposes `dr_cpue_length()`.

**Meetings and governance:**
- `meetings/20260601_WP2-WP5.qmd` — Meeting minutes and action items (1 June 2026).

**Supporting files:**
- `IMBUS/IMBUS_documentation/Proposal-SEP-211134616.pdf` — Full EMFAF proposal.
- `_quarto.yml` — Quarto website config; renders to `_site/` with navbar structure.
- `reference.docx` — Word template for DOCX output.
- `AGENTS.md` — This file; guidance for AI agents on project structure and conventions.
- `README.md` — Project overview and rendering instructions.

## Data sources

ICES DATRAS exchange tables accessed via `{obus}`:

| Table | Description | Access |
|-------|-------------|--------|
| HH | Haul Header — one row per trawl haul | `dr_con("HH")` or `dr_get("HH", ...)` |
| HL | Haul-level Length — catch by length class | `dr_con("HL")` or `dr_get("HL", ...)` |
| CA | Catch-at-age — individual biological samples | `dr_con("CA")` or `dr_get("CA", ...)` |
| LT | Litter Assessment (supplementary) | `dr_con("LT")` |
| `by_length` | IMBUS D2.3 pre-computed CPUE-by-length (Tier 2) | `dr_con("by_length")` |
| `by_tow` | IMBUS D2.3 pre-computed catch totals per haul (Tier 2, forthcoming) | `dr_con("by_tow")` |

- `dr_con()` returns a lazy DuckDB connection to parquet files (preferred for large queries).
- `dr_get()` downloads and collects into memory; wraps `icesDatras::getDATRAS()` for XML source.
- Parquet files hosted at `https://heima.hafro.is/~einarhj/datras/` (**interim; personal
  server**). Transfer to ICES infrastructure planned under D2.4/D5.3.
- Coverage: 29 surveys, 1965–present, Northeast Atlantic.

### `by_length` product schema

Generated by `data-raw/DATAPRODUCT_by_length.R`. One row per `.id × latin × length_cm`.

| Column | Type | Description |
|--------|------|-------------|
| `.id` | chr | 8-field composite haul key |
| `Survey` | chr | Survey acronym |
| `Year` | int | Year |
| `Quarter` | int | Quarter (1–4) |
| `latin` | chr | WoRMS accepted Latin name |
| `species` | chr | Common name |
| `SpeciesValidity` | chr | Record type — **filter before analysis**; typically retain `"1"` only |
| `length_cm` | dbl | Standardised length in cm |
| `accuracy` | dbl | Length measurement resolution in cm |
| `n_haul` | dbl | DataType-corrected numbers per haul |
| `n_hour` | dbl | DataType-corrected numbers per hour |

**Derivation:** HL `inner_join`'d to valid-haul HH (`HaulValidity == "V"`); the
`inner_join` (not `left_join`) also provides `DataType` and `HaulDuration` for CPUE
arithmetic and ensures only valid hauls are retained. `LengthClass` NA rows and
`NumberAtLength == 0` rows removed. Sex and developmental stage collapsed (summed).
No zero-fill — species absent from a haul do not appear. Species names joined from
`dr_get("species")` on `aphia`.

**No `SpeciesValidity` filter is applied.** `SpeciesValidity` is retained as a grouping
variable rather than pre-filtered to `"1"`. This keeps records of different types (e.g.
full length-frequency rows alongside totals-only rows for the same species and haul)
separate and visible. Without this, mixed types would be silently summed. 449 `.id ×
latin × length_cm` groups have more than one distinct `SpeciesValidity` value in the
current product. All 449 pair `"1"` with one other type: `{1, 5}` (410 groups) and
`{1, 10}` (39 groups). For most analyses, filter to `SpeciesValidity == "1"` after collecting.
See D2.2 §SpeciesValidity vocabulary (`#vocab-specval`) for the full code list and
§HL grouping key constancy violations for survey-specific co-occurrence statistics.

### `by_tow` product schema

Forthcoming (`data-raw/DATAPRODUCT_by_tow.R`, not yet written). One row per `.id × latin`.
The tow-level complement to `by_length`: DataType-corrected catch totals collapsed across
all length classes. Intended for biomass-index and catch-in-weight workflows.

| Column | Type | Description |
|--------|------|-------------|
| `.id` | chr | 8-field composite haul key |
| `Survey` | chr | Survey acronym |
| `Year` | int | Year |
| `Quarter` | int | Quarter (1–4) |
| `latin` | chr | WoRMS accepted Latin name |
| `species` | chr | Common name |
| `n_haul` | dbl | DataType-corrected numbers per haul (sum across all lengths) |
| `n_hour` | dbl | DataType-corrected numbers per hour |

**Derivation (intended):** same `inner_join` pattern as `by_length` (valid hauls only,
`DataType`/`HaulDuration` from HH); group by `.id × latin` and sum `n_haul`/`n_hour`
across all length classes. Sex and developmental stage collapsed. No zero-fill.

## {obus} package — interim status

`{obus}` is **experimental** (lifecycle badge) and serves as the proof-of-concept
implementation for WP2. Key points:

- Builds on `icesDatras` (official ICES package, which it imports) — adds parquet/DuckDB
  access, unified naming, DataType-aware arithmetic, and QC checks.
- The most transferable elements for D5.3 upstreaming: `dr_lookup_fields` naming map,
  DataType arithmetic in `dr_add_n_and_cpue()`, and the composite haul key (`.id`).
- At M18 (D5.3), {obus} will either be archived or become a thin wrapper around `icesDatras`.

## Key {obus} functions

- `dr_add_id()` — adds `.id` composite key (Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber).
- `dr_add_n_and_cpue()` — computes `n_haul` and `n_hour` from `NumberAtLength × SubsamplingFactor`, handling DataType C/R/S/P correctly. Safe for size-stratified subsampling.
- `dr_add_length_mm()` — converts `LengthClass` to `length_mm`.
- `dr_add_length_cm()` — converts `LengthClass` to `length_cm` (with `accuracy` field).
- `dr_check_*()` — QC check family; returns tibble with check results.
- `dr_hl_length()` — **proposed**; derives the standardised HL length-frequency table (with `sex`, `DevelopmentStage`, `SpeciesCategory`, `NumberAtLength`, `SubsamplingFactor` retained) lazily from raw HH + HL. Intended for power users needing sex/stage-resolved analysis. Supersedes the proposed `HL_length.parquet` stored file.

## Recommended CPUE derivation

**For most users (length-frequency CPUE):** use `dr_con("by_length")` — the pre-computed
IMBUS CPUE-by-length product covering all 29 surveys. No CPUE arithmetic needed.

**For catch totals per haul:** use `dr_con("by_tow")` (forthcoming) — tow-level counts and
numbers-per-hour collapsed across length classes. Natural input for biomass-index and
catch-in-weight workflows.

**When you need sex-resolved or zero-filled CPUE**, or are working with a custom
survey/species/year subset: use `dr_cpue_length()` (defined in
`products/cpue_derivation.qmd`, candidate for inclusion in `{obus}`).

Use either `by_length` or `dr_cpue_length()` in preference to the ICES CPUEL product.
Rationale for avoiding CPUEL:

1. **CPUEL covers only 8 of 30 surveys** (BITS, EVHOE, IE-IGFS, NS-IBTS, ROCKALL, SCOROC,
   SCOWCGFS, SWC-IBTS). The other 22 must use HL-derived CPUE regardless.
2. **CPUEL uses a shortened haul key** (omits `Country` and `StationName`), making 2,400+
   short keys ambiguous — joining CPUEL back to HH returns wrong metadata for those hauls.
   CPUEL computes correctly internally but the truncated output key is unreliable for joins.
3. **CPUEL does not filter by `HaulValidity`** — includes non-valid hauls. For BITS, 96% of
   the extra hauls were already non-valid when CPUEL was computed (not a staleness issue).
4. **CPUEL sets `sex = NA`** for all surveys except EVHOE, discarding sex-at-length.

```r
dr_cpue_length <- function(hh, hl,
                           collapse_sex   = TRUE,
                           collapse_stage = TRUE) {
  # hh: lazy HH table pre-filtered to desired survey/year/quarter, HaulValidity=="V"
  # hl: lazy HL table pre-filtered to a single target species (e.g. filter(aphia==126436))
  # Returns lazy DuckDB table: .id, length_mm, [sex], [DevelopmentStage],
  # n_haul, n_hour. Zero-catch hauls: length_mm=0, n_haul=0, n_hour=0.
  group_vars <- c(".id", "length_mm")
  if (!collapse_sex)   group_vars <- c(group_vars, "sex")
  if (!collapse_stage) group_vars <- c(group_vars, "DevelopmentStage")
  hh |>
    select(.id, HaulDuration, DataType) |>
    left_join(
      hl |>
        dr_add_length_mm() |>
        select(.id, length_mm, sex, DevelopmentStage,
               NumberAtLength, SubsamplingFactor),
      by = ".id"
    ) |>
    dr_add_n_and_cpue() |>
    group_by(across(all_of(group_vars))) |>
    summarise(n_haul = sum(n_haul, na.rm = TRUE),
              n_hour = sum(n_hour, na.rm = TRUE), .groups = "drop") |>
    mutate(length_mm = coalesce(length_mm, 0),
           n_haul    = coalesce(n_haul,    0),
           n_hour    = coalesce(n_hour,    0))
}
```

Always use `HH |> left_join(HL)` (never the reverse) to preserve the zero-station concept —
hauls with no catch for the target species appear as `length_mm=0, n_haul=0, n_hour=0`.
Output is minimal (`.id` + CPUE columns only); join to `dr_con("HH")` on `.id` for metadata.

## D2.2 document structure

D2.2 documents only the current DATRAS format; the proposed IMBUS product lives in the
separate D2.3 document.

1. **Executive Summary** — 5 principal documentation findings (naming conventions, HL
   structure, sentinel −9, AphiaID resolution, DataType); scope; pointer to D2.3
2. **Background and Purpose** — DATRAS context, WP2's 4 objectives (D2.2 = objectives 2 & 3)
3. **ICES DATRAS Data Formats and Meta-data Descriptions** —
   - **Data Formats** — field-by-field for HH, HL, CA (each: haul-id/join key, then
     content subsections, then Administrative); CPUE and derived products table
   - **Meta-data Descriptions** — surveys covered (29-survey table), field & vocabulary
     reference (`dr_lookup_fields`/`dr_lookup_vocabulary`), controlled vocabulary tables
   - **Current Issues** — column naming, DataType field, cross-table ambiguities, HL
     grouping key constancy violations, other known data issues
4. **Discussion and Conclusions** — stub
5. **Further Work** — 2 open items (Discussion/References drafting; per-survey fact sheets)
6. **References** — stub
7. **Annex 1** — Related documents and resources
8. **Appendix 2** — scope statement, build-script deviations, verification code

`.id` components are documented in their natural subsections (e.g. `Year`/`Quarter` under
Temporal, `Survey`/`Country`/`Platform` under Administrative), each tagged "(`.id` component)",
rather than in one haul-id table. HL and CA reference HH for the shared eight fields.

Uses `number-sections: true` (no hard-coded section numbers — cross-references use anchors).
Dual output: HTML + DOCX.

## Key data findings documented in D2.2

### HL constancy assumptions

The HL sampling protocol fields are **not** strictly constant within the natural grouping key
(`.id × aphia × sex × DevelopmentStage × SpeciesCategory`):

- **SpeciesValidity** varies in 2,786 groups (mostly BTS and Can-Mar) — different record types
  (e.g. full length-frequency + totals-only rows) co-occur within a group.
- **SubsamplingFactor** varies in 389 groups due to **size-stratified subsampling** — small and
  large fish subsampled at different rates. By DataType: P (293 groups — all GB-SCT, the
  intended encoding, across NS-IBTS/SCOWCGFS/SCOROC), R (95 groups — predominantly DK from
  2024 onward, plus a few NL/BE/NO), and C (1 group); 293 + 95 + 1 = 389.
- **TotalNumber** (and `SpeciesCategoryWeight`) also vary by stratum (104 groups) as a consequence.
- Safe formula: `n_haul = sum(NumberAtLength * SubsamplingFactor)` per group.

### Surveys covered

29 surveys documented with statistics (year range, valid hauls, distinct AphiaIDs) generated from
`dr_con("HH")` and `dr_con("HL")`. NS-IBTS largest (36,566 hauls from 1965); CODS-Q4 smallest
(42 hauls from 2024). BTS most species-rich (1,012 AphiaIDs). A 30th entry `NS-IBTS_UNIFtest`
(5 hauls, 2012–2021) exists in the parquet but is a test survey — to be filtered upstream.

## Open work

**D2.2 (Data Formats and Metadata):**
- **Discussion and References** sections are stubs (Further Work is drafted, 2 items).
- **Proposed intermediate parquet products** are specified in **D2.3**, not D2.2; the HL
  splitting design (HL_catch / HL_length) is deliberately deferred there — expect a different proposal.
- **Action point A2:** Confirmation pending from Vaishav Soni and Adrianna Villamor on
  `SubsampledNumber`/`SubsampleWeight` semantics and `DevelopmentStage` prevalence (both HL).

**D2.3 (Data Product Specification):**
- Unique content from garbage-piled `products/datras_field_reference_v2.qmd` (LT field table, Length Units,
  area standardisation, QC checks, drop-or-derive reference, {obus} quick reference) still needs
  a permanent home — likely as appendix/reference section in D2.3.

## Open issues — {obus} naming vs IMBUS standard

- **`data-raw/` scripts not yet sourced:** `data-raw/DATASET_lookup_fields.R` and
  `data-raw/DATASET_vocabulary.R` in the {obus} repo may not have been run, meaning
  `dr_lookup_fields` and `dr_lookup_vocabulary` may not reflect the current ICES web
  services. Source both scripts to regenerate before D2.3 delivery.

## Column naming

**Both `dr_con()` and `dr_get()` return standardised names** — {obus} applies the
`dr_lookup_fields` mapping on the way out regardless of source. When writing verification or
analysis code against either access path, use those names (`aphia`, `sex`, `SubsamplingFactor`,
`NumberAtLength`, `TotalNumber`, …). Legacy names appear only in the "Old name" columns of the
D2.2 field tables and in raw XML/disk that {obus} users never touch directly.

Most standardised names are the ICES "new" field names (legacy → standard, e.g. `SubFactor`
→ `SubsamplingFactor`). **Two are IMBUS-specific interim deviations from the ICES "new" names**,
adopted because the ICES names are themselves inconsistent (truth lives in
`~/R/Pakkar/obus/data-raw/DATASET_lookup_fields.R`):

- **`sex`** — ICES `getDatrasFieldList` names the same concept differently per table:
  `SpeciesSex` (HL) and `IndividualSex` (CA), both on the same vocabulary. IMBUS uses `sex`
  for both.
- **`aphia`** — the datacenter-resolved WoRMS id is absent from the upload schema and is named
  `Valid_Aphia` in HL/CA but `AphiaID` / `ValidAphiaID` in the derived products (CPUEL/CPUEA/IDX).
  IMBUS uses `aphia` everywhere.
- Also `Age` (ICES `getDatrasFieldList` "new" = `IndividualAge`, but `getDATRAS()` and the
  parquet return `Age`).

`sex` and `aphia` are **interim** — the upstream inconsistency must be resolved by the ICES
Datacenter / external experts, and the IMBUS names may change once it is. Flagged in D2.2
§"IMBUS interim canonical names" (`#sec-interim-names`) and Appendix 2 deviations.

## Recent changes (June 2026)

**File restructuring:** Consolidated and reorganised the repository to reduce orphans and
clarify document scope (June 22, 2026):
- `background/` → `IMBUS/` — proposal summary and progress review now in a single directory
- `products/` → `DATRAS/` — CPUE and product analysis belong with DATRAS documentation
- `DATRAS_data_issues.qmd` + `miscellaneous.qmd` → `issues.qmd` — consolidated into one
  comprehensive document covering format ambiguities, known data issues, QC findings, survey quirks
- `DATRAS_Technical_Reference.md` → `.qmd` — converted to Quarto format
- Removed empty `background/` and `products/` directories

**DATRAS FAQ update (June 22, 2026):**
- Updated header to announce `[IMBUS]` marking scheme for IMBUS-added content
- Moved `LengthClass = NA` question (IMBUS addition) to new `## IMBUS Additions` section
- Added `[IMBUS]` callout documenting DataType R size-stratified submission empirical finding
- Updated version history to "4.0 (IMBUS)"

**Consolidated issues.qmd (June 22, 2026):**
- Merges empirical EDA findings (`DATRAS_data_issues.qmd`) with QC checks (`miscellaneous.qmd`)
- Organized into 5 logical sections: naming/ambiguities, data issues, HL violations, HL structure,
  survey quirks, product coverage
- Added reproducible R code for all findings
- Cross-referenced to D2.2 for authoritative documentation
- Fixed syntax errors (e.g., `filter_out()` → proper dplyr syntax)

**Navbar structure (June 22, 2026):**
- New `Background` menu: Project Overview, WP2 Progress Review
- Expanded `DATRAS` menu: now covers FAQ, Technical Reference, Sex determination, CPUE derivation,
  Data issues and QC
- New `Meetings` menu
- Removed dead links, renamed menu items for clarity

## Rendering

```bash
quarto render deliverables/D2.2_data_formats_metadata.qmd --to docx
quarto render   # full website
quarto preview  # local preview
```
