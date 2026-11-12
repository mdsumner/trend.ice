## synthetic tables in a temp dir, then run curves_all.R
set.seed(1)
td <- tempfile(); dir.create(td)
for (y in 2001:2002) {
  n <- 20000
  cell <- sample(5000:60000, n, TRUE)
  dsr <- sample(-30:120, n, TRUE)
  mid <- as.Date(sprintf("%d-12-01", y)) + sample(-60:90, n, TRUE)
  d <- data.frame(cell = cell, ice_year = y, mid = mid, dsr = dsr,
                  log10chl = -0.6 + 0.3 * exp(-((dsr - 25) / 20)^2) + rnorm(n, 0, 0.1), n = 30)
  write.csv(d, gzfile(file.path(td, sprintf("chl_dsr_%d.csv.gz", y))), row.names = FALSE)
}
od <- tempfile()
system2("Rscript", c("scripts/curves_all.R", td, od))
print(list.files(od))
pk <- read.csv(file.path(od, "peak_by_year.csv")); print(pk)
stopifnot(all(pk$peak_dsr %in% c(20, 25, 30)))
cat("curves test pass\n")
