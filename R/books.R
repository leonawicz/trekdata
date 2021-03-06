# nolint start

#' Copy Star Trek books
#'
#' Copy Star Trek epub files, with some changes.
#'
#' @param in_dir character.
#' @param out_dir character.
#' @param drop_unformatted logical, drop the marked files known to have extremely poor formatting/limited fields.
#'
#' @return returns invisibly
#' @export
#'
#' @examples
#' \dontrun{st_book_copy(in_dir, out_dir)}
st_book_copy <- function(in_dir, out_dir, drop_unformatted = TRUE){
  if(!file.exists(out_dir)){ # runs if directory has not been created, does not check files
    files <- list.files(in_dir, pattern = ".epub$", recursive = TRUE, full.names = TRUE)
    if(drop_unformatted) files <- files[!grepl("UNFORMATTED", files)]
    pat <- " \\(Retail-PubUpd\\)" # updated edition
    pat2 <- " \\(Retail\\)" # previous edition
    idx_updated <- grep(pat, files) # index of updated novels
    updated <- files[idx_updated] # updated novels
    updated_trimmed <- gsub(pat, "", updated) # updated novels, pattern removed
    idx_replaced <- which(gsub(pat2, "", files) %in% updated_trimmed) # which previous edition novels have an updated edition available
    files <- files[-idx_replaced] # all novels minus the previous editions for which an update is in the list
    out <- file.path(out_dir, gsub(paste0(in_dir, "/"), "", files))
    out <- gsub(paste0(pat, "|", pat2, "| UNFORMATTED"), "", out)
    out <- paste0(dirname(out), ".epub")
    purrr::walk(dirname(out), ~dir.create(.x, showWarnings = FALSE, recursive = TRUE))
    file.copy(files, out)
    cat("Files copied.\n")
  }
  invisible()
}

# nolint end

.st_chapcheck1 <- c("INVINCIBLE", "Have Tech, Will Travel", "SPARTACUS", "WAR DRUMS", "THE ROMULAN STRATAGEM",
                   "ROGUE SAUCER", "I,Q", "GEMWORLD: BOOK ONE OF TWO", "The Genesis Wave Book Three",
                   "Star Trek: The Next Generation: The Stuff of Dreams", "Memory Prime")

.st_chapcheck2 <- c("MARTYR", "No Limits", "Spectre", "SPARTACUS", "WAR DRUMS", "THE ROMULAN STRATAGEM",
                   "ROGUE SAUCER", "I,Q", "GEMWORLD: BOOK ONE OF TWO",
                   "Star Trek: The Next Generation: The Stuff of Dreams", "Memory Prime")

.st_pat <- paste0(
  "(C|c)(H|h)(_|\\d)|^i0\\d\\d|000000|c0\\d\\d|^c(\\d$|\\d\\d$)|",
  "tocref\\d|Chapter|chapter_\\d\\d|C\\d-|p\\d_c\\d|^c_\\d|",
  "^bk\\d|^rule\\d|^prt$|_RWTOC|\\d+text-(\\d|\\d\\d)$", collapse = "")

# Star Trek novel overrides
# Pattern helper function specific to Star Trek novels. A function that takes no arguments and returns a named list of three elements: \code{pattern} is a regular expression pattern string,
# \code{chapter_check} is a character vector giving exact (in-metadata) book titles as a filter to only apply the supplemental \code{pattern} to specific books,
# and \code{chapter_doublecheck} is a vector of titles that applies additional checks that may only be necessary and helpful (and non-harmful) for specific titles.
.st_pat_list <- function(){
  list(pattern = "toc_ref\\d|^con$|^i2000\\d|^ref(\\d$|\\d\\d$)|^dreams-\\d",
       chapter_check = .st_chapcheck1, chapter_doublecheck = .st_chapcheck2)
}

# Star Trek novel section filter
# Regular expression pattern for dropping commonly named non-chapter sections that typically apply to popular Star Trek novels.
.st_sec_drop <- "^(C|c)o(v|n|p)|^(T|t)it|^(A|a)ck|^htl|reg(front|back)|signup|isbn|font|css|style|image|logo"

.st_fields <- c("title", "creator", "date", "identifier", "publisher", "file")

.st_series <- function(x, subseries = FALSE, parent_dir = "support_files"){
  x <- strsplit(dirname(x), "/")
  idx <- purrr::map_dbl(x, ~(which(.x == parent_dir) + 1))
  if(subseries) idx <- idx + 1
  x <- purrr::map_chr(seq_along(x), ~x[[.x]][idx[.x]])
  x[x == "All-Series_Crossover"] <- "All-Series/Crossover"
  x
}

st_add_series <- function(d, files){
  dplyr::mutate(d, series = .st_series(files, FALSE), subseries = .st_series(files, TRUE))
}

st_add_dedication <- function(d){
  x <- purrr::map_chr(d[["data"]], ~{
    idx <- grep("^(D|d)ed", substr(.x[["section"]], 1, 3))
    if(length(idx)) .x[["text"]][idx[1]] else as.character(NA)
  })
  dplyr::mutate(d, dedication = x)
}

st_fix_date <- function(x){
  if(!"file" %in% names(x)) return(x)
  y <- stringr::str_extract(x$file, "\\d{8}")
  if(any(is.na(y)) && "subseries" %in% names(x) && !all(is.na(x$subseries))){
    y2 <- stringr::str_extract(x$subseries, "\\d{8}")
    y[is.na(y)] <- y2[is.na(y)]
  }
  if(all(is.na(y))) return(x)
  dplyr::mutate(x, date = ifelse(is.na(y), .data[["date"]],
                                 paste(substr(y, 1, 4), substr(y, 5, 6), substr(y, 7, 8), sep = "-")))
}

st_fix_case <- function(x){
  f <- function(x, authors = FALSE){
    x[!is.na(x)] <- tools::toTitleCase(tolower(x[!is.na(x)]))
    x <- gsub(" & ", " and ", x)
    x <- gsub(" &([A-Za-z])", " and \\1", x)
    if(authors){
      x <- gsub("( [a-z]) ", " \\U\\1\\. ", x, perl = TRUE)
      x <- gsub("(^[A-Za-z]) ", "\\U\\1\\. ", x, perl = TRUE)
      x <- gsub("( Ii+)( |$)", "\\U\\1\\2", x, perl = TRUE)
    }
    x <- gsub("\\s+", " ", x)
    x <- gsub("( Vi$| Vii$| Viii$)", "\\U\\1", x, perl = TRUE)
    x <- gsub("( Ii$| Iii$| X$)", "\\U\\1", x, perl = TRUE)
    paste0(toupper(substr(x, 1, 1)), substring(x, 2))
  }
  if("title" %in% names(x)) x <- dplyr::mutate(x, title = f(.data[["title"]]))
  if("creator" %in% names(x)) x <- dplyr::mutate(x, creator = f(.data[["creator"]], authors = TRUE))
  if("publisher" %in% names(x)) x <- dplyr::mutate(x, publisher = f(.data[["publisher"]]))
  x
}

st_fix_bantam <- function(x){
  a <- c("Bantam Episodes", "Bantam Novels") # nolint
  dplyr::mutate(x, subseries = dplyr::case_when(
    grepl(a[1], .data[["subseries"]]) ~ a[1],
    grepl(a[2], .data[["subseries"]]) ~ a[2],
    TRUE ~ .data[["subseries"]]))
}

st_fix_nchap <- function(x){
  dplyr::mutate(x, nchap = ifelse(.data[["nchap"]] == 0 |
                                    grepl("Bantam Episodes", .data[["subseries"]]) |
                                    (grepl("Bantam Novels", .data[["subseries"]]) & .data[["nchap"]] < 10),
                                  as.integer(NA), .data[["nchap"]]))
}

.st_title_from_file <- function(x){
  files <- gsub("\\.epub$", "", x[["file"]])
  x$title <- purrr::map_chr(files, ~paste0(strsplit(.x, " - ")[[1]][-1], collapse = ": "))
  x
}

.st_series_from_file <- function(x){
  x$series_abb <- purrr::map_chr(x[["file"]], ~{
    gsub("\\d+ ([A-Z9]+|[A-Z9]+-[A-Z9]+).*", "\\1", strsplit(.x, " - ")[[1]][1])
  })
  x
}

.st_number_from_file <- function(x){
  x$number <- purrr::map_int(x[["file"]], ~{
    a1 <- strsplit(.x, " - ")[[1]][1]
    a2 <- gsub("^\\d+ ([A-Z9]+|[A-Z9]+-[A-Z9]+) (\\d+)", "\\2", a1)
    if(a1 == a2) a2 <- as.integer(NA)
    as.integer(a2)
  })
  x
}

st_series_update <- function(x){
  .st_series_from_file(x) %>% .st_number_from_file()
}

st_author_sub <- function(x){
  dplyr::mutate(x, creator = gsub("(\\.[a-z]\\.)", "\\U\\1", .data[["creator"]], perl = TRUE)) %>%
    dplyr::rename(author = .data[["creator"]])
}

st_pub_sub <- function(x){
  f <- function(x){
    x[stringr::str_detect(x, "Pocket|Packet")] <- "Pocket Books"
    x[stringr::str_detect(x, "Klingon Language Institute")] <- "Klingon Language Institute"
    x[stringr::str_detect(x, "Elysium")] <- "Elysium"
    x[stringr::str_detect(x, "schuster|Schuster|S and s")] <- "Simon and Schuster"
    x[stringr::str_detect(x, "Martin")] <- "St. Martin's Press"
    x[stringr::str_detect(x, "Titan")] <- "Titan Books"
    x[stringr::str_detect(x, "^Bantam$")] <- "Bantam Books"
    x[stringr::str_detect(x, "^Star Trek$")] <- "Simon and Schuster"
    x[x == "NANA"] <- as.character(NA)
    x
  }
  if("publisher" %in% names(x)) x <- dplyr::mutate(x, publisher = f(.data[["publisher"]]))
  x
}

#' Read Star Trek epub files
#'
#' A wrapper around \code{epubr::epub} for Star Trek epub files.
#'
#' @param file character.
#' @param fields character.
#' @param chapter_pattern character.
#' @param add_pattern list.
#' @param cleaner function.
#' @param drop_sections character.
#' @param fix_date logical.
#' @param fix_text logical.
#'
#' @return a data frame
#' @export
#'
#' @examples
#' \dontrun{st_epub(file)}
st_epub <- function(file, fields = NULL, chapter_pattern = NULL, add_pattern = NULL,
                    cleaner = NULL, drop_sections = NULL, fix_date = TRUE, fix_text = TRUE){
  if(is.null(fields)) fields <- .st_fields
  if(is.null(chapter_pattern)) chapter_pattern <- .st_pat
  if(is.null(add_pattern)) add_pattern <- .st_pat_list()
  if(is.null(drop_sections)) drop_sections <- .st_sec_drop
  d <- epubr::epub(file, fields = fields, drop_sections = drop_sections, chapter_pattern = chapter_pattern,
                   add_pattern = add_pattern)
  d <- st_add_series(d, file) %>% st_add_dedication() %>% st_series_update()
  if(fix_date) d <- st_fix_date(d)
  d <- st_fix_bantam(d)
  d <- st_fix_nchap(d)
  if(fix_text){
    d <- st_fix_case(d)
    d <- .st_title_from_file(d)
    d <- st_author_sub(d) %>% st_pub_sub()
    d <- dplyr::mutate_if(d, is.character, trimws)
  }
  if(is.function(cleaner)){
    nested <- names(d$data[[1]])
    d <- tidyr::unnest(d, .data[["data"]])
    d <- dplyr::mutate(d, text = cleaner(.data[["text"]]))
    d <- tidyr::nest(d, !! nested)
  }
  d
}

#' Testing function for Star Trek books
#'
#' A testing function for reading Star Trek epub files with \code{epubr::epub} or \code{st_epub}.
#'
#' @param file character.
#' @param details logical.
#' @param add_tail logical.
#' @param default_reader logical.
#'
#' @return returns invisibly
#' @export
#'
#' @examples
#' \dontrun{st_epub_test(file)}
st_epub_test <- function(file, details = FALSE, add_tail = FALSE, default_reader = FALSE){
  read <- if(default_reader) epubr::epub else st_epub
  x <- read(file)
  if(!all(c("title", "creator") %in% names(x))) warning("`title` and/or `author` missing.")
  if("nchap" %in% names(x) && x$nchap == 0) warning("`nchap` is zero.")
  if(nrow(x$data[[1]]) < 5) warning("Content data frame has fewer than five rows.")
  if(details){
    print(x)
    print(x$data[[1]])
    if(add_tail) print(utils::tail(x$data[[1]]))
  }
  cat("Checks completed. ---- ", x$title, "\n")
  invisible()
}
