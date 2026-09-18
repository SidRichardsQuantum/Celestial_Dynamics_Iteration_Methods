# A derived in-memory index: history JSON remains authoritative.
studio_gallery_index = function(records, presets = studio_presets()) {
  if (!length(records)) return(data.frame())
  rows = lapply(names(records), function(path) {
    row = studio_gallery_metadata(records[[path]], presets)
    row$path = path
    row
  })
  do.call(rbind, rows)
}

studio_gallery_page = function(index, scope = "all", query = "", page = 1L, page_size = 12L) {
  if (length(page_size) != 1L || !page_size %in% c(6L, 12L, 24L, 48L)) stop("Invalid page size.")
  if (length(page) != 1L || !is.finite(page) || page < 1) page = 1L
  if (nrow(index)) {
    keep = switch(scope, all = rep(TRUE, nrow(index)), favorites = index$favorite,
      failed = index$status == "failed", cancelled = index$status == "cancelled",
      active = index$status %in% c("queued", "running"), index$system == scope)
    if (nzchar(trimws(query))) {
      haystack = paste(index$title, index$preset, index$system, index$integrator, index$id)
      keep = keep & grepl(tolower(trimws(query)), tolower(haystack), fixed = TRUE)
    }
    index = index[keep, , drop = FALSE]
  }
  total = nrow(index)
  pages = max(1L, ceiling(total / page_size))
  page = as.integer(min(page, pages))
  first = if (total) (page - 1L) * page_size + 1L else 0L
  last = min(total, page * page_size)
  rows = if (total) index[seq.int(first, last), , drop = FALSE] else index
  list(rows = rows, page = page, pages = pages, total = total, first = first, last = last)
}

# Cache PNG bytes only, with bounded memory and LRU eviction. A changed or
# deleted file invalidates its entry; browsing never computes a new trajectory.
studio_preview_cache = function(max_entries = 48L, max_bytes = 8 * 1024^2) {
  if (!is.numeric(max_entries) || length(max_entries) != 1L || !is.finite(max_entries) || max_entries < 1 ||
      !is.numeric(max_bytes) || length(max_bytes) != 1L || !is.finite(max_bytes) || max_bytes < 1) {
    stop("Preview cache limits must be positive finite numbers.")
  }
  entries = list()
  used = character()
  reads = 0L
  get_preview = function(path) {
    info = file.info(path)
    if (!nrow(info) || is.na(info$size) || isTRUE(info$isdir)) {
      entries[[path]] <<- NULL
      used <<- setdiff(used, path)
      return(NULL)
    }
    signature = c(info$size, as.numeric(info$mtime), as.numeric(info$ctime))
    entry = entries[[path]]
    if (is.null(entry) || !identical(signature, entry$signature)) {
      bytes = readBin(path, "raw", info$size)
      reads <<- reads + 1L
      entry = list(signature = signature, bytes = bytes, key = unname(tools::md5sum(path)))
      entries[[path]] <<- entry
    }
    used <<- c(setdiff(used, path), path)
    while (length(used) > max_entries || sum(vapply(entries, function(x) length(x$bytes), numeric(1))) > max_bytes) {
      entries[[used[1]]] <<- NULL
      used <<- used[-1]
    }
    entry
  }
  list(get = get_preview, stats = function() list(entries = length(entries), reads = reads,
    bytes = sum(vapply(entries, function(x) length(x$bytes), numeric(1)))))
}
