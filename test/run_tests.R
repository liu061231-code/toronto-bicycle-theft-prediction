# Run all tests. Execute from the project root with:
#   Rscript test/run_tests.R
#
# This runner sources test_helper.R (which loads the pipeline modules) and then
# runs every test file in this directory.

test_root <- normalizePath(dirname(
  sub("^--file=", "", commandArgs(trailingOnly = FALSE)[
    grep("^--file=", commandArgs(trailingOnly = FALSE))
  ][1])
), mustWork = TRUE)

# Load the shared helper in this environment so TEST_ROOT is available.
suppressMessages({
  library(testthat)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
})

TEST_ROOT <- normalizePath(dirname(test_root), mustWork = TRUE)
source(file.path(TEST_ROOT, "src", "config.R"))
source(file.path(TEST_ROOT, "src", "prepare_data.R"))
source(file.path(TEST_ROOT, "src", "features.R"))
source(file.path(TEST_ROOT, "src", "validation.R"))
source(file.path(TEST_ROOT, "src", "models.R"))
source(file.path(TEST_ROOT, "src", "evaluate.R"))

# The helper's own source() of modules is idempotent; re-sourcing is fine.
testthat::test_dir(test_root, reporter = "summary")
