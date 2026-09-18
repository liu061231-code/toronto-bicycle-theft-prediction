# features.R --------------------------------------------------------------
# Feature engineering for the monthly theft-count panel.
#
# The target is a count with heavy over-dispersion and zero-inflation, so
# features are designed to be used by both linear (basis-function) models
# and generalized linear models (Poisson / negative-binomial). All
# transformations derived from the data are fit on the training split only
# and then applied to validation/test to avoid leakage.

# Construct the basis-function design matrix used by the linear/ridge models.
#
# Components:
#   - cubic B-splines over the month index (smooth long-term trend)
#   - annual sine/cosine harmonics (seasonality)
#   - radial basis functions over normalised coordinates (spatial structure)
#   - one-hot neighbourhood indicators (neighbourhood fixed effects)
#
# `recipe` contains all scaling constants/centers learned from training.
make_basis_recipe <- function(train) {
  unique_coordinates <- train |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood)
  center_index <- unique(round(seq(
    1, nrow(unique_coordinates), length.out = 16
  )))
  # Boundary knots are set from the TRAINING time range so the spline basis
  # never assumes knowledge of future months. This keeps the basis stable
  # when a model is trained on an early window of an expanding CV fold.
  train_time <- range(train$time_index)
  list(
    time_boundary = train_time,
    time_knots = as.numeric(stats::quantile(
      train$time_index, c(0.2, 0.4, 0.6, 0.8)
    )),
    lon_center = mean(train$lon),
    lat_center = mean(train$lat),
    spatial_scale = max(stats::sd(train$lon), stats::sd(train$lat)),
    rbf_centers = unique_coordinates[center_index, c("lon", "lat")],
    rbf_sigma = 0.8,
    neighborhood_levels = unique_coordinates$neighborhood
  )
}

make_design_matrix <- function(data, recipe) {
  time_basis <- splines::bs(
    data$time_index,
    knots = recipe$time_knots,
    Boundary.knots = recipe$time_boundary,
    degree = 3,
    intercept = FALSE,
    warn.outside = FALSE
  )
  seasonal <- cbind(
    sin1 = sin(2 * pi * data$month_of_year / 12),
    cos1 = cos(2 * pi * data$month_of_year / 12),
    sin2 = sin(4 * pi * data$month_of_year / 12),
    cos2 = cos(4 * pi * data$month_of_year / 12)
  )
  lon <- (data$lon - recipe$lon_center) / recipe$spatial_scale
  lat <- (data$lat - recipe$lat_center) / recipe$spatial_scale
  centers <- as.data.frame(recipe$rbf_centers)
  centers$lon <- (centers$lon - recipe$lon_center) / recipe$spatial_scale
  centers$lat <- (centers$lat - recipe$lat_center) / recipe$spatial_scale
  rbf <- vapply(
    seq_len(nrow(centers)),
    function(i) {
      exp(
        -((lon - centers$lon[i])^2 + (lat - centers$lat[i])^2) /
          (2 * recipe$rbf_sigma^2)
      )
    },
    numeric(nrow(data))
  )
  neighborhood_basis <- stats::model.matrix(
    ~ neighborhood - 1,
    data = data.frame(
      neighborhood = factor(
        data$neighborhood,
        levels = recipe$neighborhood_levels
      )
    )
  )
  x <- cbind(time_basis, seasonal, rbf, neighborhood_basis)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf))),
    paste0("area_", seq_len(ncol(neighborhood_basis)))
  )
  x
}
