#!/usr/bin/env Rscript

# =============================================================================
# Species delimitation via GMYC (Generalized Mixed Yule-Coalescent)
#
# Inputs:
#   --tree=path/to/beast_timetree.tree
#   --outdir=gmyc_results
#
# Optional:
#   --format=auto|nexus|newick
#   --tree_index=1                    # if Nexus contains multiple trees (multiPhylo)
#   --outgroup_regex="out|outgroup"   # drop tips matching regex (case-insensitive)
#   --outgroup_file=path/to/list.txt  # one tip label per line (exact matches)
#   --method=multiple|single
#   --force_ultrametric=FALSE|TRUE    # TRUE uses phytools::force.ultrametric() if needed
#   --seed=12345
#   --save_plots=TRUE|FALSE
#   --plot_format=pdf|png
#   --write_xlsx=TRUE|FALSE           # TRUE writes xlsx if openxlsx installed
#
# Outputs:
#   - gmyc_result.rds
#   - gmyc_summary.txt
#   - gmyc_clusters_long.csv          (tip -> cluster)
#   - gmyc_species_list.csv           (species/cluster list form)
#   - gmyc_clusters.xlsx (optional)
#   - plots_gmyc.(pdf|png) (if save_plots=TRUE)
#   - sessionInfo.txt
#
# Dependencies:
#   - ape (required)
#   - splits (required)  # provides gmyc()
#   - phytools (optional; only needed if forcing ultrametric)
#   - openxlsx (optional; only needed if writing xlsx)
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("ape", quietly = TRUE)) {
    stop("Package 'ape' is required. Install with: install.packages('ape')", call. = FALSE)
  }
  if (!requireNamespace("splits", quietly = TRUE)) {
    stop("Package 'splits' is required. Install with: install.packages('splits')", call. = FALSE)
  }
})

# ----------------------------- CLI parser (base R) ----------------------------
parse_args <- function(x) {
  out <- list()
  for (a in x) {
    if (!startsWith(a, "--")) next
    kv <- sub("^--", "", a)
    if (!grepl("=", kv, fixed = TRUE)) next
    parts <- strsplit(kv, "=", fixed = TRUE)[[1]]
    key <- parts[[1]]
    val <- paste(parts[-1], collapse = "=")
    out[[key]] <- val
  }
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

get_opt <- function(name, default = "") {
  if (!is.null(args[[name]])) return(args[[name]])
  env <- Sys.getenv(toupper(name), unset = NA_character_)
  if (!is.na(env) && nzchar(env)) return(env)
  default
}

as_bool <- function(x, default = FALSE) {
  if (!nzchar(x)) return(default)
  x <- tolower(trimws(x))
  x %in% c("1", "true", "t", "yes", "y")
}

# ----------------------------- Config --------------------------------
tree_path          <- get_opt("tree", "")
outdir             <- get_opt("outdir", "gmyc_results")
tree_format        <- tolower(get_opt("format", "auto"))     # auto|newick|nexus
tree_index         <- suppressWarnings(as.integer(get_opt("tree_index", "1")))
outgroup_regex     <- get_opt("outgroup_regex", "")
outgroup_file      <- get_opt("outgroup_file", "")
method             <- tolower(get_opt("method", "multiple")) # multiple|single
force_ultrametric  <- as_bool(get_opt("force_ultrametric", "FALSE"), default = FALSE)
seed               <- suppressWarnings(as.integer(get_opt("seed", "12345")))
save_plots         <- as_bool(get_opt("save_plots", "TRUE"), default = TRUE)
plot_format        <- tolower(get_opt("plot_format", "pdf")) # pdf|png
write_xlsx         <- as_bool(get_opt("write_xlsx", "FALSE"), default = FALSE)

# ----------------------------- Checks ---------------------------------
if (!nzchar(tree_path)) stop("Missing required input: --tree=path/to/tree", call. = FALSE)
if (!file.exists(tree_path)) stop("Tree file not found: ", tree_path, call. = FALSE)
if (!method %in% c("multiple", "single")) stop("--method must be multiple or single", call. = FALSE)
if (!plot_format %in% c("pdf", "png")) stop("--plot_format must be pdf or png", call. = FALSE)
if (is.na(tree_index) || tree_index < 1) stop("--tree_index must be >= 1", call. = FALSE)

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Save session info
sink(file.path(outdir, "sessionInfo.txt"))
cat("Date: ", format(Sys.time(), tz = ""), "\n", sep = "")
cat("Working directory: ", getwd(), "\n", sep = "")
cat("Command: Rscript species_delim_gmyc.R ",
    paste(commandArgs(trailingOnly = TRUE), collapse = " "), "\n\n", sep = "")
print(sessionInfo())
sink()

set.seed(seed)

# ----------------------------- Read tree -----------------------------
read_tree_auto <- function(path, fmt = "auto") {
  if (fmt == "newick") return(ape::read.tree(path))
  if (fmt == "nexus")  return(ape::read.nexus(path))

  # auto: try nexus then newick, but allow either
  tr <- tryCatch(ape::read.nexus(path), error = function(e) NULL)
  if (!is.null(tr)) return(tr)

  tr <- tryCatch(ape::read.tree(path), error = function(e) NULL)
  if (!is.null(tr)) return(tr)

  stop("Could not read tree as Nexus or Newick: ", path, call. = FALSE)
}

Utre <- read_tree_auto(tree_path, tree_format)

# Handle multi-tree files (multiPhylo)
if (inherits(Utre, "multiPhylo")) {
  if (tree_index > length(Utre)) {
    stop("Requested tree_index=", tree_index, " but file contains only ",
         length(Utre), " trees.", call. = FALSE)
  }
  message("Nexus contains ", length(Utre), " trees; using tree_index=", tree_index)
  Utre <- Utre[[tree_index]]
}

if (!inherits(Utre, "phylo")) stop("Tree object is not a 'phylo'.", call. = FALSE)

# ----------------------------- Drop outgroups ----------------------
drop_outgroups <- function(tr, regex = "", file = "") {
  tips_to_drop <- character(0)

  if (nzchar(file)) {
    if (!file.exists(file)) stop("outgroup_file not found: ", file, call. = FALSE)
    og <- readLines(file, warn = FALSE)
    og <- trimws(og)
    og <- og[nzchar(og) & !startsWith(og, "#")]
    tips_to_drop <- unique(c(tips_to_drop, intersect(og, tr$tip.label)))
  }

  if (nzchar(regex)) {
    hits <- grepl(regex, tr$tip.label, ignore.case = TRUE, perl = TRUE)
    tips_to_drop <- unique(c(tips_to_drop, tr$tip.label[hits]))
  }

  if (length(tips_to_drop) > 0) {
    message("Dropping ", length(tips_to_drop), " outgroup tip(s).")
    tr <- ape::drop.tip(tr, tips_to_drop)
  } else {
    message("No outgroup tips dropped (no matches / not provided).")
  }

  tr
}

Utre <- drop_outgroups(Utre, outgroup_regex, outgroup_file)

if (length(Utre$tip.label) < 4) {
  stop("Too few tips after outgroup removal (need >= 4).", call. = FALSE)
}

# ----------------------------- Ultrametric handling ---------------------------
is_ultra <- ape::is.ultrametric(Utre, tol = 1e-8)
if (!is_ultra) {
  msg <- "Tree is not ultrametric (GMYC requires an ultrametric time tree)."
  if (!force_ultrametric) {
    stop(msg, "\nSet --force_ultrametric=TRUE to force ultrametric (not recommended unless you know why).",
         call. = FALSE)
  }
  if (!requireNamespace("phytools", quietly = TRUE)) {
    stop(msg, "\nRequested --force_ultrametric=TRUE but package 'phytools' is not installed.",
         call. = FALSE)
  }
  message(msg, " Forcing ultrametric via phytools::force.ultrametric().")
  Utre <- phytools::force.ultrametric(Utre)
  if (!ape::is.ultrametric(Utre, tol = 1e-8)) {
    stop("force.ultrametric() did not produce an ultrametric tree. Aborting.", call. = FALSE)
  }
} else {
  message("Tree is ultrametric: OK")
}

# Optional quick tree plot (saved if requested)
plot_tree_to_file <- function(tr, outdir, fmt = "pdf") {
  out_path <- file.path(outdir, paste0("plot_tree.", fmt))
  if (fmt == "pdf") {
    grDevices::pdf(out_path, width = 11, height = 8.5)
    on.exit(grDevices::dev.off(), add = TRUE)
    plot(tr, cex = 0.5, no.margin = TRUE)
    grDevices::dev.off()
  } else {
    grDevices::png(out_path, width = 2000, height = 1400, res = 200)
    on.exit(grDevices::dev.off(), add = TRUE)
    plot(tr, cex = 0.5, no.margin = TRUE)
    grDevices::dev.off()
  }
  out_path
}

if (isTRUE(save_plots)) {
  plot_tree_to_file(Utre, outdir, plot_format)
}

# ----------------------------- GMYC run ---------------------------------------
message("Running GMYC method: ", method)
result <- splits::gmyc(Utre, method = method)

# Save result object
saveRDS(result, file.path(outdir, "gmyc_result.rds"))

# Save summary
sink(file.path(outdir, "gmyc_summary.txt"))
print(summary(result))
sink()

# ----------------------------- Export clusters --------------------------------
# spec.list(result) returns a list of clusters with tip labels
spec <- splits::spec.list(result)

# 1) Long format: one row per tip label
clusters_long <- do.call(rbind, lapply(seq_along(spec), function(i) {
  data.frame(
    tip = spec[[i]],
    cluster = sprintf("gmyc_%03d", i),
    stringsAsFactors = FALSE
  )
}))

# Ensure all tips are represented (if GMYC drops any unexpectedly)
missing_tips <- setdiff(Utre$tip.label, clusters_long$tip)
if (length(missing_tips) > 0) {
  warning(length(missing_tips), " tip(s) not assigned by spec.list(); adding as NA cluster.")
  clusters_long <- rbind(
    clusters_long,
    data.frame(tip = missing_tips, cluster = NA_character_, stringsAsFactors = FALSE)
  )
}

# 2) Species list format (one row per cluster with comma-joined members)
species_list <- data.frame(
  cluster = sprintf("gmyc_%03d", seq_along(spec)),
  members = vapply(spec, function(x) paste(x, collapse = ", "), character(1)),
  n_members = vapply(spec, length, integer(1)),
  stringsAsFactors = FALSE
)

utils::write.csv(clusters_long, file.path(outdir, "gmyc_clusters_long.csv"), row.names = FALSE)
utils::write.csv(species_list, file.path(outdir, "gmyc_species_list.csv"), row.names = FALSE)

# Optional XLSX
if (isTRUE(write_xlsx)) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    warning("write_xlsx=TRUE but package 'openxlsx' not installed; skipping XLSX.")
  } else {
    openxlsx::write.xlsx(
      list(
        clusters_long = clusters_long,
        species_list = species_list
      ),
      file.path(outdir, "gmyc_clusters.xlsx"),
      overwrite = TRUE
    )
  }
}

# ----------------------------- Plot GMYC result --------------------------------
plot_gmyc_to_file <- function(res, outdir, fmt = "pdf") {
  out_path <- file.path(outdir, paste0("plots_gmyc.", fmt))
  if (fmt == "pdf") {
    grDevices::pdf(out_path, width = 11, height = 8.5)
    on.exit(grDevices::dev.off(), add = TRUE)
    plot(res)
    grDevices::dev.off()
  } else {
    grDevices::png(out_path, width = 2000, height = 1400, res = 200)
    on.exit(grDevices::dev.off(), add = TRUE)
    plot(res)
    grDevices::dev.off()
  }
  out_path
}

if (isTRUE(save_plots)) {
  plot_gmyc_to_file(result, outdir, plot_format)
}

message("\nAll done. Results in: ", normalizePath(outdir))
message("Clusters inferred: ", length(spec))