############################################################
# BioGeoBEARS pipeline
# Author: O., KO.
# Date: 2025‑05‑07
#
# Purpose: Run the full model set (DEC, DEC+J, DIVALIKE, DIVALIKE+J,
#          BAYAREALIKE, BAYAREALIKE+J) on a user‑supplied phylogeny
#          and geography matrix, then output:
#           * AIC‑ready model comparison table (CSV)
#           * Per‑model Rdata objects
#           * Per‑model ancestral‑range plots — **two pages per model**:
#                ‑ Page 1: Most‑probable ranges (single‑state labels)
#                ‑ Page 2: Ancestral‑range probability pies
############################################################

############################
# ==== USER INPUTS ========
############################
# Absolute or relative paths (use "/" on all OS)
TREE_FILE      <- "bitimetree_uce.nwk"      # <-- EDIT
GEOG_FILE      <- "geography_file_UCE.txt"       # <-- EDIT (PHYLIP format)
OUTPUT_DIR     <- "Output_UCE/"      # <-- EDIT
#MAX_RANGE_SIZE <- 4                           # adjust if needed
MAX_RANGE_SIZE <- ncol(tipranges@df) # Max Ranges
N_CORES        <- max(1, parallel::detectCores() - 1)  # use all but one core


############################
# ==== SET‑UP =============
############################
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

# Load / install packages ------------------------------------------------
req_pkgs <- c("pacman", "BioGeoBEARS", "GenSA", "FD", "rexpokit", "cladoRcpp", "parallel")
missing  <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)

pacman::p_load(char = req_pkgs)

# Simple logger ----------------------------------------------------------
log_file   <- file.path(OUTPUT_DIR, "biogeobears_run.log")
if (file.exists(log_file)) file.remove(log_file)
log_con    <- file(log_file, open = "wt")
log_msg    <- function(...) cat(sprintf("[%s] ", Sys.time()), ..., "\n", file = log_con, append = TRUE)
log_msg("BioGeoBEARS pipeline started")

############################
# ==== HELPER FUNCTIONS ===
############################
# Create and tweak a BioGeoBEARS_run object -----------------------------
init_run <- function(model, with_J) {
  run <- define_BioGeoBEARS_run()
  run$trfn              <- TREE_FILE
  run$geogfn            <- GEOG_FILE
  run$max_range_size    <- MAX_RANGE_SIZE
  run$include_null_range<- TRUE
  run$min_branchlength  <- 1e-6
  run$on_NaN_error      <- -1e50
  run$speedup           <- TRUE
  run$use_optimx        <- "GenSA"
  run$num_cores_to_use  <- N_CORES
  run$force_sparse      <- FALSE
  run <- readfiles_BioGeoBEARS_run(run)
  
  # Model‑specific tweaks ----------------------------------------------
  switch(model,
         DIVALIKE = {
           run$BioGeoBEARS_model_object@params_table["s",c("type","init","est")] <- list("fixed",0,0)
           run$BioGeoBEARS_model_object@params_table["ysv","type"] <- "2-j"
           run$BioGeoBEARS_model_object@params_table["ys","type"]  <- "ysv*1/2"
           run$BioGeoBEARS_model_object@params_table["y","type"]   <- "ysv*1/2"
           run$BioGeoBEARS_model_object@params_table["v","type"]   <- "ysv*1/2"
           run$BioGeoBEARS_model_object@params_table["mx01v",c("type","init","est")] <- list("fixed",0.5,0.5)
         },
         BAYAREALIKE = {
           run$BioGeoBEARS_model_object@params_table["s",c("type","init","est")] <- list("fixed",0,0)
           run$BioGeoBEARS_model_object@params_table["v",c("type","init","est")] <- list("fixed",0,0)
           run$BioGeoBEARS_model_object@params_table["ysv","type"] <- "1-j"
           run$BioGeoBEARS_model_object@params_table["ys","type"]  <- "ysv*1/1"
           run$BioGeoBEARS_model_object@params_table["y","type"]   <- "1-j"
           run$BioGeoBEARS_model_object@params_table["mx01y",c("type","init","est")] <- list("fixed",0.9999,0.9999)
         }
  )
  
  # Enable +J if requested ---------------------------------------------
  if (with_J) {
    run$BioGeoBEARS_model_object@params_table["j","type"] <- "free"
    run$BioGeoBEARS_model_object@params_table["j",c("init","est")] <- 0.0001
    run$BioGeoBEARS_model_object@params_table["j","max"]  <- switch(model,
                                                                    DEC = 2.9999,
                                                                    DIVALIKE = 1.9999,
                                                                    BAYAREALIKE = 0.9999)
  }
  invisible(run)
}

# Run one model safely ---------------------------------------------------
run_model <- function(model, with_J) {
  label   <- paste0(model, if (with_J) "+J" else "")
  outpref <- file.path(OUTPUT_DIR, label)
  log_msg("Running ", label)
  
  res <- tryCatch({
    r <- init_run(model, with_J)
    check_BioGeoBEARS_run(r)
    bears_optim_run(r)
  }, error = function(e) {
    log_msg("ERROR in ", label, ": ", e$message)
    return(NULL)
  })
  if (is.null(res)) return(NULL)
  
  save(res, file = paste0(outpref, ".Rdata"))
  
  # --- Dual‑page A4 PDF -------------------------------------------------
  pdf(paste0(outpref, ".pdf"), width = 8.27, height = 11.69)
  tr        <- read.tree(TREE_FILE)
  tipranges <- getranges_from_LagrangePHYLIP(lgdata_fn = GEOG_FILE)
  
  # Page 1 – most‑probable state text
  plot_BioGeoBEARS_results(res, label,
                           plotwhat = "text",
                           addl_params = list("j"),
                           label.offset = 0.45, tipcex = 0.7,
                           statecex = 0.8, titlecex = 0.85,
                           plotsplits = TRUE, splitcex = 0.6,
                           cornercoords_loc = system.file("extdata/a_scripts", package="BioGeoBEARS"),
                           include_null_range = TRUE,
                           tr = tr, tipranges = tipranges)
  # Page 2 – probability pies
  plot_BioGeoBEARS_results(res, label,
                           plotwhat = "pie",
                           addl_params = list("j"),
                           label.offset = 0.45, tipcex = 0.7,
                           statecex = 0.7, titlecex = 0.85,
                           plotsplits = TRUE, splitcex = 0.6,
                           cornercoords_loc = system.file("extdata/a_scripts", package="BioGeoBEARS"),
                           include_null_range = TRUE,
                           tr = tr, tipranges = tipranges)
  dev.off()
  res
}

############################
# ==== MAIN LOOP ==========
############################
models   <- c("DEC", "DIVALIKE", "BAYAREALIKE")
results  <- list()

for (m in models) {
  results[[m]]                <- run_model(m, FALSE)
  results[[paste0(m, "+J")]] <- run_model(m, TRUE)
}

# Remove failed runs -----------------------------------------------------
results <- Filter(Negate(is.null), results)

############################
# ==== MODEL COMPARISON ===
############################
if (length(results) == 0)
  stop("All model runs failed; see log for details.")

summary_tbl <- do.call(rbind, lapply(names(results), function(n) {
  tbl <- extract_params_from_BioGeoBEARS_results_object(
    results[[n]], returnwhat = "table",
    addl_params = c("j"), paramsstr_digits = 4)
  data.frame(Model = n, tbl, stringsAsFactors = FALSE)
}))

# Add LnL and k ----------------------------------------------------------
summary_tbl$LnL       <- sapply(results, get_LnL_from_BioGeoBEARS_results_object)
summary_tbl$numparams <- ifelse(grepl("\\+J$", summary_tbl$Model), 3, 2)

# Compute AIC statistics -------------------------------------------------
AICcols <- calc_AIC_column(LnL_vals = summary_tbl$LnL,
                           nparam_vals = summary_tbl$numparams)
summary_tbl <- cbind(summary_tbl, AICcols)

# Write to CSV -----------------------------------------------------------
write.csv(summary_tbl,
          file = file.path(OUTPUT_DIR, "biogeobears_model_tests.csv"),
          row.names = FALSE)

############################
# ==== FINISH =============
############################
log_msg("Pipeline finished successfully")
close(log_con)
cat("\nAll done! See outputs in:", OUTPUT_DIR, "\n")

