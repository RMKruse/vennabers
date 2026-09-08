# Run against an installed package. This audit is for one fixed configuration.
check_encoded_evaluation <- function(result, outer, schema) {
  notes <- tune::collect_notes(result)
  native <- tune::collect_predictions(result, summarize = FALSE)
  metrics <- tune::collect_metrics(result, summarize = FALSE)
  decoded <- vennabers::venn_abers_decode(native, schema)
  stopifnot(nrow(notes) == 0L, !anyNA(decoded$truth), all(is.finite(metrics$.estimate)))
  ids <- setdiff(names(outer), "splits")
  expected <- do.call(rbind, lapply(seq_len(nrow(outer)), function(i) {
    split <- outer$splits[[i]]
    rows <- as.integer(split, data = "assessment")
    stopifnot(!length(intersect(rows, as.integer(split, data = "analysis"))))
    cbind(as.data.frame(outer[rep(i, length(rows)), ids, drop = FALSE]),
          .row = rows, .config = "pre0_mod0_post0")
  }))
  actual <- decoded$identity
  stopifnot(!anyNA(actual), !anyDuplicated(actual), nrow(actual) == nrow(expected),
            nrow(merge(actual, expected, by = names(expected))) == nrow(expected),
            !anyDuplicated(metrics[c(ids, ".config", ".metric")]), nrow(metrics) == 2L * nrow(outer),
            all(metrics$.estimator == "binary"), all(metrics$.config == "pre0_mod0_post0"))
  for (i in seq_len(nrow(outer))) {
    matches <- function(table) Reduce(`&`, lapply(ids, function(id) table[[id]] == outer[[id]][i]))
    rows <- matches(actual)
    truth <- decoded$truth[rows]
    encoded_truth <- outer$splits[[i]]$data[[schema$encoded_outcome]][actual$.row[rows]]
    stopifnot(identical(as.character(truth), schema$class_levels[match(as.character(encoded_truth), schema$classes)]))
    probability <- decoded$probability[rows, schema$event_class]
    reconstructed <- c(brier_class = yardstick::brier_class_vec(truth, probability, event_level = schema$event_level),
                       mn_log_loss = yardstick::mn_log_loss_vec(truth, probability, event_level = schema$event_level))
    m <- metrics[matches(metrics), ]
    stopifnot(setequal(m$.metric, names(reconstructed)),
              all(abs(m$.estimate - reconstructed[m$.metric]) <= 1e-10))
  }
  invisible(list(decoded = decoded, metrics = metrics, notes = notes))
}

if (all(vapply(c("vennabers", "workflows", "recipes", "rsample", "tune", "yardstick"),
               requireNamespace, logical(1), quietly = TRUE))) {
  development <- data.frame(x = sin(1:80), y = factor(rep(c("class", ".pred_yes", ".pred_yes", "class"), 20),
                                                    levels = c("class", ".pred_yes")))
  names(development) <- c("vaV0001", ".pred_class")
  schema <- vennabers::venn_abers_schema(development, outcome = ".pred_class", event_level = "second")
  encoded <- vennabers::venn_abers_encode(development, schema)
  # Build formulas/recipes explicitly in the encoded namespace.
  formula <- reformulate(setdiff(names(encoded), schema$encoded_outcome), schema$encoded_outcome)
  base <- workflows::workflow() |>
    workflows::add_recipe(recipes::recipe(formula, encoded) |>
                            recipes::step_normalize(recipes::all_numeric_predictors())) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  model <- vennabers::calibrated_workflow(base, schema$encoded_outcome, schema = schema, seed = 42)
  fitted <- generics::fit(model, encoded)
  new_data <- vennabers::venn_abers_encode(development[1:3, "vaV0001", drop = FALSE], schema)
  probability <- vennabers::venn_abers_decode(predict(fitted, new_data, type = "prob"), schema)$probability
  class <- vennabers::venn_abers_decode(predict(fitted, new_data, type = "class"), schema)$class
  details <- vennabers::venn_abers_decode(vennabers::venn_abers_details(fitted, new_data), schema)$details
  stopifnot(identical(colnames(probability), c("class", ".pred_yes")), length(class) == 3L)

  # Preserve prescribed memberships and repeat/fold IDs when rebuilding on encoded data.
  original_outer <- withr::with_seed(41, rsample::vfold_cv(development, v = 2, repeats = 2))
  outer <- rsample::manual_rset(lapply(original_outer$splits, function(s) {
    rsample::make_splits(list(analysis = as.integer(s, data = "analysis"),
                             assessment = as.integer(s, data = "assessment")), encoded)
  }), original_outer[c("id", "id2")])
  control <- tune::control_resamples(save_pred = TRUE, extract = workflows::extract_fit_engine,
    event_level = schema$event_level, parallel_over = "resamples", allow_par = FALSE, pkgs = c("vennabers", "stats"))
  evaluation <- withr::with_seed(43, tune::fit_resamples(model, outer,
    metrics = yardstick::metric_set(yardstick::brier_class, yardstick::mn_log_loss), control = control))
  checked <- check_encoded_evaluation(evaluation, outer, schema)
  # Truth and original outcome never overwrite .pred_class or the outer IDs.
  stopifnot(identical(checked$decoded$outcome, ".pred_class"), nrow(checked$decoded$identity) == 160L,
            all(vapply(tune::collect_extracts(evaluation)$.extracts, function(s) identical(s$schema, schema), logical(1))))
}
