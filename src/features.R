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
#   - neighbourhood-level contextual features (historical share of outdoor /
#     commercial thefts), learned from training data to avoid leakage
#
# `recipe` contains all scaling constants/centers learned from training.
make_basis_recipe <- function(train) {
  # Only neighbourhoods with valid coordinates participate in spatial (RBF)
  # modelling. NSA and any other unknown area have NA coordinates and are
  # excluded here so they cannot inject a (0,0) center into the spatial basis.
  unique_coordinates <- train |>
    dplyr::filter(!is.na(.data$lon), !is.na(.data$lat)) |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood)

  center_index <- unique(round(seq(
    1, nrow(unique_coordinates), length.out = 16
  )))
  # Boundary knots are set from the TRAINING time range so the spline basis
  # never assumes knowledge of future months. This keeps the basis stable
  # when a model is trained on an early window of an expanding CV fold.
  train_time <- range(train$time_index)

  # Neighbourhood-level contextual priors: the historical (training-time)
  # share of thefts that happen outdoors and in commercial premises. These
  # are stable per-neighbourhood attributes, not per-month values, so they
  # carry no target leakage and generalise to unseen months.
  neighborhood_context <- train |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(
      outside_share = mean(outside_share),
      commercial_share = mean(commercial_share),
      .groups = "drop"
    ) |>
    dplyr::arrange(neighborhood)

  # Spatial center/scale computed only over valid coordinates so the scale
  # reflects real geographic extent, not a synthetic (0,0) outlier.
  valid_lon <- train$lon[!is.na(train$lon) & !is.na(train$lat)]
  valid_lat <- train$lat[!is.na(train$lon) & !is.na(train$lat)]

  list(
    time_boundary = train_time,
    time_knots = as.numeric(stats::quantile(
      train$time_index, c(0.2, 0.4, 0.6, 0.8)
    )),
    lon_center = mean(valid_lon),
    lat_center = mean(valid_lat),
    spatial_scale = max(stats::sd(valid_lon), stats::sd(valid_lat)),
    rbf_centers = unique_coordinates[center_index, c("lon", "lat")],
    rbf_sigma = 0.8,
    neighborhood_levels = unique_coordinates$neighborhood,
    neighborhood_context = neighborhood_context
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
  # Unknown-area (NSA) rows have NA coordinates. Set their RBF features to 0
  # (maximally "far" from every valid center) rather than propagating NA, so
  # they carry no spatial signal but do not break the design matrix.
  if (!is.null(dim(rbf)) && ncol(rbf) > 0L) {
    unknown_idx <- is.na(lon) | is.na(lat)
    rbf[unknown_idx, ] <- 0
  }
  # One-hot neighbourhood indicators built explicitly (not via model.matrix,
  # which silently DROPS rows whose factor level is not in the known set --
  # e.g. NSA). This guarantees one row per input row: known neighbourhoods get
  # a 1 in their own column, unknown areas (NSA) get an all-zero row so their
  # prediction is driven by temporal + context terms only.
  n_levels <- length(recipe$neighborhood_levels)
  level_map <- match(data$neighborhood, recipe$neighborhood_levels)
  neighborhood_basis <- matrix(
    0, nrow = nrow(data), ncol = n_levels
  )
  known_idx <- which(!is.na(level_map))
  if (length(known_idx) > 0L) {
    row_col <- cbind(known_idx, level_map[known_idx])
    neighborhood_basis[row_col] <- 1
  }
  colnames(neighborhood_basis) <- recipe$neighborhood_levels

  # Join the neighbourhood-level contextual priors (outdoor / commercial
  # theft shares) as fixed per-neighbourhood covariates.
  context <- data |>
    dplyr::select(neighborhood) |>
    dplyr::left_join(recipe$neighborhood_context, by = "neighborhood") |>
    dplyr::select(outside_share, commercial_share)
  context_matrix <- as.matrix(context)
  # Unknown areas have no contextual prior; use 0 (neutral) so their
  # prediction is driven by temporal structure only.
  context_matrix[is.na(context_matrix)] <- 0

  x <- cbind(time_basis, seasonal, rbf, neighborhood_basis, context_matrix)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf))),
    paste0("area_", seq_len(ncol(neighborhood_basis))),
    "context_outside_share", "context_commercial_share"
  )
  x
}
