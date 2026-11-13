## Join the chl tables (context run) with BRAN on the ice grid, and ask whether
## the physical state at retreat explains the bloom.
##
##   Rscript scripts/curves_bran.R CHLDIR BRANDIR [outdir=trend-ice-curves-bran]
##
## CHLDIR: chl_dsr_<y>, cells (run_chl_context.R); BRANDIR: bran_icegrid_<y>
## (bran_to_icegrid.R). Off-shelf, clean rows (no ice within ~75 km).
## Per cell-year "at retreat" = mean over dsr -5..5 of mld, temp, salt.
## Bloom amplitude per cell-year = max log10 chl over dsr 0..60 minus mean
## over dsr -30..-1 (>= 3 composites each side).
## Writes: curves by retreat timing x MLD-at-retreat tercile (terciles within
## each timing class, so timing and MLD are not confounded), amplitude
## summaries and rank correlations, csv + png.

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
years <- as.integer(sub("^chl_dsr_([0-9]{4})\\..*$", "\\1",
                        list.files(chldir, pattern = "^chl_dsr_[0-9]{4}\\.")))
parts <- list()
for (y in sort(years)) {
  ch <- read_any(find1(chldir, sprintf("chl_dsr_%d", y)))
  ch <- ch[!is.na(ch$ice_near) & ch$ice_near == 0, c("cell", "ice_year", "mid", "dsr", "log10chl")]
  ch$mid <- as.Date(ch$mid)
  bf <- na.omit(c(find1(brandir, sprintf("bran_icegrid_%d", y)), find1(brandir, sprintf("bran_icegrid_%d", y + 1L))))
  if (!length(bf)) { message(y, ": no BRAN"); next }
  br <- do.call(rbind, lapply(bf, read_any))
  br$mid <- as.Date(br$mid)
  br <- br[br$cell %in% ch$cell, ]
  j <- merge(ch, br, by = c("cell", "mid"), all.x = TRUE)
  message(y, ": ", nrow(j), " rows, ", round(100 * mean(!is.na(j$mld))), "% with BRAN")
  parts[[length(parts) + 1]] <- j
}
tab <- do.call(rbind, parts)
ci <- match(tab$cell, cells$cell)
if ("depth" %in% names(cells)) tab <- tab[!is.na(cells$depth[ci]) & cells$depth[ci] <= -1000, ]
tab$timing <- retreat_timing(tab)$timing

## state at retreat and bloom amplitude per cell-year
key <- paste(tab$cell, tab$ice_year)
at <- tab[tab$dsr >= -5 & tab$dsr <= 5, ]
akey <- paste(at$cell, at$ice_year)
state <- data.frame(key = unique(akey))
for (v in c("mld", "temp", "salt")) state[[v]] <- tapply(at[[v]], akey, mean, na.rm = TRUE)[state$key]
pre <- tab[tab$dsr >= -30 & tab$dsr <= -1, ]; post <- tab[tab$dsr >= 0 & tab$dsr <= 60, ]
pk <- paste(pre$cell, pre$ice_year); qk <- paste(post$cell, post$ice_year)
amp <- data.frame(key = intersect(names(which(table(pk) >= 3)), names(which(table(qk) >= 3))))
amp$pre <- tapply(pre$log10chl, pk, mean)[amp$key]
amp$peak <- tapply(post$log10chl, qk, max)[amp$key]
amp$amp <- amp$peak - amp$pre
cy <- merge(amp, state, by = "key")
cy$timing <- tab$timing[match(cy$key, key)]
cy <- cy[!is.na(cy$mld) & !is.na(cy$timing), ]
message(nrow(cy), " cell-years with amplitude and state at retreat")

## MLD terciles within each timing class
cy$mld_t <- NA_character_
for (tm in levels(cy$timing)) {
  i <- which(cy$timing == tm)
  b <- quantile(cy$mld[i], c(1/3, 2/3), na.rm = TRUE)
  cy$mld_t[i] <- as.character(cut(cy$mld[i], c(-Inf, b, Inf), labels = c("shallow", "mid", "deep")))
}
cy$mld_t <- factor(cy$mld_t, levels = c("shallow", "mid", "deep"))

w <- function(x, name) utils::write.csv(x, file.path(outdir, paste0(name, ".csv")), row.names = FALSE)
summ <- do.call(rbind, lapply(split(cy, list(cy$timing, cy$mld_t), drop = TRUE), function(d)
  data.frame(timing = d$timing[1], mld_t = d$mld_t[1], n = nrow(d),
             mld_med = median(d$mld), amp_med = median(d$amp),
             amp_q25 = unname(quantile(d$amp, 0.25)), amp_q75 = unname(quantile(d$amp, 0.75)))))
w(summ[order(summ$timing, summ$mld_t), ], "amplitude_by_timing_mld")
cors <- do.call(rbind, lapply(split(cy, cy$timing), function(d)
  data.frame(timing = d$timing[1], n = nrow(d),
             rho_mld = suppressWarnings(cor(d$amp, d$mld, method = "spearman", use = "complete")),
             rho_temp = suppressWarnings(cor(d$amp, d$temp, method = "spearman", use = "complete")),
             rho_salt = suppressWarnings(cor(d$amp, d$salt, method = "spearman", use = "complete")))))
w(cors, "amplitude_rank_correlations"); print(summ); print(cors)

## curves by timing x MLD tercile
tab$mld_t <- cy$mld_t[match(key, cy$key)]
cv <- bin_curve(tab[!is.na(tab$mld_t), ], by = c("timing", "mld_t"))
w(cv, "curve_timing_mld")
for (tm in levels(tab$timing)) {
  plot_curves(cv[cv$timing == tm, ], "mld_t", file.path(outdir, sprintf("curve_%s_by_mld.png", tm)),
              sprintf("Off-shelf, %s retreat: by mixed layer depth at retreat", tm))
}
message("done: ", outdir)
