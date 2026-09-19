# helper.R ----------------------------------------------------------------
# Pure helpers for the project test suite: builds synthetic data and exposes
# small utilities. It does NOT locate the project root or source modules —
# run_tests.R does that once and sets TEST_ROOT in the global environment.
# Each test file `source()`s this file after run_tests.R has loaded the
# pipeline modules.

# Build a small synthetic raw dataset resembling the real schema, including a
# few "NSA" unknown-area records with zero coordinates.
make_synthetic_raw <- function(
    n_neighborhoods = 5,
    n_years = 4,
    with_nsa = TRUE) {
  neighborhoods <- paste0("Area", seq_len(n_neighborhoods))
  if (with_nsa) {
    neighborhoods <- c(neighborhoods, "NSA")
  }
  coords <- data.frame(
    neighborhood = paste0("Area", seq_len(n_neighborhoods)),
    lon = seq(-79.4, -79.2, length.out = n_neighborhoods),
    lat = seq(43.65, 43.70, length.out = n_neighborhoods)
  )
  mseq <- seq(
    as.Date(sprintf("%d-01-01", 2014)),
    as.Date(sprintf("%d-12-01", 2014 + n_years - 1)),
    by = "month"
  )
  rows <- list()
  k <- 0L
  for (nb in neighborhoods) {
    for (m in mseq) {
      # `for` strips the Date class to numeric (days since epoch); restore it.
      m_date <- as.Date(m, origin = "1970-01-01")
      seed_val <- (k * 37) %% 10
      thefts <- if (seed_val < 4) 0 else seed_val
      k <- k + 1L
      rows[[length(rows) + 1L]] <- list(
        date = m_date,
        quarter = m_date,
        day_of_week = weekdays(m_date),
        neighborhood = nb,
        bike_cost = 500,
        location = if (thefts > 0) "Open/Public Spaces" else "Others",
        long = if (nb == "NSA") 0 else coords$lon[coords$neighborhood == nb],
        lat = if (nb == "NSA") 0 else coords$lat[coords$neighborhood == nb]
      )
    }
  }
  dplyr::bind_rows(rows)
}
