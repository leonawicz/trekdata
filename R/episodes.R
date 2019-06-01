st_script_info <- function(){
  url <- "https://scifi.media/star-trek/transcripts/"
  x <- xml2::read_html(url) %>% rvest::html_nodes(".fusion-text p") %>% rvest::html_children()
  urls <- rvest::html_attr(x, "href")
  txt <- rvest::html_text(x)

  .season_sub <- function(x){
    name <- c("One", "Two", "Three", "Four", "Five", "Six", "Seven")
    suppressWarnings(
      as.integer(paste0(sapply(1:7, function(i) if(grepl(name[i], x)) gsub(paste0(".*", name[i]), i, x) else ""), collapse = ""))
    )
  }
  season <- ifelse(grepl("^Season .*", txt), sapply(txt, .season_sub), NA)

  number <- as.integer(ifelse(grepl("^Episode \\d.*", txt), gsub("^Episode (\\d+).*", "\\1", txt), NA))

  .clean <- function(x){
    x <- gsub("\u2010|\u2011|\u2012|\u2013|\u2014|\u2015", "-", x)
    x <- gsub("\u2018|\u2019", "'", x)
    x <- gsub("\u201C|\u201D", "\"", x)
    x <- gsub("\u2026", "...", x)
    x <- gsub("^\"|\"$", "", x)
    tools::toTitleCase(trimws(x))
  }
  .rs <- function(x) gsub("Part I$", "Part 1", romans_sub(x))
  title <- ifelse(grepl("^Episode \\d.*(:|.) ", txt), gsub("^Episode \\d+(:|.) (.*)", "\\2", .rs(txt)),
                  ifelse(grepl("^Star Trek", txt), .rs(txt), NA)) %>% .clean()

  fmt <- rep("episode", length(title))
  idx <- 1:(which(is.na(title))[1] - 1)
  fmt[idx] <- "movie"
  number[idx] <- idx
  series <- rep(NA, length(title))
  series_abb <- c("TOS", "TNG", "DS9", "VOY", "ENT")
  series[which(season == 1)] <- series_abb[c(2:5, 1)]
  series[1:6] <- "TOS"
  series[7:10] <- "TNG"
  series <- factor(series, levels = series_abb)

  tibble::tibble(format = fmt, series = series, season = season,
                 number = as.integer(number), title = title, url = urls) %>%
    tidyr::fill(.data[["series"]], .data[["season"]]) %>%
    dplyr::filter(!is.na(.data[["number"]])) %>%
    dplyr::group_by(.data[["format"]], .data[["series"]]) %>%
    tidyr::complete(number = tidyr::full_seq(.data[["number"]], 1)) %>% dplyr::ungroup() %>%
    dplyr::arrange(.data[["format"]], .data[["series"]], .data[["number"]]) %>%
    dplyr::mutate(series = as.character(.data[["series"]])) %>%
    tidyr::fill(.data[["season"]])
}