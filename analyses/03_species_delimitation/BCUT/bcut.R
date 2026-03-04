#!/usr/bin/env Rscript

# =============================================================================
# Species delimitation via Branch-Cutting on an ML phylogeny
#
# Inputs (provide via CLI args or environment variables):
#   --tree=path/to/treefile
#   --outdir=results_branchcutting
# Optional:
#   --format=auto|newick|nexus
#   --outgroup_regex="regex"         # drop tips whose names match regex (case-insensitive)
#   --outgroup_file=path/to/file.txt # one tip label per line to drop
#   --methods=step,elbow             # branchcutting methods to run (comma-separated)
#   --kernel=rectangular             # kernel for method="step" (if supported)
#   --seed=12345
#   --save_plots=TRUE|FALSE
#   --plot_format=pdf|png
#
# Outputs (written to --outdir):
#   - bcut_<method>_otus.csv
#   - bcut_<method>.rds
#   - bcut_<method>_summary.txt
#   - plots_<method>.(pdf|png) (if save_plots=TRUE)
#   - sessionInfo.txt
#
# Dependencies:
#   - ape (required)
#   - ggtree (only for quick tree visualization)
#   - branchcutting.R (unless you have a branchcutting package installed)
#
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("ape", quietly = TRUE)) {
    stop("Package 'ape' is required. Install with: install.packages('ape')", call. = FALSE)
  }
})

# ----------------------------- CLI parser (base R) ----------------------------
parse_args <- function(x) {
  # Accepts --key=value
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
  # CLI arg takes precedence; then env var; then default
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
tree_path      <- get_opt("tree", "")
outdir         <- get_opt("outdir", "branchcutting_results")
tree_format    <- tolower(get_opt("format", "auto"))        # auto|newick|nexus
outgroup_regex <- get_opt("outgroup_regex", "")             # optional
outgroup_file  <- get_opt("outgroup_file", "")              # optional
methods        <- strsplit(get_opt("methods", "step"), ",", fixed = TRUE)[[1]]
methods        <- trimws(methods)
kernel         <- get_opt("kernel", "rectangular")
seed           <- suppressWarnings(as.integer(get_opt("seed", "12345")))
save_plots     <- as_bool(get_opt("save_plots", "TRUE"), default = TRUE)
plot_format    <- tolower(get_opt("plot_format", "pdf"))    # pdf|png

# ----------------------------- Sanity checks ---------------------------------
if (!nzchar(tree_path)) {
  stop("Missing required input: --tree=path/to/treefile", call. = FALSE)
}
if (!file.exists(tree_path)) {
  stop("Tree file not found: ", tree_path, call. = FALSE)
}
if (!plot_format %in% c("pdf", "png")) {
  stop("--plot_format must be 'pdf' or 'png'", call. = FALSE)
}

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Save session info for reproducibility
sink(file.path(outdir, "sessionInfo.txt"))
cat("Date: ", format(Sys.time(), tz = ""), "\n", sep = "")
cat("Working directory: ", getwd(), "\n", sep = "")
cat("Command: Rscript species_delim_branchcutting.R ",
    paste(commandArgs(trailingOnly = TRUE), collapse = " "), "\n\n", sep = "")
print(sessionInfo())
sink()

set.seed(seed)

# ----------------------------- Load branchcutting -----------------------------
# Prefer sourcing a local branchcutting.R (public repo-friendly), else try package.
load_branchcutting <- function() {
  # If the user ships branchcutting.R alongside this script or in their repo:
  local_path <- "branchcutting.R"
  if (file.exists(local_path)) {
    source(local_path)
  } else {
    # If there is a package called 'branchcutting':
    if (requireNamespace("branchcutting", quietly = TRUE)) {
      suppressPackageStartupMessages(library(branchcutting))
    }
  }

  if (!exists("branchcutting", mode = "function")) {
    stop(
      "Function 'branchcutting()' not found.\n",
      "Provide 'branchcutting.R' in the working directory (recommended for sharing),\n",
      "or install/load the relevant package if you use one.",
      call. = FALSE
    )
  }
}
load_branchcutting()

# ----------------------------- Read tree -----------------------------
read_tree_auto <- function(path, fmt = "auto") {
  # Returns an ape::phylo
  if (fmt == "newick") return(ape::read.tree(path))
  if (fmt == "nexus")  return(ape::read.nexus(path))

  # auto: try Newick first (common for *.treefile), then Nexus
  tr <- tryCatch(ape::read.tree(path), error = function(e) NULL)
  if (!is.null(tr)) return(tr)

  tr <- tryCatch(ape::read.nexus(path), error = function(e) NULL)
  if (!is.null(tr)) return(tr)

  stop("Could not read tree as Newick or Nexus: ", path, call. = FALSE)
}

tre <- read_tree_auto(tree_path, tree_format)

# Optional: show a quick tree plot if ggtree is installed (interactive use)
if (requireNamespace("ggtree", quietly = TRUE)) {
  # Don’t force plotting in non-interactive mode; just note availability
  message("Optional: 'ggtree' available. You can inspect interactively via ggtree::ggtree(tre).")
} else {
  message("Note: 'ggtree' not installed; skipping optional visualization helper.")
}

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

tre <- drop_outgroups(tre, outgroup_regex, outgroup_file)

if (length(tre$tip.label) < 4) {
  stop("Too few tips after outgroup removal (need >= 4).", call. = FALSE)
}

# ----------------------------- Branch-cutting runner --------------------------
make_otus_df <- function(bcut_obj) {
  # bcut$otus is expected to be a list, each element = vector of tip labels for that OTU
  if (is.null(bcut_obj$otus) || !is.list(bcut_obj$otus)) {
    stop("bcut$otus missing or not a list; cannot build OTU table.", call. = FALSE)
  }

  otus <- data.frame(
    ID  = unlist(bcut_obj$otus, use.names = FALSE),
    OTU = rep(seq_along(bcut_obj$otus), vapply(bcut_obj$otus, length, integer(1))),
    stringsAsFactors = FALSE
  )

  # zero-pad (b01, b02, ... b10, etc.)
  otus$bcut <- sprintf("b%02d", otus$OTU)
  otus
}

save_bcut_plots <- function(bcut_obj, method_name, outdir, fmt = "pdf") {
  out_path <- file.path(outdir, paste0("plots_", method_name, ".", fmt))

  if (fmt == "pdf") {
    grDevices::pdf(out_path, width = 11, height = 8.5)
    on.exit(grDevices::dev.off(), add = TRUE)
  } else {
    # png: one file per plot (cleaner than multi-page PNG)
    # We'll handle below by saving four separate PNGs
  }

  plots <- c("tree", "otus", "dens", "loss")

  if (fmt == "pdf") {
    for (w in plots) {
      main <- switch(w,
        dens = "Density plot",
        loss = "Loss plot",
        tree = "Branch-cutting: tree",
        otus = "Branch-cutting: OTUs"
      )
      try(plot(bcut_obj,
               which = w,
               cex = if (w == "tree") 0.5 else NULL,
               no.margin = TRUE,
               edge.width = 3,
               pt.cex = if (w == "otus") 3 else NULL,
               pt.col = if (w == "otus") 2 else NULL,
               main = main),
          silent = TRUE
      )
    }
  } else {
    # PNG: separate files
    for (w in plots) {
      png_path <- file.path(outdir, paste0("plot_", method_name, "_", w, ".png"))
      grDevices::png(png_path, width = 2000, height = 1400, res = 200)
      on.exit(grDevices::dev.off(), add = TRUE)

      main <- switch(w,
        dens = "Density plot",
        loss = "Loss plot",
        tree = "Branch-cutting: tree",
        otus = "Branch-cutting: OTUs"
      )

      try(plot(bcut_obj,
               which = w,
               cex = if (w == "tree") 0.5 else NULL,
               no.margin = TRUE,
               edge.width = 3,
               pt.cex = if (w == "otus") 3 else NULL,
               pt.col = if (w == "otus") 2 else NULL,
               main = main),
          silent = TRUE
      )

      grDevices::dev.off()
    }
  }

  invisible(out_path)
}

run_branchcutting <- function(tr, method_name, kernel = "rectangular") {
  # Some implementations accept kernel only for method="step".
  if (tolower(method_name) == "step") {
    branchcutting(tr, method = "step", kernel = kernel)
  } else {
    branchcutting(tr, method = method_name)
  }
}

# ----------------------------- Execute methods --------------------------------
for (m in methods) {
  if (!nzchar(m)) next
  m_lower <- tolower(m)

  message("Running branch-cutting method: ", m_lower)

  bcut <- run_branchcutting(tre, m_lower, kernel = kernel)

  # Save summary to text
  summ_path <- file.path(outdir, paste0("bcut_", m_lower, "_summary.txt"))
  sink(summ_path)
  print(summary(bcut))
  sink()

  # OTU table
  otus <- make_otus_df(bcut)
  otus_path <- file.path(outdir, paste0("bcut_", m_lower, "_otus.csv"))
  utils::write.csv(otus, otus_path, row.names = FALSE)

  # Save object for reproducibility
  rds_path <- file.path(outdir, paste0("bcut_", m_lower, ".rds"))
  saveRDS(bcut, rds_path)

  # Plots
  if (isTRUE(save_plots)) {
    save_bcut_plots(bcut, m_lower, outdir, fmt = plot_format)
  }

  message("Done: ", m_lower,
          " | OTUs=", length(bcut$otus),
          " | wrote: ", basename(otus_path))
}

message("\nAll done. Results in: ", normalizePath(outdir))