if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  request = studio_preset("circular_two_body")
  records = setNames(lapply(seq_len(29), function(i) list(id = paste0("run-", i),
    request = request, timestamp = "2026-09-18T12:00:00Z", status = "completed",
    favorite = i %% 2 == 0, preset = "circular_two_body")), paste0("path-", seq_len(29)))
  index = studio_gallery_index(records)
  pages = lapply(1:3, function(i) studio_gallery_page(index, page = i))
  stopifnot(identical(vapply(pages, function(p) nrow(p$rows), integer(1)), c(12L, 12L, 5L)),
    identical(unlist(lapply(pages, function(p) p$rows$path)), index$path),
    studio_gallery_page(index, page = 99)$page == 3L,
    studio_gallery_page(index, scope = "favorites")$total == 14L,
    studio_gallery_page(index, query = "RK4")$total == 29L,
    studio_gallery_page(index, scope = "failed")$total == 0L,
    studio_gallery_page(index, query = "does not exist", page = 5)$page == 1L,
    studio_gallery_page(data.frame())$first == 0L,
    studio_gallery_page(index, page_size = 6)$pages == 5L)
  directory = tempfile("preview-cache-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  files = file.path(directory, c("a.png", "b.png", "c.png"))
  for (i in seq_along(files)) writeBin(as.raw(rep(i, 100)), files[i])
  cache = studio_preview_cache(max_entries = 2, max_bytes = 250)
  first = cache$get(files[1])
  stopifnot(identical(first, cache$get(files[1])), cache$stats()$reads == 1L)
  cache$get(files[2]); cache$get(files[3])
  stopifnot(cache$stats()$entries == 2, cache$stats()$bytes <= 250)
  cache$get(files[1])
  stopifnot(cache$stats()$reads == 4L)
  writeBin(as.raw(rep(4, 120)), files[1])
  stopifnot(cache$get(files[1])$key != first$key, cache$stats()$reads == 5L)
  unlink(files[1])
  stopifnot(is.null(cache$get(files[1])))
  cat("Gallery pagination, filters, cache hits, eviction and invalidation passed.\n")
})
