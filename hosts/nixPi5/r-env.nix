{ pkgs }:

pkgs.rWrapper.override {
  packages = with pkgs.rPackages; [
    shiny
    DBI
    dbplyr
    echarts4r
    htmlwidgets
    reactable
    rhino
    rlang
    RSQLite
    shinyWidgets
    styler
    tidyr
    treesitter
    treesitter_r
    cranlogs
    dplyr
    httr2
    jsonlite
    scales
    stringr
  ];
}
