#' Comprehensive CPUEL validation: all Survey-Quarter-Year combinations
#' Runs emulation once per Survey-Quarter (all years), then compares row-by-row
#' with CPUEL aggregated at the Survey x Quarter x Year level.

library(tidyverse)
library(obus)

source("DATRAS/compute_cpue_emulation.R")

sq_combos <- dr_con("CPUEL") |>
  distinct(Survey, Quarter) |>
  arrange(Survey, Quarter) |>
  collect()

results <- vector("list", nrow(sq_combos))

for (i in seq_len(nrow(sq_combos))) {

  sv  <- sq_combos$Survey[i]
  qtr <- sq_combos$Quarter[i]

  cat(sprintf("\n[%d/%d] %s Q%d ...", i, nrow(sq_combos), sv, qtr))

  # CPUEL: per-year summary for this SQ
  cpuel_syq <- dr_con("CPUEL") |>
    filter(Survey == sv, Quarter == qtr) |>
    group_by(Survey, Quarter, Year) |>
    summarise(
      cpuel_rows   = n(),
      cpuel_aphias = n_distinct(aphia),
      cpuel_hauls  = n_distinct(HaulNumber),
      cpuel_n_hour = sum(n_hour, na.rm = TRUE),
      cpuel_catch  = sum(length_mm > 0, na.rm = TRUE),
      cpuel_zf     = sum(length_mm == 0, na.rm = TRUE),
      .groups = "drop"
    ) |>
    collect()

  # Emulation: run once for all years in this SQ.
  # EVHOE is the only survey where CPUEL retains sex (F/M/U); use
  # collapse_sex = FALSE for EVHOE so the row structure is comparable.
  emul <- tryCatch(
    compute_cpue_emulation(
      haul_key        = "short",
      filter_survey   = sv,
      filter_quarter  = qtr,
      filter_species_validity = "1",
      collapse_sex    = (sv != "EVHOE")
    ),
    error = function(e) {
      cat(sprintf(" ERROR: %s", conditionMessage(e)))
      NULL
    }
  )

  if (is.null(emul)) {
    results[[i]] <- cpuel_syq |>
      mutate(emul_rows = NA_integer_, emul_aphias = NA_integer_,
             emul_hauls = NA_integer_, status = "ERROR")
    next
  }

  emul_syq <- emul |>
    group_by(Survey, Quarter, Year) |>
    summarise(
      emul_rows    = n(),
      emul_aphias  = n_distinct(latin),
      emul_hauls   = n_distinct(HaulNumber),
      emul_n_hour  = sum(n_hour, na.rm = TRUE),
      emul_catch   = sum(length_mm > 0, na.rm = TRUE),
      emul_zf      = sum(length_mm == 0, na.rm = TRUE),
      .groups = "drop"
    )

  sq_result <- cpuel_syq |>
    left_join(emul_syq, by = c("Survey", "Quarter", "Year")) |>
    mutate(
      row_diff_pct    = round(100 * (emul_rows   - cpuel_rows)   / cpuel_rows,   1),
      aphia_diff      = emul_aphias - cpuel_aphias,
      haul_diff       = emul_hauls  - cpuel_hauls,
      n_hour_diff_pct = round(100 * (emul_n_hour - cpuel_n_hour) / cpuel_n_hour, 1),
      # Decompose row diff into catch vs zero-fill components
      catch_diff_pct  = round(100 * (emul_catch - cpuel_catch) / pmax(cpuel_catch, 1), 1),
      zf_diff         = emul_zf - cpuel_zf,
      zf_diff_pct     = round(100 * zf_diff / cpuel_rows, 1),
      status = case_when(
        is.na(emul_rows)             ~ "ERROR",
        abs(row_diff_pct) < 1        ~ "PASS",
        abs(row_diff_pct) < 10       ~ "CLOSE",
        TRUE                         ~ "DIFF"
      )
    )

  results[[i]] <- sq_result
  n_pass  <- sum(sq_result$status == "PASS",  na.rm = TRUE)
  n_close <- sum(sq_result$status == "CLOSE", na.rm = TRUE)
  n_diff  <- sum(sq_result$status == "DIFF",  na.rm = TRUE)
  cat(sprintf(" PASS=%d CLOSE=%d DIFF=%d", n_pass, n_close, n_diff))
}

all_results <- bind_rows(results)

cat("\n\n=== SUMMARY BY SURVEY-QUARTER ===\n")
summary_sq <- all_results |>
  group_by(Survey, Quarter) |>
  summarise(
    n_years      = n(),
    pct_pass     = round(100 * mean(status == "PASS"),  1),
    pct_close    = round(100 * mean(status == "CLOSE"), 1),
    pct_diff     = round(100 * mean(status == "DIFF"),  1),
    mean_row_diff = round(mean(row_diff_pct, na.rm = TRUE), 1),
    mean_aphia_diff = round(mean(aphia_diff, na.rm = TRUE), 1),
    .groups = "drop"
  )
print(summary_sq, n = 20)

cat("\n=== WORST YEAR-CASES (|row_diff_pct| > 5%) ===\n")
all_results |>
  filter(abs(row_diff_pct) > 5) |>
  select(Survey, Quarter, Year, cpuel_rows, emul_rows, row_diff_pct,
         cpuel_aphias, emul_aphias, aphia_diff) |>
  arrange(Survey, Quarter, Year) |>
  print(n = 60)

cat("\n=== APHIA MISMATCHES (aphia_diff != 0) ===\n")
all_results |>
  filter(aphia_diff != 0) |>
  select(Survey, Quarter, Year, cpuel_aphias, emul_aphias, aphia_diff) |>
  arrange(Survey, Quarter, Year) |>
  print(n = 60)

saveRDS(all_results, "DATRAS/cpuel_validation_results.rds")
cat("\nResults saved to DATRAS/cpuel_validation_results.rds\n")
