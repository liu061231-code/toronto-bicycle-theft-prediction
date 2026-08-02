extract_seasonal_coefficients <- function(ridge_model, lambda) {
  fitted <- as.matrix(stats::coef(ridge_model, s = lambda))[, 1]
  wanted <- c("sin1", "cos1", "sin2", "cos2")
  stats::setNames(as.numeric(fitted[wanted]), wanted)
}

summarise_seasonal_cycle <- function(coefficients) {
  required <- c("sin1", "cos1", "sin2", "cos2")
  stopifnot(all(required %in% names(coefficients)))
  month <- 1:12
  seasonal_log <-
    coefficients["sin1"] * sin(2 * pi * month / 12) +
    coefficients["cos1"] * cos(2 * pi * month / 12) +
    coefficients["sin2"] * sin(4 * pi * month / 12) +
    coefficients["cos2"] * cos(4 * pi * month / 12)
  monthly <- tibble::tibble(
    month = month,
    month_label = month.abb,
    seasonal_log = as.numeric(seasonal_log),
    seasonal_multiplier = exp(seasonal_log)
  )
  list(
    coefficients = tibble::tibble(
      term = required,
      estimate = as.numeric(coefficients[required])
    ),
    monthly = monthly,
    summary = tibble::tibble(
      annual_amplitude = as.numeric(sqrt(
        coefficients["sin1"]^2 + coefficients["cos1"]^2
      )),
      semiannual_amplitude = as.numeric(sqrt(
        coefficients["sin2"]^2 + coefficients["cos2"]^2
      )),
      peak_month = month[which.max(seasonal_log)],
      trough_month = month[which.min(seasonal_log)],
      peak_to_trough_ratio = exp(max(seasonal_log) - min(seasonal_log))
    )
  )
}
