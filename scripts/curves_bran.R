## Join the chl tables (context run) with BRAN on the ice grid, and ask whether
## the physical state at and after retreat explains the bloom.
##
##   Rscript scripts/curves_bran.R CHLDIR BRANDIR [outdir=trend-ice-curves-bran]
##
## CHLDIR: chl_dsr_<y>, cells (run_chl_context.R); BRANDIR: bran_icegrid_<y>
## (bran_to_icegrid.R). Off-shelf cells only.
##
## Per cell-year (retreat day R from the chl rows):
##   BRAN state, read from the BRAN tables directly (not limited to rows with
##   usable chl, which near retreat are mostly ice-adjacent):
##     *_at   mean over composites with mid in R-5 .. R+5
##     *_post mean over composites with mid in R .. R+20 (the stratifying layer)
##   bloom, from clean chl rows (no ice within ~75 km):
##     peak  max log10 chl over dsr 0..60 (>= 3 composites)
##     pre   mean log10 chl over dsr -30..-1 from all rows (>= 2), so
##     amp   = peak - pre where available
## MLD terciles are taken within each retreat-timing tercile, so timing and
## MLD are not confounded. Writes summaries, rank correlations and curves.

source("R/curves.R")
args <- commandArgs(trailingOnly = TRUE)
chldir <- path.expand(args[1]); brandir <- path.expand(args[2])
outdir <- path.expand(if (length(args) >= 3) args[3] else "trend-ice-curves-bran")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

read_any <- function(f) {
  if (grepl("parquet$", f)) as.data.frame(arrow::read_parquet(f)) else utils::read.csv(f)
}
find1 <- function(dir, stem) {
  f <- list.files(dir, pattern = sprintf("^%s\\.(parquet|csv\\.gz)$", stem), full.names = TRUE)
  if (length(f)) f[1] else NA_character_
}

cells <- read_any(find1(chldir, "cells"))
offshelf <- if ("depth" %in% names(cells)) cells$cell[!is.na(cells$depth) & cells$depth <= -1000] else cells$cell
years <- sort(as.integer(sub("^chl_dsr_([0-9]{4})\\..*$", "\\1",
                             list.files(chldir, pattern = "^chl_dsr_[0-9]{4}\\."))))
rows <- list(); cys <- list()
for (y in years) {
  ch <- read_any(find1(chldir, sprintf("chl_dsr_%d", y)))
  ch <- ch[ch$cell %in% offshelf, c("cell", "ice_year", "mid", "dsr", "log10chl", "ice_near")]
  ch$mid <- as.Date(ch$mid)
  ch$clean <- !is.na(ch$ice_near) & ch$ice_near == 0
  ## retreat date per cell-year
  ch$rdate <- ch$mid - ch$dsr
  cy <- unique(ch[c("cell", "ice_year", "rdate")])
  ## BRAN state from the BRAN tables, calendar years y and y + 1
  bf <- na.omit(c(find1(brandir, sprintf("bran_icegrid_%d", y)), find1(brandir, sprintf("bran_icegrid_%d", y + 1L))))
  if (length(bf)) {
    br <- do.call(rbind, lapply(bf, read_any))
    br$mid <- as.Date(br$mid)
    br <- br[br$cell %in% cy$cell, ]
    b <- merge(br, cy, by = "cell")
    b$d <- as.integer(b$mid - b$rdate)
    agg <- function(sel, suffix) {
      x <- b[sel, ]
      k <- paste(x$cell, x$ice_year)
      out <- data.frame(key = unique(k))
      for (v in c("mld", "temp", "salt")) out[[paste0(v, suffix)]] <- tapply(x[[v]], k, mean, na.rm = TRUE)[out$key]
      out
    }
    st <- merge(agg(b$d >= -5 & b$d <= 5, "_at"), agg(b$d >= 0 & b$d <= 20, "_post"), by = "key", all = TRUE)
    cy$key <- paste(cy$cell, cy$ice_year)
    cy <- merge(cy, st, by = "key", all.x = TRUE)
  }
  message(y, ": ", nrow(cy), " cell-years, ", round(100 * mean(!is.na(cy$mld_post))), "% with BRAN after retreat")
  rows[[length(rows) + 1]] <- ch[, c("cell", "ice_year", "mid", "dsr", "log10chl", "clean")]
  cys[[length(cys) + 1]] <- cy
}
tab <- do.call(rbind, rows)
cy <- do.call(rbind, cys)
cy$key <- paste(cy$cell, cy$ice_year)
tab$key <- paste(tab$cell, tab$ice_year)

## timing terciles (all rows), bloom metrics
tab$timing <- retreat_timing(tab)$timing
post <- tab[tab$clean & tab$dsr >= 0 & tab$dsr <= 60, ]
pre <- tab[tab$dsr >= -30 & tab$dsr <= -1, ]
np <- table(post$key); nq <- table(pre$key)
cy$peak <- tapply(post$log10chl, post$key, max)[cy$key]
cy$peak[is.na(np[cy$key]) | np[cy$key] < 3] <- NA
cy$pre <- tapply(pre$log10chl, pre$key, mean)[cy$key]
cy$pre[is.na(nq[cy$key]) | nq[cy$key] < 2] <- NA
cy$amp <- cy$peak - cy$pre
cy$timing <- tab$timing[match(cy$key, tab$key)]
d <- cy[!is.na(cy$peak) & !is.na(cy$mld_post) & !is.na(cy$timing), ]
message(nrow(d), " cell-years with a bloom peak and BRAN after retreat; ",
        sum(!is.na(d$amp)), " also with a pre-retreat level")

## MLD (after retreat) terciles within each timing class
d$mld_t <- NA_character_
for (tm in levels(d$timing)) {
  i <- which(d$timing == tm)
  b <- quantile(d$mld_post[i], c(1/3, 2/3), na.rm = TRUE)
  d$mld_t[i] <- as.character(cut(d$mld_post[i], c(-Inf, b, Inf), labels = c("shallow", "mid", "deep")))
}
d$mld_t <- factor(d$mld_t, levels = c("shallow", "mid", "deep"))

w <- function(x, name) utils::write.csv(x, file.path(outdir, paste0(name, ".csv")), row.names = FALSE)
summ <- do.call(rbind, lapply(split(d, list(d$timing, d$mld_t), drop = TRUE), function(x)
  data.frame(timing = x$timing[1], mld_t = x$mld_t[1], n = nrow(x),
             mld_post_med = median(x$mld_post), temp_post_med = median(x$temp_post, na.rm = TRUE),
             salt_post_med = median(x$salt_post, na.rm = TRUE),
             peak_med = median(x$peak), n_amp = sum(!is.na(x$amp)), amp_med = median(x$amp, na.rm = TRUE))))
summ <- summ[order(summ$timing, summ$mld_t), ]
w(summ, "bloom_by_timing_mld")
rho <- function(a, b) suppressWarnings(cor(a, b, method = "spearman", use = "complete.obs"))
cors <- do.call(rbind, lapply(split(d, d$timing), function(x)
  data.frame(timing = x$timing[1], n = nrow(x),
             peak_mld = rho(x$peak, x$mld_post), peak_temp = rho(x$peak, x$temp_post),
             peak_salt = rho(x$peak, x$salt_post),
             n_amp = sum(!is.na(x$amp)), amp_mld = rho(x$amp, x$mld_post),
             amp_temp = rho(x$amp, x$temp_post), amp_salt = rho(x$amp, x$salt_post))))
w(cors, "bloom_rank_correlations")
print(summ, row.names = FALSE); print(cors, row.names = FALSE)

## curves by timing x MLD tercile (clean rows)
tab$mld_t <- d$mld_t[match(tab$key, d$key)]
cv <- bin_curve(tab[tab$clean & !is.na(tab$mld_t), ], by = c("timing", "mld_t"))
w(cv, "curve_timing_mld")
for (tm in levels(tab$timing)) {
  plot_curves(cv[cv$timing == tm, ], "mld_t", file.path(outdir, sprintf("curve_%s_by_mld.png", tm)),
              sprintf("Off-shelf, %s retreat: by mixed layer depth 0-20 days after retreat", tm))
}
message("done: ", outdir)
