# Fork doctoralvarez/Nyxian — version 0.1.0
# Changelog:
#  - 0.1.0 (2026-11-19): CRAN packages built for iOS without a dependency
#    that cannot exist there yet (epiR without sf: sf needs GDAL, GEOS and
#    PROJ; epiR uses it only for maps). nyx_strip_db() takes it out of the
#    package index (so it is not in the closure), nyx_install_patched()
#    installs the package for the Mac from its source with that dependency
#    removed from DESCRIPTION and NAMESPACE (and says which of its R files
#    still name it), nyx_repack() leaves the patched source where the iOS
#    build takes it, nyx_smoke() runs a few functions of it on the Mac.
# Used by build_rpkg.sh (sourced by R for the Mac).

nyx_drop <- list(epiR = c("sf"))

nyx_strip_field <- function(field, rm) {
  if (is.na(field) || !nzchar(field)) return(field)
  parts <- trimws(strsplit(field, ",")[[1]])
  names <- sub("[[:space:](].*$", "", parts)
  paste(parts[!names %in% rm], collapse = ", ")
}

nyx_strip_db <- function(db) {
  for (p in intersect(names(nyx_drop), rownames(db)))
    for (f in intersect(c("Depends", "Imports", "LinkingTo"), colnames(db)))
      db[p, f] <- nyx_strip_field(db[p, f], nyx_drop[[p]])
  db
}

nyx_patch_dir <- function(dir, rm) {
  d <- read.dcf(file.path(dir, "DESCRIPTION"), keep.white = TRUE)
  for (f in intersect(c("Depends", "Imports", "LinkingTo"), colnames(d)))
    d[1, f] <- nyx_strip_field(d[1, f], rm)
  d <- cbind(d, NyxianRemoved = paste(rm, collapse = ", "))
  write.dcf(d, file.path(dir, "DESCRIPTION"), keep.white = colnames(d))
  ns <- readLines(file.path(dir, "NAMESPACE"))
  pat <- paste0("^\\s*import(From)?\\(\\s*\"?(", paste(rm, collapse = "|"), ")\"?\\s*[,)]")
  writeLines(ns[!grepl(pat, ns)], file.path(dir, "NAMESPACE"))
  # where the package still calls it (those functions will stop with an error)
  files <- list.files(file.path(dir, "R"), full.names = TRUE)
  for (pkg in rm) {
    uses <- character()
    for (f in files) {
      code <- readLines(f, warn = FALSE)
      hit <- grepl(paste0(pkg, "::"), code, fixed = TRUE) | (pkg == "sf" & grepl("\\bst_[a-z_]+\\(", code, perl = TRUE))
      if (any(hit)) uses <- c(uses, basename(f))
    }
    message(basename(dir), " without ", pkg, ": ",
            if (length(uses)) paste("still named in", paste(uses, collapse = ", ")) else "not used in its R code")
  }
}

nyx_install_patched <- function(p, lib, work) {
  dir.create(work, showWarnings = FALSE, recursive = TRUE)
  f <- download.packages(p, destdir = work, quiet = TRUE)[1, 2]
  unlink(file.path(work, p), recursive = TRUE)
  untar(f, exdir = work)
  nyx_patch_dir(file.path(work, p), nyx_drop[[p]])
  install.packages(file.path(work, p), lib = lib, repos = NULL, type = "source", quiet = TRUE)
  f
}

nyx_repack <- function(p, work, srcdir) {
  old <- list.files(srcdir, pattern = paste0("^", p, "_.*\\.tar\\.gz$"), full.names = TRUE)
  name <- if (length(old)) basename(old[1]) else paste0(p, "_patched.tar.gz")
  unlink(old)
  owd <- setwd(work); on.exit(setwd(owd))
  tar(file.path(srcdir, name), files = p, compression = "gzip", tar = "internal")
}

nyx_smoke <- function(p, lib) {
  if (p != "epiR") return(invisible())
  ok <- TRUE
  run <- function(label, expr) {
    r <- tryCatch({ force(expr); "ok" }, error = function(e) { ok <<- FALSE; conditionMessage(e) })
    message("epiR check ", label, ": ", r)
  }
  suppressPackageStartupMessages(library(epiR, lib.loc = c(lib, .libPaths())))
  dx <- as.table(matrix(c(670, 202, 74, 640), nrow = 2, byrow = TRUE))
  run("epi.tests", print(epi.tests(dx, conf.level = 0.95)))
  run("epi.2by2", print(epi.2by2(as.table(matrix(c(13, 2163, 5, 3349), nrow = 2, byrow = TRUE)), method = "cohort.count")))
  run("epi.kappa", print(epi.kappa(as.table(matrix(c(40, 5, 8, 47), nrow = 2)), method = "cohen")$kappa))
  set.seed(1); x <- rnorm(40, 540, 30); y <- x + rnorm(40, 3, 6)
  run("epi.ccc", print(epi.ccc(x, y)$rho.c))
  run("epi.conf", print(epi.conf(matrix(c(25, 400), nrow = 1), ctype = "prevalence", method = "exact")))
  if (!ok) stop("epiR does not work without sf")
}
