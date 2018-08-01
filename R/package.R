#' Log the loading and unloading of R packages
#'
#' @section Introduction:
#' **vrwatch** is a tool that logs the loadings and unloadings of R packages
#' on a system. Its goal is to measure which packages are used, and how
#' often.
#'
#' @section Requirements:
#' * A version of R. Any version later than or equal to 3.0.0 is sufficient.
#' 
#' * To log to the system log, a logger daemon, and the `logger` command
#'   line tool must be available. The **vrwatch** RPM package
#'   configures `rsyslog` (http://www.rsyslog.com/), but in general any
#'   system compatible with `logger` can be used. `rsyslog` is standard and
#'   installed by default on most Linux distributions, including Debian
#'   Linux, Ubuntu Linux, CentOS and RedHat Linux.
#'
#'   The **vrwatch** RPM package sets up `rsyslog` to log **vrwatch**
#'   events to `/var/log/vrwatch.log`. If an alternative logging system is
#'   used then these events go to the regular generic system log file by
#'   default.
#'   
#' * The **vrwatch** R package needs to be loaded in every R session that
#'   is to be logged. The **vrwatch** RPM package sets up the
#'   system-wide R profile in `$R_HOME/etc/Rprofile.site` to load
#'   **vrwatch** at the beginning of every R session.
#'
#' @section Installation:
#' **vrwatch** is an R package, and you can install it as a regular R package.
#' We suggest to install it via the supplied RPM package, whenever
#' possible; to set up the `rsyslog` system logger, and the automatic
#' loading of **vrwatch** into every R session via a system-wide R profile.
#'
#' For platforms unsupported by the supplied RPM package,
#' **vrwatch** can be installed as a regular R package. The filtering of
#' the **vrwatch** events to a separate log file can be set up by the
#' system administrator. **vrwatch** events are logged with the **vrwatch**
#' tag, so the following `rsyslog` configuration file can be used:
#' ```
#' :syslogtag, isequal, "VRWATCH:" /var/log/vrwatch.log
#' & ~
#' ```
#' Save this to `/etc/rsyslog/23-vrwatch.conf` and restart the `rsyslog`
#' daemon.
#'
#' To check that **vrwatch** is installed and working properly, start R,
#' and check that the **vrwatch** package is loaded:
#' ```
#' loadedNamespaces()
#' #> [1] "graphics"  "utils"     "grDevices" "stats"
#' #> [5] "datasets"  "vrwatch"   "methods"   "base"
#' ```
#'
#' Then load an R package (e.g. **splines**, which is not loaded by default,
#' but included on almost all R installations: `library(splines)`).
#' Try unloading a package as well, e.g. `unloadNamespace("splines")`.
#' Then verify that the package loadings are logged to the log file,
#' which is `/var/log/vrwatch.log`, unless configured otherwise.
#'
#' @section Log entries:
#' **vrwatch** log entries look similar to the following example. Note that
#' there might be some differences depending on the logging configuration
#' of the system.
#' ```
#' Nov  3 10:27:01 centos6 VRWATCH: 21735 LOAD   splines /usr/lib64/R/library/splines
#' Nov  3 10:27:04 centos6 VRWATCH: 21735 UNLOAD splines /usr/lib64/R/library/splines
#' ```
#' * The first three columns are a timestamp, in the regular log format
#' * The fourth column is the hostname
#' * The fifth column is a log tag, which is always `VRWATCH:`
#' * The six column is the process id of the R process
#' * The seventh column is `LOAD` or `UNLOAD`, the type of the event
#' * The eighth column is the name of the R package that was loaded or
#'   unloaded
#' * The last column is the directory where the R package is installed
#'   on the system
#'
#' @section Logging to a system log:
#' **vrwatch** logs to the system log via the `logger` command line program
#' by default. To avoid this, set the `VRWATCH_NOSYSLOG` environment
#' variable to any non-empty value, before loading the **vrwatch** R package.
#'
#' @section Logging to a file:
#' In addition or instead the system log, **vrwatch** can log to an
#' arbitrary log file. For this the `VRWATCH_LOGFILE` environment variable
#' must be set to the name of the file to be logged to, before loading the
#' **vrwatch** package.
#'
#' @section Impact on the system:
#' **vrwatch** traces (see [base::trace()]) the [base::loadNamespace()] and
#' the [base::unloadNamespace()] base R functions, and inserts an extra
#' function call into them, to do the logging.
#'
#' The impact of **vrwatch** on the system should be very minimal:
#' * Loading and unloading package will be slightly slower when **vrwatch**
#'   is loaded. In our measurements the difference in running time was
#'   less than 0.01 seconds, so this is only an issue for code that
#'   repeatedly loads and unloads R packages many times, and this is
#'   very atypical.
#' * The **vrwatch** package must be loaded at all times to perform the
#'   logging, so code that queries and manipulates the set of loaded
#'   packages can be potentially impacted. Again, this is very atypical.
#'
#' In case of unwanted system impact, unload the **vrwatch** package:
#' ```
#' unloadNamespace("vrwatch")
#' ```
#'
#' @author Mango Solutions http://mango-solutions.com
#' @name vrwatch
#' @docType package
NULL

data <- new.env()


# Linux-format timestamp: "Mon  1 Jan 00:00:00"
format_timestamp <- function(date) {
  format(as.POSIXlt(date, tz = "UTC"), "%a %e %H:%M:%S")
}


# Start tracing un/loadNamespace functions when vrwatch is loaded
.onLoad <- function(libname, pkgname) {

  data$logfile <- Sys.getenv("VRWATCH_LOGFILE", NA_character_)

  if (Sys.getenv("VRWATCH_NOSYSLOG", "") == "") {
    data$syslog <- TRUE
  }
  
  # Write "LOAD vrwatch" entry
  write_log("LOAD  ", pkgname, file.path(libname, pkgname))

  suppressMessages(
    trace(base::loadNamespace, print = FALSE, tracer = function() {
      pkg <- get("package", parent.frame())
      lib.loc <- get("lib.loc", parent.frame())
      pkgpath <- c(attr(pkg, "LibPath"), lib.loc)
      pkg <- as.character(pkg)[1]
      current <- loadedNamespaces()
      
      # If package isn't loaded already, write a LOAD entry
      if (! pkg %in% current) {
        path <- normalizePath(find.package(pkg, pkgpath))
        write_log("LOAD  ", pkg, path)
      }
    })
  )

  suppressMessages(
    trace(base::unloadNamespace, print = FALSE, tracer = function() {
      pkg <- get("ns", parent.frame())
      current <- loadedNamespaces()
      
      # If package is loaded, write an UNLOAD entry
      if (pkg %in% current) {
        path <- normalizePath(asNamespace(pkg)$`.__NAMESPACE__.`$path)
        write_log("UNLOAD", pkg, path)
      }
    })
  )
}



# Stop tracing un/loadNamespace functions
.onUnload <- function(libpath) {
  suppressMessages(untrace(base::loadNamespace))
  suppressMessages(untrace(base::unloadNamespace))
}



write_log <- function(operation, package, path,
                      timestamp = format_timestamp(Sys.time()),
                      host = Sys.info()[["nodename"]],
                      pid = Sys.getpid()) {

  if (!is.null(data$logfile) && !identical(data$logfile, NA_character_)) {
    entry <- paste(timestamp, host, pid, "VRWATCH:", operation, package, path)
    cat(entry, "\n", sep = "", file = data$logfile, append = TRUE)
  }

  if (!is.null(data$syslog)) {
    logentry <- paste(pid, operation, package, path)
    system(sprintf('logger -p info -t VRWATCH "%s"', logentry))
  }
}
