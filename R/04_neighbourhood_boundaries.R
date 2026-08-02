historical_neighbourhoods_url <- paste0(
  "https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/",
  "fc443770-ef0a-4025-9c2c-2cb558bfab00/resource/",
  "9994da8e-5d35-438b-bfc4-eef14d09e035/download/",
  "neighbourhoods-historical-140-4326.geojson"
)

read_historical_neighbourhoods <- function(
    boundary_source = historical_neighbourhoods_url) {
  boundaries <- sf::st_read(boundary_source, quiet = TRUE) |>
    sf::st_make_valid()
  required <- c("AREA_SHORT_CODE", "AREA_NAME")
  if (!all(required %in% names(boundaries))) {
    stop(
      "Historical boundary data is missing columns: ",
      paste(setdiff(required, names(boundaries)), collapse = ", ")
    )
  }
  boundaries <- boundaries |>
    dplyr::transmute(
      neighbourhood_id = as.integer(AREA_SHORT_CODE),
      boundary_name = AREA_NAME,
      geometry = geometry
    )
  if (nrow(boundaries) != 140L ||
      dplyr::n_distinct(boundaries$neighbourhood_id) != 140L) {
    stop("Expected 140 unique historical Toronto neighbourhood boundaries.")
  }
  boundaries
}
