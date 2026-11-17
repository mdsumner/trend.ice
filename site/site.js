// trend.ice site config, read by the shared kit (kit/, synced from
// AustralianAntarcticDivision/trend with tools/kit-sync). Units, metric
// scales and code-generator text for each record are in kit/records.js.
// The kit pages (index, status, mechanics) are plain HTML copied into
// the Quarto build; the analysis pages are .qmd rendered in the kit look.
window.TREND_SITE = {
  record: "ice",
  title: "trend.ice",
  repo: "https://github.com/mdsumner/trend.ice",
  tabs: [["index.html", "Explorer"], ["status.html", "Status"],
         ["overview.html", "Overview"], ["maps.html", "Maps"],
         ["results.html", "Results"], ["methods.html", "Methods"],
         ["data.html", "Data"], ["mechanics.html", "Mechanics"]],
  dataHint: "Run pawsey/export_site.R and commit site/data/.",
  explorer: {
    sources: ["cdr-sic", "asi-sic"],
    // the other records on the same cells, read from their own sites
    family: ["sst:oisst", "chl:occci-log10chl", "sla:sla-cmems"],
    // transverse Mercator on 115E (+proj=tmerc +lon_0=115, as seaice.map),
    // framed on both polar caps (beyond 40S and 40N): the two poles lie on
    // the central meridian, so one map holds the global ice, Antarctic
    // below, Arctic above. frame "south" or "north" frames one cap.
    // Equal Earth and the rest are in the menu.
    view: "tmerc",
    rotate: [-115, 70],
    tmerc: { frame: "both", radius: 50 },
    coast: true
  }
};
