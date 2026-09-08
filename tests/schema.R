library(vennabers)
error <- function(expr, pattern = "") {
  result <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(result, "error"), grepl(pattern, conditionMessage(result)))
}
# Schema construction/encoding does not require optional integration packages.
d <- data.frame(x = c(.13, .81, .37), z = factor(c("a b", "a-b", "a b")),
                y = factor(c("class", ".pred_yes", "class"), levels = c("class", ".pred_yes")))
names(d) <- c("vaV0001", "ümlaut", ".pred_class")
s <- venn_abers_schema(d, ".pred_class", event_level = "second")
e <- venn_abers_encode(d, s)
stopifnot(identical(s, venn_abers_schema(d[3:1, ], ".pred_class", event_level = "second")),
          identical(s$encoded_outcome, unname(s$columns[[".pred_class"]])),
          identical(e[[s$columns[["vaV0001"]]]], d[["vaV0001"]]),
          identical(e[[s$columns[["ümlaut"]]]], d[["ümlaut"]]),
          identical(levels(e[[s$encoded_outcome]]), unname(s$classes)),
          identical(s$event_class, ".pred_yes"))
reordered <- d[c(3, 2, 1)]
reordered[[s$outcome]] <- factor(reordered[[s$outcome]], levels = rev(levels(d[[s$outcome]])))
stopifnot(identical(venn_abers_encode(reordered, s), e),
          nrow(venn_abers_encode(d[0, ], s)) == 0L,
          !s$encoded_outcome %in% names(venn_abers_encode(d[1:2], s)))
error(venn_abers_encode(d[1], s), "missing")
error(venn_abers_encode(cbind(d, extra = 1), s), "Unknown")
for (bad_names in list(c("x", "x", "y"), c("", "z", "y"), c(NA, "z", "y"))) {
  bad <- d; names(bad) <- bad_names
  error(venn_abers_schema(bad, "y"), "name")
  error(venn_abers_encode(bad, s), "name")
}
bad <- d; bad[[s$outcome]] <- factor(c("new", "class", "class"))
error(venn_abers_encode(bad, s), "Unknown")
for (field in names(s)) {
  bad <- s; bad[[field]] <- NULL
  error(venn_abers_encode(d, bad), "schema")
}
bad <- s; bad$columns <- bad$columns[-1]
error(venn_abers_encode(d, bad), "schema")
bad <- s; bad$classes[2] <- bad$classes[1]
error(venn_abers_encode(d, bad), "schema")
# Decoding uses exact probability names, retaining dimensions and separate roles.
p <- setNames(data.frame(c(.1, .9, .3), c(.9, .1, .7)), paste0(".pred_", unname(s$classes)))
p$.pred_class <- factor(c(s$classes[2], s$classes[1], s$classes[2]), levels = unname(s$classes))
p[[s$encoded_outcome]] <- e[[s$encoded_outcome]]
p$.row <- c(3L, 1L, 2L); p$id <- c("Repeat1", "Repeat1", "Repeat2")
p$id2 <- c("Fold2", "Fold1", "Fold1"); p$.config <- rep("pre0_mod0_post0", 3)
for (rows in list(1:3, 1L, integer())) {
  native <- p[rows, rev(names(p)), drop = FALSE]
  decoded <- venn_abers_decode(native, s)
  stopifnot(identical(colnames(decoded$probability), s$class_levels),
            identical(dim(decoded$probability), c(length(rows), 2L)),
            identical(unname(decoded$probability[, 1]), c(.1, .9, .3)[rows]),
            identical(decoded$class, factor(c(".pred_yes", "class", ".pred_yes")[rows], levels = s$class_levels)),
            identical(decoded$truth, d[[s$outcome]][rows]), identical(decoded$outcome, s$outcome),
            identical(decoded$identity, native[c(".config", "id2", "id", ".row")]))
}
only <- venn_abers_decode(p[1:2], s)
stopifnot(is.null(only$class), is.null(only$truth), is.null(only$details), is.null(only$identity))
error(venn_abers_decode(p[-1], s), "probabilit")
bad <- p; names(bad)[2] <- names(bad)[1]
error(venn_abers_decode(bad, s), "name")
bad <- p; names(bad)[1] <- ".pred_unknown"
error(venn_abers_decode(bad, s), "probabilit")
bad <- p; bad$.pred_class <- factor("vaL9999")
error(venn_abers_decode(bad, s), "Unknown")
bad <- p; attr(bad, "vennabers_schema") <- venn_abers_schema(d, s$outcome)
error(venn_abers_decode(bad, s), "different schema")
# A code-looking original is encoded by its own identity, even at another position.
shifted <- d[c(3, 2, 1)]
shifted[[2]] <- as.Date("2020-01-01") + 1:3
ss <- venn_abers_schema(shifted, ".pred_class")
se <- venn_abers_encode(shifted, ss)
stopifnot(ss$columns[["vaV0001"]] != "vaV0001", identical(se[[3]], d[[1]]),
          identical(se[[2]], shifted[[2]]), identical(rownames(se), rownames(shifted)))
for (value in c("", NA_character_)) {
  bad <- d; levels(bad[[s$outcome]]) <- c("class", value)
  error(venn_abers_schema(bad, s$outcome))
}
bad <- d; bad[[s$outcome]][1] <- NA
stopifnot(is.na(venn_abers_encode(bad, s)[[s$encoded_outcome]][1]))
