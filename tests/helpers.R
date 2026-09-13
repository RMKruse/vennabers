register_reference_engine <- function(model, mode, fit, predict, type, engine = "reference", new_model = TRUE) {
  if (new_model) parsnip::set_new_model(model)
  parsnip::set_model_mode(model, mode)
  parsnip::set_model_engine(model, mode, engine)
  parsnip::set_fit(model, mode, engine,
    list(interface = "data.frame", protect = c("x", "y"), func = c(fun = fit), defaults = list()))
  parsnip::set_encoding(model, mode, engine,
    list(predictor_indicators = "none", compute_intercept = FALSE, remove_intercept = FALSE, allow_sparse_x = FALSE))
  parsnip::set_pred(model, mode, engine, type,
    list(pre = NULL, post = NULL, func = c(fun = predict),
      args = list(object = quote(object$fit), new_data = quote(new_data))))
}

pairwise_reference <- function() {
  audit <- new.env()
  audit$fits <- audit$predictions <- list()
  pair_fit <- function(x, y, fail_size = integer(), bad = FALSE) {
    audit$fits[[length(audit$fits) + 1L]] <- list(x = x, y = y)
    if (nrow(x) %in% fail_size) stop("planned pair failure")
    list(x = x, y = y, levels = levels(y), bad = bad, draw = runif(1))
  }
  pair_prob <- function(object, new_data) {
    stopifnot(nrow(new_data) > 0L)
    audit$predictions[[length(audit$predictions) + 1L]] <- new_data$row_id
    p <- vapply(seq_along(object$levels), function(i) {
      exp(sin(new_data$row_id / (i + 1)) + mean(object$x$x[object$y == object$levels[i]]))
    }, numeric(nrow(new_data)))
    p <- matrix(p, nrow(new_data), length(object$levels))
    p <- as.data.frame(p / rowSums(p))
    names(p) <- paste0(".pred_", object$levels)
    if (object$bad) p[[1L]] <- NA_real_
    p[rev(seq_along(p))]
  }
  register_reference_engine("va_pair_reference", "classification", "pair_fit", "pair_prob", "prob")
  spec <- parsnip::new_model_spec("va_pair_reference", args = list(), eng_args = NULL,
    mode = "classification", method = NULL, engine = "reference")
  make_base <- function(data) workflows::workflow() |> workflows::add_recipe(
    recipes::recipe(truth ~ ., data) |> recipes::step_impute_median(x) |> recipes::step_normalize(x)) |>
    workflows::add_model(spec)
  pair_data <- function(data) setNames(lapply(combn(levels(data$truth), 2, simplify = FALSE), function(pair) {
    local <- data[data$truth %in% pair, , drop = FALSE]
    local$truth <- factor(local$truth, levels = pair)
    local
  }), paste0("pair_", seq_len(choose(nlevels(data$truth), 2))))
  couple <- function(q, classes) {
    pairs <- combn(classes, 2, simplify = FALSE)
    p <- vapply(classes, function(cl) {
      relevant <- which(vapply(pairs, function(pair) cl %in% pair, logical(1)))
      odds <- lapply(relevant, function(j) {
        prob <- if (cl == pairs[[j]][2L]) q[, j] else 1 - q[, j]
        (1 - prob) / prob
      })
      1 / (1 + Reduce(`+`, odds))
    }, numeric(nrow(q)))
    p <- matrix(p, nrow(q), length(classes))
    p / rowSums(p)
  }
  list(audit = audit, pair_fit = pair_fit, pair_prob = pair_prob, spec = spec,
       make_base = make_base, pair_data = pair_data, couple = couple)
}
