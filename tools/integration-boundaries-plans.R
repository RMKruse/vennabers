# Research only: models and calibration-source predictions, no Venn-Abers math.
research_lib <- Sys.getenv("VENN_RESEARCH_LIB")
if (nzchar(research_lib)) .libPaths(c(research_lib, .libPaths()))
suppressPackageStartupMessages(library(parsnip))
suppressPackageStartupMessages(library(workflows))

plan_fit <- function(x, y, context) {
  raw <- as.data.frame(x)
  raw$truth <- y
  if (!identical(raw, context$data)) stop("Plan does not match local data")
  n <- nrow(raw)
  held <- context$held
  stopifnot(identical(sort(unlist(held, use.names = FALSE)), seq_len(n)),
            !anyDuplicated(names(held)), all(lengths(held) > 0L))
  base <- workflows::workflow() |>
    workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  fits <- lapply(held, function(i) generics::fit(base, raw[-i, , drop = FALSE]))
  calibration <- Map(function(f, i) predict(f, raw[i, , drop = FALSE], type = "prob"),
                     fits, held)
  structure(list(context = context, fits = fits, calibration = calibration),
            class = "boundary_plan_probe")
}

plan_prob <- function(object, new_data) {
  p <- Reduce(`+`, lapply(object$fits, function(f)
    predict(f, new_data, type = "prob")$.pred_yes)) / length(object$fits)
  data.frame(no = 1 - p, yes = p)
}

plan_class <- function(object, new_data) {
  factor(ifelse(plan_prob(object, new_data)$yes >= .5, "yes", "no"),
         levels = c("no", "yes"))
}

register_plan_probe <- function() {
  parsnip::set_new_model("boundary_plan_probe")
  parsnip::set_model_mode("boundary_plan_probe", "classification")
  parsnip::set_model_engine("boundary_plan_probe", "classification", eng = "probe")
  parsnip::set_dependency("boundary_plan_probe", eng = "probe", pkg = "workflows",
                          mode = "classification")
  parsnip::set_fit("boundary_plan_probe", "classification", "probe",
    list(interface = "data.frame", protect = c("x", "y"),
         func = c(fun = "plan_fit"), defaults = list()))
  parsnip::set_encoding("boundary_plan_probe", "classification", "probe",
    list(predictor_indicators = "none", compute_intercept = FALSE,
         remove_intercept = FALSE, allow_sparse_x = FALSE))
  for (kind in c("prob", "class")) {
    parsnip::set_pred("boundary_plan_probe", "classification", "probe", kind,
      list(pre = NULL, post = NULL,
           func = c(fun = if (kind == "prob") "plan_prob" else "plan_class"),
           args = list(object = quote(object$fit), new_data = quote(new_data))))
  }
}

run_occurrence <- function(job) {
  spec <- parsnip::new_model_spec("boundary_plan_probe", args = list(), eng_args = NULL,
    mode = "classification", method = NULL, engine = "probe") |>
    parsnip::set_engine("probe", context = job$context)
  outer <- workflows::workflow() |>
    workflows::add_variables(outcomes = truth, predictors = x) |>
    workflows::add_model(spec)
  set.seed(job$context$seed)
  result <- tune::fit_resamples(outer, job$resample,
    metrics = yardstick::metric_set(yardstick::accuracy, yardstick::brier_class),
    control = tune::control_resamples(save_pred = TRUE, allow_par = FALSE,
                                     extract = workflows::extract_fit_engine))
  stopifnot(nrow(tune::collect_notes(result)) == 0L)
  list(id = job$context$id, predictions = tune::collect_predictions(result),
       metrics = tune::collect_metrics(result),
       state = tune::collect_extracts(result)$.extracts[[1]])
}

plan_probe <- function() {
  register_plan_probe()
  set.seed(1602)
  dat <- data.frame(x = rnorm(96), truth = factor(rep(c("no", "yes"), 48)))
  split <- rsample::make_splits(list(analysis = 1:72, assessment = 73:96), dat)
  local <- as.data.frame(rsample::analysis(split))
  plan_a <- split(seq_len(72), rep(1:3, each = 24))
  plan_b <- split(seq_len(72), rep(1:3, length.out = 72))
  jobs <- Map(function(id, held, seed) {
    list(context = list(id = id, seed = seed, data = local, held = held),
         resample = rsample::manual_rset(list(split), id))
  }, c("Repeat-A", "Repeat-B"), list(plan_a, plan_b), c(1603L, 1604L))
  names(jobs) <- c("Repeat-A", "Repeat-B")
  stopifnot(identical(jobs[[1]]$context$data, jobs[[2]]$context$data),
            !identical(jobs[[1]]$context$held, jobs[[2]]$context$held))
  first <- lapply(jobs, run_occurrence)
  reversed <- lapply(rev(jobs), run_occurrence)
  saved <- tempfile(fileext = ".rds")
  saveRDS(jobs, saved)
  roundtrip <- lapply(readRDS(saved), run_occurrence)
  # Fresh PSOCK workers: explicit job values, no selection counters or shared state.
  workers <- parallel::makePSOCKcluster(2, rscript = file.path(R.home("bin"), "Rscript"))
  on.exit(parallel::stopCluster(workers), add = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  parallel::clusterCall(workers, function(path) {
    source(path, local = .GlobalEnv)
    register_plan_probe()
    TRUE
  }, script)
  concurrent <- parallel::parLapply(workers, rev(jobs), run_occurrence)
  for (id in names(jobs)) {
    for (other in list(reversed, roundtrip, concurrent)) {
      stopifnot(identical(first[[id]]$predictions, other[[id]]$predictions),
                identical(first[[id]]$metrics, other[[id]]$metrics),
                identical(first[[id]]$state$context, other[[id]]$state$context))
    }
    got <- first[[id]]
    stopifnot(all(got$predictions$id == id), nrow(got$predictions) == 24L,
              identical(got$state$context$held, jobs[[id]]$context$held))
    for (k in seq_along(got$state$fits)) {
      engine <- workflows::extract_fit_engine(got$state$fits[[k]])
      held <- got$state$context$held[[k]]
      stopifnot(identical(unname(engine$model$x), local$x[-held]),
                identical(got$state$calibration[[k]],
                  predict(got$state$fits[[k]], local[held, , drop = FALSE], type = "prob")))
    }
  }
  stopifnot(!isTRUE(all.equal(first[[1]]$predictions$.pred_yes,
                              first[[2]]$predictions$.pred_yes)))
  bad <- jobs[[1]]$context
  bad$data$x[1] <- bad$data$x[1] + 1
  error <- tryCatch(plan_fit(local["x"], local$truth, bad), error = conditionMessage)
  stopifnot(identical(error, "Plan does not match local data"))
  saveRDS(first, saved)
  restored <- readRDS(saved)
  for (id in names(jobs)) stopifnot(identical(
    plan_prob(first[[id]]$state, dat[73:96, , drop = FALSE]),
    plan_prob(restored[[id]]$state, dat[73:96, , drop = FALSE])))
  cat("PASS: identical local data, distinct preassigned plans; native per-occurrence resampling\n")
  cat("PASS: repeated, reversed, RDS job replay, two fresh PSOCK workers; predictions/metrics/context identical\n")
  cat("PASS: exact inner training rows and held predictions; outer 24 rows excluded; mismatched plan rejected\n")
  cat("PASS: saved prediction path; distinct plans produce distinct predictions\n")
  cat("LIMIT: explicit external orchestration, not one native multi-occurrence fit_resamples call; no VA math\n")
  cat(R.version.string, "\n")
  print(sapply(c("parsnip", "workflows", "hardhat", "rsample", "tune", "yardstick"),
               function(p) as.character(packageVersion(p))))
}

if (sys.nframe() == 0L) plan_probe()
