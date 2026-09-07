# Installed example: optional integration; failures propagate when available.
packages <- c("parsnip", "workflows", "recipes", "rsample", "hardhat", "generics",
              "rlang", "tibble", "tidyselect", "withr")
if (all(vapply(packages, requireNamespace, logical(1), quietly = TRUE))) local({
  library(vennabers)
  # Development data are available for training and calibration. Assessment
  # observations below are untouched by either learning step or parameter choice.
  set.seed(12)
  data <- data.frame(x = stats::rnorm(250))
  data$truth <- factor(ifelse(stats::runif(250) < stats::plogis(data$x), "yes", "no"),
                       levels = c("yes", "no"))
  development <- data[1:200, ]
  assessment <- data[201:250, ]
  recipe <- recipes::recipe(truth ~ x, development) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
  base <- workflows::workflow() |>
    workflows::add_recipe(recipe) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  calibrated <- calibrated_workflow(base, outcome = "truth", seed = 42)
  fitted <- generics::fit(calibrated, development)
  probability <- predict(fitted, assessment, type = "prob")
  class <- predict(fitted, assessment, type = "class")
  details <- venn_abers_details(fitted, assessment)
  state <- workflows::extract_fit_engine(fitted)
  stopifnot(identical(probability, details$prediction), nrow(class) == 50L,
            length(state$models) == 1L, state$event_class == "yes",
            state$folds$Inductive1$training_size + state$folds$Inductive1$calibration_size == 200L)
  # Prediction-time loss changes neither the fitted model nor its stored default.
  brier <- predict(fitted, assessment, type = "prob", loss = "brier")
  stopifnot(identical(brier, venn_abers_details(fitted, assessment, loss = "brier")$prediction),
            workflows::extract_fit_engine(fitted)$loss == "log")
  print(head(probability))
  print(head(details$details))
  print(brier_score(assessment$truth == "yes", probability$.pred_yes))
  # Local recipe statistics are inspectable through the full stored workflow.
  print(workflows::extract_recipe(state$models$Inductive1))
  # This split cannot undo earlier tuning or transformations that used calibration
  # or assessment observations. IID data and a model fixed independently of its
  # calibration observations remain assumptions; VA bounds are not confidence
  # intervals and calibration need not improve scores on a particular test set.
})
