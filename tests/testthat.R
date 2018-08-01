# Setup
logfile <- Sys.getenv("VRWATCH_LOGFILE")

temp_log <- tempfile(fileext = ".log")
Sys.setenv("VRWATCH_LOGFILE" = temp_log)

if (.Platform$OS.type != "unix") {
  Sys.setenv("VRWATCH_NOSYSLOG" = "true")
}



# Testing
library(testthat)
library(vrwatch)

test_check("vrwatch")



# Teardown
if (logfile == "") {
  Sys.unsetenv("VRWATCH_LOGFILE")
} else {
  Sys.setenv("VRWATCH_LOGFILE" = logfile)
}

unlink(temp_log)
