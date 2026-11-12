## curves.R - helpers for binned bloom curves

## 5-day bins of a numeric column, grouped; median and quartiles
bin_curve <- function(d, var = "log10chl", by = NULL, width = 5L) {
  d$bin <- width * (d$dsr %/% width)
  g <- if (is.null(by)) list(bin = d$bin) else c(list(bin = d$bin), d[by])
  f <- function(v) c(q25 = unname(stats::quantile(v, 0.25)), med = stats::median(v),
                     q75 = unname(stats::quantile(v, 0.75)), n = length(v))
  a <- stats::aggregate(d[[var]], g, f)
  out <- data.frame(a[setdiff(names(a), "x")], a$x)
  out[do.call(order, out[c(by, "bin")]), ]
}

plot_curves <- function(cv, by, file, main, ylab = "median log10 chl") {
  grDevices::png(file, width = 1000, height = 650)
  on.exit(grDevices::dev.off())
  grp <- interaction(cv[by], drop = TRUE)
  lv <- levels(grp)
  cols <- grDevices::hcl.colors(length(lv), "Dark 3")
  graphics::plot(cv$bin, cv$med, type = "n", xlab = "days since retreat", ylab = ylab, main = main)
  for (i in seq_along(lv)) {
    s <- cv[grp == lv[i], ]
    graphics::lines(s$bin, s$med, col = cols[i], lwd = 2)
  }
  graphics::abline(v = 0, lty = 2)
  graphics::legend("topright", lv, col = cols, lwd = 2, bty = "n", cex = 0.8)
}

## timing terciles of retreat over all cell-years; returns factor and breaks
retreat_timing <- function(tab) {
  day <- as.integer(as.Date(tab$mid) - as.Date(sprintf("%04d-02-15", tab$ice_year))) + 1L
  retreat <- day - tab$dsr
  cy <- unique(data.frame(cell = tab$cell, ice_year = tab$ice_year, retreat = retreat))
  brk <- stats::quantile(cy$retreat, c(1/3, 2/3))
  list(timing = cut(retreat, c(-Inf, brk, Inf), labels = c("early", "mid", "late")),
       retreat = retreat, breaks = brk)
}

## open-water baseline for each row: median log10 chl of never-iced cells at
## the same composite and sector, in the same 1-degree latitude band or, if
## that band has no open water (high latitudes), the nearest band that does.
## Returns a data.frame: base (the median) and dlat (|band difference| in
## degrees, 0 when the row's own band had open water).
baseline_for <- function(tab, open, lat_band) {
  key_t <- paste(as.Date(tab$mid), tab$sector)
  open$key <- paste(as.Date(open$mid), open$sector)
  base <- rep(NA_real_, nrow(tab))
  dlat <- rep(NA_real_, nrow(tab))
  ok_open <- open[open$ncell >= 5, ]
  idx <- split(seq_len(nrow(tab)), key_t)
  for (k in names(idx)) {
    o <- ok_open[ok_open$key == k, ]
    if (!nrow(o)) next
    i <- idx[[k]]
    ub <- unique(lat_band[i])
    jb <- vapply(ub, function(b) which.min(abs(o$lat_band - b)), integer(1))
    m <- match(lat_band[i], ub)
    base[i] <- o$med[jb[m]]
    dlat[i] <- abs(o$lat_band[jb[m]] - lat_band[i])
  }
  data.frame(base = base, dlat = dlat)
}
