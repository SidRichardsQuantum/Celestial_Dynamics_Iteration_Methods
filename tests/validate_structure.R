source("R/load.R")

required_files = c(
  "DESCRIPTION",
  "NAMESPACE",
  ".Rbuildignore",
  "R/load.R",
  "analysis/README.md",
  "examples/README.md"
)

missing_files = required_files[!file.exists(cd_path(required_files))]
if (length(missing_files) > 0) {
  stop(sprintf("Missing structural files:\n%s",
               paste(missing_files, collapse = "\n")))
}

description = read.dcf(cd_path("DESCRIPTION"))
if (as.character(description[1, "Package"]) !=
    "CelestialDynamicsIterationMethods") {
  stop("DESCRIPTION has an unexpected package name.")
}

r_files = list.files(cd_project_root(), pattern = "\\.R$", recursive = TRUE,
                     full.names = TRUE)
r_files = r_files[!grepl("^\\.git/", r_files)]

direct_source_pattern = '^\\s*source\\("R/(constants|methods|systems)/'
direct_source_hits = unlist(lapply(r_files, function(path) {
  lines = readLines(path, warn = FALSE)
  matches = grep(direct_source_pattern, lines, value = TRUE)
  if (length(matches) == 0) {
    return(character(0))
  }
  relative_path = sub(paste0("^", cd_project_root(), "/"), "", path)
  sprintf("%s: %s", relative_path, matches)
}), use.names = FALSE)

if (length(direct_source_hits) > 0) {
  stop(sprintf(
    "Use source(\"R/load.R\") plus cd_source()/cd_load_*() instead of direct R/ dependency sources:\n%s",
    paste(direct_source_hits, collapse = "\n")
  ))
}

cat("Repository structure validation passed.\n")
