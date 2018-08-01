context("Check vrwatch functionality")


test_that("vrwatch can write to a log file", {
  
  # Custom log file
  logfile <- Sys.getenv("VRWATCH_LOGFILE", "")
  
  initial <- readLines(logfile)
  
  
  # We loaded vrwatch just before running these tests...
  expect_match(initial, "LOAD   vrwatch", all = FALSE)
  
  #  ... so at least one entry will have a timestamp with today's date
  expect_match(initial, format(Sys.time(), "%a %e", tz = "UTC"), all = FALSE)
  
  
  
  # Load/unload a package and check log entries
  expect_failure(expect_match(initial, "splines"))
  
  library(splines)
  expect_match(tail(readLines(logfile), 1), "LOAD   splines")
  
  unloadNamespace("splines")
  expect_match(tail(readLines(logfile), 1), "UNLOAD splines")
  
  
  # Read in full log, excluding "path" column, and convert to a matrix-like form
  # (The path can contain spaces, which on't play nice with the vapply below)
  current <- readLines(logfile)
  
  cols <- vapply(1:8, function(x) {
    lapply(strsplit(current, "\\s+"), `[[`, x)
  }, vector(mode = "list", length = length(current)))
  
  expect_equal(nrow(cols), length(current))
  
  
  # Check facts about certain columns:
  # * Date should always be less than or equal to 31
  expect_true(all(as.numeric(cols[, 2]) <= 31))
  #  * The 6th column should always contain the VRWATCH: tag
  expect_true(all(cols[, 6] == "VRWATCH:"))
  # * The 7th column should always contain the operation
  expect_true(all(cols[, 7] %in% c("LOAD", "UNLOAD")))
  
  
  
  # Unload should be silent
  expect_message(unloadNamespace("vrwatch"), NA)
})
