#' Emulate CPUEL calculation from raw HH and HL data
#'
#' Reconstructs the ICES CPUEL product from raw HH and HL tables. Supports both
#' the ambiguous shortened haul key (as in CPUEL) and the unambiguous full .id key.
#'
#' Key behaviors emulating CPUEL:
#' - Filters HH to valid hauls only (HaulValidity == "V")
#' - Uses length in millimeters (not centimeters as in raw HL)
#' - By default collapses sex and developmental stage (sums over them); set
#'   collapse_sex = FALSE to retain sex in the output (needed for EVHOE, which
#'   is the only CPUEL survey where sex is preserved as F/M/U)
#' - Outputs n_haul and n_hour (CPUE in numbers per hour of hauling)
#' - Groups by (haul_key, species, length_mm [, sex if collapse_sex = FALSE])
#' - **INCLUDES ZERO-FILL**: sentinel rows for (haul, species) pairs where species
#'   was not caught. The zero-fill species pool is built from ALL HL records for
#'   valid hauls in the Survey/Year/Quarter, including presence-only records
#'   (any SpeciesValidity code, NA NumberAtLength), matching CPUEL behaviour.
#'
#' @param hh DATRAS haul header table. Defaults to dr_con("HH") if NULL.
#' @param hl DATRAS length table. Defaults to dr_con("HL") if NULL.
#' @param species Species lookup table. Defaults to dr_con("species") if NULL.
#' @param haul_key Character: "short" for ambiguous shortened key
#'   (Survey:Year:Quarter:Platform:Gear:HaulNumber), or "full" for unambiguous
#'   key (.id). Default "short" matches CPUEL output format but collapses
#'   physically distinct hauls that share the same short key (see Known Issues).
#' @param filter_survey Optional: vector of survey names to include.
#' @param filter_year Optional: vector of years to include.
#' @param filter_quarter Optional: vector of quarters to include.
#' @param filter_species Optional: vector of WoRMS AphiaID to restrict output.
#' @param collapse_sex Logical: whether to collapse sex by summing over it.
#'   Default TRUE (matches CPUEL for 7 of 8 surveys). Set to FALSE to retain
#'   sex in the output — required for EVHOE comparisons since CPUEL retains
#'   sex (F/M/U) for EVHOE. When FALSE, sex is added to the group_by key and
#'   zero-fill rows get sex = NA.
#' @param filter_species_validity Optional: SpeciesValidity codes used to filter
#'   **CPUE calculation records** (actual catches). Default "1" (full
#'   length-frequency records, the large majority of HL rows). Set to NULL for
#'   all codes. The 8 codes found in HL are: 0 (presence noted, invalid
#'   protocol), 1 (full LF), 2 (subsampled LF), 4 (presence-only), 5
#'   (presence-only, visual ID), 6 (bycatch only), 7 (presence, different gear),
#'   10 (survey-specific, mainly DYFS/SNS/BTS). Note: this filter does NOT
#'   affect the zero-fill species pool — all species present in HL for valid
#'   hauls in the SYQ are included in zero-fill regardless of this setting.
#'
#' @return A tibble with columns:
#'   - Haul key columns (depends on haul_key argument)
#'   - latin: WoRMS Latin species name
#'   - species: Common name
#'   - length_mm: Length in millimeters (0 for zero-fill rows)
#'   - n_haul: Estimated numbers per haul (summed across sex/stage); 0 for zero-fill
#'   - n_hour: CPUE in numbers per hour (summed across sex/stage); 0 for zero-fill
#'
#' @section Known issues and caveats:
#' \describe{
#'   \item{Short-key collapsing (haul_key = "short")}{
#'     Multi-vessel surveys (NS-IBTS, BITS) assign the same HaulNumber sequence
#'     to each vessel. When two physically distinct hauls share (Platform, Gear,
#'     HaulNumber), distinct() collapses them to one short key. CPUEL retains
#'     both hauls internally and only truncates the output key, so it produces
#'     more zero-fill rows. Use haul_key = "full" to avoid this. The effect is
#'     ~5-15% row undercounting for affected survey-quarters.
#'   }
#'   \item{CPUEL data vintage}{
#'     Each CPUEL row carries a DateofCalculation field indicating when ICES
#'     computed that record. If the local HH/HL tables have been updated since
#'     then, comparing against stored CPUEL will show discrepancies in species
#'     counts — not a function error. Surveys last computed in 2018 (SWC-IBTS,
#'     ROCKALL) will show the largest divergence.
#'   }
#'   \item{Residual species gaps}{
#'     Across 348 Survey-Quarter-Year combinations validated, NS-IBTS Q3 shows
#'     a consistent 1-3 aphia gap (emulation < CPUEL). Cause not fully resolved.
#'   }
#'   \item{Sex handling for EVHOE (collapse_sex default)}{
#'     With default collapse_sex = TRUE, sex is summed out for all surveys. For
#'     EVHOE, CPUEL retains sex (F/M/U), so the emulation output has fewer rows
#'     than CPUEL (F + M + U are merged into one aggregated row per haul ×
#'     species × length). Set collapse_sex = FALSE and compare sex-by-sex for
#'     exact EVHOE row matching. Zero-fill rows produced with collapse_sex =
#'     FALSE get sex = NA, consistent with CPUEL's NA rows for species where sex
#'     is not routinely recorded.
#'   }
#' }
#'
#' @examples
#' \dontrun{
#'   library(obus)
#'
#'   # NS-IBTS Q1 2025 cod using shortened (ambiguous) key
#'   cpue_short <- compute_cpue_emulation(
#'     haul_key = "short",
#'     filter_survey = "NS-IBTS",
#'     filter_year = 2025,
#'     filter_quarter = 1,
#'     filter_species = 126436
#'   )
#'   cpue_short_data <- collect(cpue_short)
#'
#'   # Same data using full unambiguous .id key
#'   cpue_full <- compute_cpue_emulation(
#'     haul_key = "full",
#'     filter_survey = "NS-IBTS",
#'     filter_year = 2025,
#'     filter_quarter = 1,
#'     filter_species = 126436
#'   )
#'   cpue_full_data <- collect(cpue_full)
#' }
#'
#' @export
compute_cpue_emulation <- function(
  hh = NULL,
  hl = NULL,
  species = NULL,
  haul_key = c("short", "full"),
  filter_survey = NULL,
  filter_year = NULL,
  filter_quarter = NULL,
  filter_species = NULL,
  collapse_sex = TRUE,
  filter_species_validity = "1"
) {

  library(dplyr)
  library(obus)

  # Set defaults
  if (is.null(hh)) hh <- dr_con("HH")
  if (is.null(hl)) hl <- dr_con("HL")
  if (is.null(species)) species <- dr_con("species")

  haul_key <- match.arg(haul_key)

  # ===================================================================
  # STEP 1: Filter HH to valid hauls (CPUEL behavior)
  # ===================================================================
  hh_valid <- hh |>
    filter(HaulValidity == "V")

  # Apply optional HH filters
  if (!is.null(filter_survey)) {
    hh_valid <- hh_valid |> filter(Survey %in% filter_survey)
  }
  if (!is.null(filter_year)) {
    hh_valid <- hh_valid |> filter(Year %in% filter_year)
  }
  if (!is.null(filter_quarter)) {
    hh_valid <- hh_valid |> filter(Quarter %in% filter_quarter)
  }

  # ===================================================================
  # STEP 2: Process HL and join with valid HH
  # ===================================================================
  hl_processed <- hl

  # Optional species filter
  if (!is.null(filter_species)) {
    hl_processed <- hl_processed |> filter(aphia %in% filter_species)
  }

  # SpeciesValidity filter: default to "1" (full length-frequency records)
  # matching CPUEL behavior
  if (!is.null(filter_species_validity)) {
    hl_processed <- hl_processed |> filter(SpeciesValidity %in% filter_species_validity)
  }

  hl_processed <- hl_processed |>
    # Filter to non-zero counts
    filter(NumberAtLength != 0) |>
    # Inner join: only keep HL records with matching valid HH records
    inner_join(
      hh_valid |>
        select(.id, DataType, HaulDuration),
      by = ".id"
    ) |>
    # Skip records with missing length
    filter(!is.na(LengthClass)) |>
    # Add length in millimeters
    dr_add_length_mm() |>
    # Add CPUE (n_haul and n_hour)
    dr_add_n_and_cpue() |>
    # Add species metadata
    dr_add_species(species)

  # Collect all processed data now
  hl_collected <- hl_processed |> collect()

  # Build species pool for zero-fill from ALL HL records in valid hauls,
  # including presence-only records (NA NumberAtLength). CPUEL zero-fills
  # for all reported species regardless of SpeciesValidity or count.
  hl_species_pool_raw <- hl
  if (!is.null(filter_species)) {
    hl_species_pool_raw <- hl_species_pool_raw |> filter(aphia %in% filter_species)
  }
  species_pool <- hl_species_pool_raw |>
    inner_join(
      hh_valid |> select(.id),
      by = ".id"
    ) |>
    dr_add_species(species) |>
    distinct(Survey, Year, Quarter, latin, species) |>
    collect()

  # ===================================================================
  # STEP 3: Aggregate by haul key, species, and length_mm (actual data)
  # ===================================================================
  if (haul_key == "short") {
    # CPUEL-style: ambiguous shortened key
    grp_vars_short <- c("Survey", "Year", "Quarter", "Platform", "Gear", "HaulNumber",
                        "latin", "species", "length_mm")
    if (!collapse_sex) grp_vars_short <- c(grp_vars_short, "sex")

    actual_data <- hl_collected |>
      group_by(across(all_of(grp_vars_short))) |>
      summarise(
        n_haul = sum(n_haul, na.rm = TRUE),
        n_hour = sum(n_hour, na.rm = TRUE),
        .groups = "drop"
      )

    # ===================================================================
    # STEP 4: Create ZERO-FILL rows (species absent from specific hauls)
    # ===================================================================
    species_per_syq <- species_pool |>
      distinct(Survey, Year, Quarter, latin, species)

    hauls_per_syq <- hh_valid |>
      distinct(Survey, Year, Quarter, Platform, Gear, HaulNumber) |>
      collect()

    full_grid <- hauls_per_syq |>
      inner_join(species_per_syq, by = c("Survey", "Year", "Quarter"))

    zero_rows <- full_grid |>
      anti_join(distinct(hl_collected, Survey, Year, Quarter, Platform, Gear, HaulNumber, latin),
                by = c("Survey", "Year", "Quarter", "Platform", "Gear", "HaulNumber", "latin")) |>
      mutate(
        length_mm = 0,
        n_haul = 0,
        n_hour = 0
      )
    if (!collapse_sex) zero_rows <- mutate(zero_rows, sex = NA_character_)
    zero_rows <- zero_rows |>
      select(any_of(c("Survey", "Year", "Quarter", "Platform", "Gear", "HaulNumber",
                      "latin", "species", "sex", "length_mm", "n_haul", "n_hour")))

    result <- bind_rows(actual_data, zero_rows)

  } else if (haul_key == "full") {
    # Full .id key: unambiguous
    grp_vars_full <- c(".id", "Survey", "Year", "Quarter", "latin", "species", "length_mm")
    if (!collapse_sex) grp_vars_full <- c(grp_vars_full, "sex")

    actual_data <- hl_collected |>
      group_by(across(all_of(grp_vars_full))) |>
      summarise(
        n_haul = sum(n_haul, na.rm = TRUE),
        n_hour = sum(n_hour, na.rm = TRUE),
        .groups = "drop"
      )

    # ===================================================================
    # STEP 4: Create ZERO-FILL rows (species absent from specific hauls)
    # ===================================================================
    species_per_syq <- species_pool |>
      distinct(Survey, Year, Quarter, latin, species)

    hauls_per_syq <- hh_valid |>
      select(.id, Survey, Year, Quarter) |>
      distinct() |>
      collect()

    full_grid <- hauls_per_syq |>
      inner_join(species_per_syq, by = c("Survey", "Year", "Quarter"))

    zero_rows <- full_grid |>
      anti_join(distinct(hl_collected, .id, latin),
                by = c(".id", "latin")) |>
      mutate(
        length_mm = 0,
        n_haul = 0,
        n_hour = 0
      )
    if (!collapse_sex) zero_rows <- mutate(zero_rows, sex = NA_character_)
    zero_rows <- zero_rows |>
      select(any_of(c(".id", "Survey", "Year", "Quarter",
                      "latin", "species", "sex", "length_mm", "n_haul", "n_hour")))

    result <- bind_rows(actual_data, zero_rows)
  }

  return(result)
}
