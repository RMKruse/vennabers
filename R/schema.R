#' @export
venn_abers_schema <- function(data, outcome, classification = "binary", event_level = "first") {
  .schema_data_names(data)
  .integration_names(outcome, "outcome")
  if (length(outcome) != 1L || !outcome %in% names(data)) {
    stop("`outcome` must name one column in `data`.", call. = FALSE)
  }
  .validate_choice(classification, "binary", "classification")
  .validate_choice(event_level, c("first", "second"), "event_level")
  y <- data[[outcome]]
  if (!is.factor(y) || nlevels(y) != 2L) {
    stop("Schema outcome must be a factor with exactly two levels.", call. = FALSE)
  }
  .integration_names(levels(y), "class")
  columns <- stats::setNames(sprintf("vaV%04d", seq_along(data)), names(data))
  classes <- stats::setNames(sprintf("vaL%04d", seq_len(nlevels(y))), levels(y))
  structure(list(version = 1L, outcome = outcome, encoded_outcome = unname(columns[[outcome]]),
                 original_columns = names(data), columns = columns, class_levels = levels(y),
                 classes = classes, ordered = is.ordered(y), mode = "classification",
                 classification = classification, event_level = event_level,
                 event_class = levels(y)[if (event_level == "first") 1L else 2L]),
            class = "vennabers_schema")
}

.schema_data_names <- function(data) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  .integration_names(names(data), "input column")
}

.validate_schema <- function(schema) {
  fields <- c("version", "outcome", "encoded_outcome", "original_columns", "columns",
              "class_levels", "classes", "ordered", "mode", "classification", "event_level", "event_class")
  invalid <- function() stop("Invalid or incomplete `schema` mapping.", call. = FALSE)
  if (!inherits(schema, "vennabers_schema") || !is.list(schema) ||
      !identical(names(schema), fields) || !identical(schema$version, 1L)) invalid()
  valid_names <- function(x) is.character(x) && is.vector(x) && length(x) > 0L &&
    !anyNA(x) && all(nzchar(x)) && !anyDuplicated(x)
  if (!valid_names(schema$original_columns) || !valid_names(schema$class_levels) ||
      length(schema$class_levels) != 2L || !valid_names(schema$outcome) ||
      length(schema$outcome) != 1L || !schema$outcome %in% schema$original_columns ||
      !identical(schema$columns, stats::setNames(sprintf("vaV%04d", seq_along(schema$original_columns)), schema$original_columns)) ||
      !identical(schema$classes, stats::setNames(sprintf("vaL%04d", seq_along(schema$class_levels)), schema$class_levels)) ||
      !identical(schema$encoded_outcome, unname(schema$columns[[schema$outcome]])) ||
      !identical(schema$mode, "classification") || !identical(schema$classification, "binary") ||
      !is.logical(schema$ordered) || length(schema$ordered) != 1L || is.na(schema$ordered) ||
      !identical(schema$event_level, "first") && !identical(schema$event_level, "second")) invalid()
  if (!identical(schema$event_class, schema$class_levels[if (schema$event_level == "first") 1L else 2L])) invalid()
  invisible(schema)
}

.schema_binding <- function(x, schema) {
  bound <- attr(x, "vennabers_schema", exact = TRUE)
  if (!is.null(bound) && !identical(bound, schema)) {
    stop("Object is bound to a different schema.", call. = FALSE)
  }
  invisible(NULL)
}

.bind_schema <- function(x, schema) {
  if (!is.null(schema)) attr(x, "vennabers_schema") <- schema
  x
}

#' @export
venn_abers_encode <- function(data, schema) {
  .validate_schema(schema)
  .schema_data_names(data)
  .schema_binding(data, schema)
  unknown <- setdiff(names(data), schema$original_columns)
  required <- setdiff(schema$original_columns, schema$outcome)
  if (length(unknown)) stop("Unknown input columns: ", paste(unknown, collapse = ", "), ".", call. = FALSE)
  if (!all(required %in% names(data))) stop("Input is missing required predictors.", call. = FALSE)
  data <- data[intersect(schema$original_columns, names(data))]
  if (schema$outcome %in% names(data)) {
    y <- data[[schema$outcome]]
    if (!is.factor(y)) stop("Schema outcome must be a factor.", call. = FALSE)
    if (any(!levels(y) %in% schema$class_levels)) stop("Unknown outcome classes.", call. = FALSE)
    data[[schema$outcome]] <- factor(unname(schema$classes[as.character(y)]),
                                    levels = unname(schema$classes), ordered = schema$ordered)
  }
  names(data) <- unname(schema$columns[names(data)])
  .bind_schema(data, schema)
}

.schema_encoded_data <- function(data, schema, truth = FALSE) {
  .validate_schema(schema)
  .schema_data_names(data)
  .schema_binding(data, schema)
  required <- unname(schema$columns)
  if (!truth) required <- setdiff(required, schema$encoded_outcome)
  if (!all(required %in% names(data)) || any(!names(data) %in% schema$columns)) {
    stop("Data must contain the schema's encoded columns (truth is required for fit).", call. = FALSE)
  }
  if (schema$encoded_outcome %in% names(data) &&
      !identical(levels(data[[schema$encoded_outcome]]), unname(schema$classes))) {
    stop("Encoded outcome class order must match the schema; use venn_abers_encode().", call. = FALSE)
  }
  invisible(NULL)
}

.schema_decode_class <- function(x, schema, role) {
  if ((!is.factor(x) && !is.character(x)) ||
      any(!as.character(x)[!is.na(x)] %in% schema$classes) ||
      is.factor(x) && any(!levels(x) %in% schema$classes)) {
    stop("Unknown encoded classes in ", role, ".", call. = FALSE)
  }
  factor(schema$class_levels[match(as.character(x), schema$classes)],
         levels = schema$class_levels, ordered = schema$ordered)
}

#' @export
venn_abers_decode <- function(x, schema) {
  .validate_schema(schema)
  .schema_binding(x, schema)
  if (is.list(x) && !is.data.frame(x) && identical(names(x), c("prediction", "details"))) {
    result <- venn_abers_decode(x$prediction, schema)
    details <- x$details
    .schema_data_names(details)
    .schema_binding(details, schema)
    if (!all(c("row", "fold", "event_class", "lower", "upper", "probability") %in% names(details))) {
      stop("Incomplete binary details.", call. = FALSE)
    }
    details$event_class <- as.character(.schema_decode_class(details$event_class, schema, "details"))
    attr(details, "vennabers_schema") <- NULL
    result$details <- details
    return(result)
  }
  .schema_data_names(x)
  expected <- paste0(".pred_", unname(schema$classes))
  probabilities <- setdiff(names(x)[startsWith(names(x), ".pred_")], ".pred_class")
  if (length(probabilities) && !setequal(probabilities, expected)) {
    stop("Incomplete or unknown probability mapping.", call. = FALSE)
  }
  identities <- names(x)[grepl("^(\\.row|\\.config|id([1-9][0-9]*)?)$", names(x))]
  if (any(!names(x) %in% c(expected, ".pred_class", schema$encoded_outcome, identities))) {
    stop("Unknown encoded output columns.", call. = FALSE)
  }
  result <- list(outcome = schema$outcome)
  if (length(probabilities)) {
    if (!all(vapply(x[expected], .valid_probability, logical(1))) || any(abs(rowSums(x[expected]) - 1) > 1e-8)) {
      stop("Invalid class probabilities.", call. = FALSE)
    }
    result$probability <- as.matrix(x[expected])
    storage.mode(result$probability) <- "double"
    colnames(result$probability) <- schema$class_levels
  }
  if (".pred_class" %in% names(x)) result$class <- .schema_decode_class(x$.pred_class, schema, "class")
  if (schema$encoded_outcome %in% names(x)) result$truth <- .schema_decode_class(x[[schema$encoded_outcome]], schema, "truth")
  if (length(identities)) {
    result$identity <- x[identities]
    attr(result$identity, "vennabers_schema") <- NULL
  }
  result
}
