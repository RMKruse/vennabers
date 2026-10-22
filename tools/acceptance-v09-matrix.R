# Local v0.9 tuning acceptance matrix against one installed artifact:
#   R_LIBS=<lib> Rscript tools/acceptance-v09-matrix.R <temporary-out-dir> [postprocessing|v08|all]
# <temporary-out-dir> receives logs and result tables; keep it outside .scratch.
# postprocessing: ten domain/method rows (as in examples/full-postprocessing.R)
#   x joint/two_stage x Grid/Bayes = 40 tuned compositions. Rows pair up
#   (binary, pairwise, shared three-class, shared two-class, regression); each
#   pair of 8 runs is an L8 orthogonal array: every row runs all four tuning
#   variants, the pair covers all eight fixed compositions, and search, strategy,
#   matched/full, Inductive/Cross, holdout/ensemble and fixed/tuned calibration
#   options are mutually balanced (no factor is tied to another).
# v08: the open v0.8 gate, 20 trainable paths (binary, shared OvO/OvR, pairwise
#   OvO, regression x Inductive/Cross x matched/full) x the same 4 variants = 80,
#   with calibration options tuned when Cross XOR two_stage, fixed otherwise.
# Every run: repeated outer resampling with exact (id, id2, .row, .config)
# coverage and saved extracts, B/S/A exclusion of every local search, eligible
# choices, last_fit with an A-target mutation, and a fresh-process RDS
# prediction under learning/search guards.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %in% 1:2)
out <- args[[1L]]; part <- if (length(args) == 2L) args[[2L]] else "all"
stopifnot(part %in% c("postprocessing", "v08", "all"))
dir.create(out, showWarnings = FALSE, recursive = TRUE)
library(vennabers)
checker <- new.env()
sys.source(system.file("examples", "check-encoded-evaluation.R", package = "vennabers"), checker)
source(system.file("examples", "assertions.R", package = "vennabers"))

# Nested joint candidates split B again (search resamples, VA and B/P splits),
# so pairwise and three-class paths need enough rows per class pair.
make_data <- function(k, regression = FALSE, n = if (k == 3L) 7200L else 2400L, sd = 3) withr::with_seed(123, {
  cl <- factor(rep(c("a", "b", "c")[seq_len(k)], length.out = n), levels = c("a", "b", "c")[seq_len(k)])
  x <- stats::rnorm(n, sd = sd) + c(-1, 1, -1)[cl]
  z <- stats::rnorm(n, sd = sd) + c(-1, -1, 1)[cl]
  data.frame(x = x, z = z, truth = if (regression) 3 + x - .3 * x^2 + z + stats::rnorm(n) else cl)
})
stratified <- function(d) rsample::vfold_cv(d, v = 2, strata = truth, pool = 0)
plain <- function(d) rsample::vfold_cv(d, v = 2)
degree <- dials::parameters(dials::new_quant_param(type = "integer", range = c(1L, 2L),
  inclusive = c(TRUE, TRUE), label = c(degree = "Degree")))
search <- function(kind, resamples, seed) {
  if (kind == "grid") return(list(method = "grid", grid = data.frame(degree = 1:2), resamples = resamples))
  list(method = "bayes", initial = 2L, iter = 1L, param_info = degree, resamples = resamples,
       control = tune::control_bayes(seed = seed, save_pred = TRUE, no_improve = 2L))
}
option_search <- function(kind, regression, resamples, seed) {
  values <- if (regression) data.frame(moderation = c(.1, .2)) else data.frame(va_loss = c("log", "brier"))
  if (kind == "grid") return(list(method = "grid", grid = values, resamples = resamples))
  info <- if (regression) dials::parameters(dials::new_quant_param(type = "double", range = c(.1, .2),
    inclusive = c(TRUE, TRUE), label = c(moderation = "Moderation"))) else
    dials::parameters(dials::new_qual_param(type = "character", values = c("log", "brier"), label = c(va_loss = "Loss")))
  list(method = "bayes", initial = 2L, iter = 1L, param_info = info, resamples = resamples,
       control = tune::control_bayes(seed = seed, save_pred = TRUE, no_improve = 2L))
}

# domain: binary, pairwise, ovo3, ovr3, ovo2, ovr2, regression.
build <- function(domain, post_method, strategy, va, mode, tuning_strategy, kind, options, seed) {
  regression <- domain == "regression"; pairwise <- domain == "pairwise"
  k <- if (pairwise || domain %in% c("ovo3", "ovr3")) 3L else 2L
  # Joint selection with tuned options and postprocessing nests five splits
  # (S, option resamples, VA, B/P, candidate search); give it three times the rows.
  deep <- !is.null(post_method) && tuning_strategy == "joint" && options == "tuned"
  # Tailor multinomial runs probably's nnet::multinom with at most 100
  # iterations and cannot be changed; weakly informative shared three-class
  # probabilities stop there unconverged (a correct error), so give them signal.
  informative <- !is.null(post_method) && domain %in% c("ovo3", "ovr3")
  d <- make_data(k, regression, n = (if (k == 3L) 7200L else 2400L) * (if (deep) 3L else 1L),
                 sd = if (informative) 2 else 3)
  engine <- if (regression) parsnip::linear_reg(engine = "lm") else if (pairwise || k == 2L)
    parsnip::logistic_reg(engine = "glm") else
    parsnip::multinom_reg(penalty = .1) |> parsnip::set_engine("nnet", trace = FALSE, maxit = 1000)
  base <- workflows::workflow() |> workflows::add_recipe(recipes::recipe(truth ~ x + z, d) |>
    recipes::step_poly(x, degree = tune::tune("degree"))) |> workflows::add_model(engine)
  resamples <- if (regression) plain else stratified
  tuning <- list(strategy = tuning_strategy, model = search(kind, resamples, seed))
  # Pairwise joint Grid without postprocessing is the Cartesian route (no local
  # model resamples); model-only pairwise joint tuning scores on joint_resamples.
  if (pairwise && tuning_strategy == "joint") {
    if (kind == "grid" && is.null(post_method)) tuning$model$resamples <- NULL
    if (options == "fixed") tuning$joint_resamples <- stratified
  }
  arguments <- list(base, "truth", method = va, prediction_model = mode, seed = seed, tuning = tuning)
  if (va == "cross") arguments$v <- 2L
  if (!regression && domain != "binary") arguments$classification <- if (pairwise) "ovo" else substr(domain, 1, 3)
  if (pairwise) arguments$model_training <- "pairwise"
  # Tuned calibration options are selected on a reserved S share.
  if (options == "tuned") {
    arguments$tuning$selection_prop <- .5
    arguments$tuning$calibration <- option_search(kind, regression, resamples, seed + 1L)
    if (regression) arguments$epsilon <- tune::tune("moderation") else arguments$loss <- tune::tune("va_loss")
  } else if (regression) arguments$m <- 1L
  if (!is.null(post_method)) {
    post <- list(method = post_method, strategy = strategy)
    if (post_method == "sigmoid") post$sigmoid_input <- "probability"
    if (strategy == "holdout") post$prop <- .3 else post$v <- 2L
    arguments$postprocessing <- post
  }
  list(data = d, spec = do.call(calibrated_workflow, arguments, quote = TRUE), regression = regression)
}

# Every local search record: its B positions (and P/C positions to exclude)
# inside the enclosing rows (the final rows, or a class pair's rows).
searches <- function(state) {
  parts <- if (is.null(state$pair_models)) list(state) else state$pair_models
  unlist(lapply(parts, function(part) {
    local <- if (is.null(part$pair_id)) state$tuning$models else state$tuning$models[[part$pair_id]]
    if (is.null(part$postprocessing)) return(lapply(names(local), function(id) {
      fold <- part$folds[[id]]
      list(pair = part$rows, search = local[[id]], B = if (is.null(fold)) NULL else fold$analysis,
           excluded = if (is.null(fold)) integer() else fold$assessment)
    }))
    unlist(lapply(names(part$postprocessing), function(path) {
      post <- part$postprocessing[[path]]
      inner <- if (is.null(post$inner_folds)) list(Holdout1 = post) else post$inner_folds
      lapply(names(inner), function(j) list(pair = part$rows, search = local[[path]][[j]],
        B = inner[[j]]$B, excluded = c(inner[[j]]$P, inner[[j]]$C)))
    }), recursive = FALSE)
  }), recursive = FALSE)
}
audit_state <- function(state, F_rows, A_rows) {
  final <- if (is.null(state$tuning$calibration)) F_rows else F_rows[state$tuning$calibration$final_rows]
  S_rows <- if (is.null(state$tuning$calibration)) integer() else F_rows[state$tuning$calibration$selection_rows]
  assert_conditions(!length(intersect(final, S_rows)), !any(c(final, S_rows) %in% A_rows))
  local <- Filter(function(x) !is.null(x$search$chosen), searches(state))
  for (x in local) {
    rows <- if (is.null(x$pair)) final else final[x$pair]
    s <- x$search
    # Cartesian pairwise joint Grid: local records name the chosen joint
    # candidate and score it on joint_resamples, not locally.
    if (is.null(s$candidates)) s$candidates <- state$tuning$joint$candidates
    B <- if (is.null(x$B)) rows else rows[x$B]
    searched <- if (is.null(s$native)) seq_along(B) else unique(tune::collect_predictions(s$native)$.row)
    assert_conditions(length(B) > 0L, !any(B %in% c(A_rows, S_rows, rows[x$excluded])),
      identical(sort(searched), seq_along(B)),
      s$chosen %in% s$candidates$id[s$candidates$status == "eligible"])
  }
  length(local) + !is.null(state$tuning$joint)
}

run_case <- function(case) {
  built <- build(case$domain, case$post, case$strategy, case$va, case$mode, case$tuning, case$search,
                 case$options, case$seed)
  d <- built$data; spec <- built$spec; regression <- built$regression
  metrics <- if (regression) yardstick::metric_set(yardstick::rmse) else yardstick::metric_set(yardstick::mn_log_loss)
  outer <- withr::with_seed(case$seed + 2L, rsample::vfold_cv(d, v = 2, repeats = 2))
  elapsed <- system.time(result <- tune::fit_resamples(spec, outer, metrics = metrics,
    control = tune::control_resamples(save_pred = TRUE, extract = workflows::extract_fit_engine, allow_par = FALSE)))[["elapsed"]]
  audited <- checker$check_outer_identities(result, outer, metrics = 1L)
  local <- vapply(seq_len(nrow(outer)), function(h) audit_state(audited$extracts[[h]],
    as.integer(outer$splits[[h]], "analysis"), as.integer(outer$splits[[h]], "assessment")), 1L)
  n <- nrow(d); A <- seq.int(.8 * n + 1, n)
  last <- tune::last_fit(spec, rsample::make_splits(list(analysis = seq_len(.8 * n), assessment = A), d), metrics = metrics)
  native <- tune::collect_predictions(last)
  fit <- tune::extract_workflow(last); new <- d[A, c("x", "z")]
  changed <- d
  changed$truth[A] <- if (regression) changed$truth[A] + 100 else rev(changed$truth[A])
  other <- tune::last_fit(spec, rsample::make_splits(list(analysis = seq_len(.8 * n), assessment = A), changed), metrics = metrics)
  assert_conditions(nrow(tune::collect_notes(last)) == 0L, identical(native$.row, A),
    identical(venn_abers_details(fit, new), venn_abers_details(tune::extract_workflow(other), new)),
    local > 0L)
  list(fit = fit, new = new, regression = regression,
       summary = data.frame(case[setdiff(names(case), "post")], post = if (is.null(case$post)) "none" else case$post,
         outer_resamples = nrow(outer), outer_rows = nrow(audited$predictions), local_searches = sum(local),
         final_observed_base_fits = venn_abers_tuning(fit)$cost$observed_base_fits, outer_seconds = elapsed,
         status = "passed"))
}

variants <- expand.grid(search = c("grid", "bayes"), tuning = c("joint", "two_stage"), stringsAsFactors = FALSE)
# L8 columns from bits a (row within its pair), b (search), c (strategy):
# mode = a xor b, VA = a xor c, holdout/ensemble = a xor b xor c, options = b xor c.
l8 <- function(a, b, c) list(mode = c("matched", "full")[bitwXor(a, b) + 1L],
  va = c("inductive", "cross")[bitwXor(a, c) + 1L],
  strategy = c("holdout", "ensemble")[bitwXor(bitwXor(a, b), c) + 1L],
  options = c("fixed", "tuned")[bitwXor(b, c) + 1L])
cases <- list()
if (part %in% c("postprocessing", "all")) {
  rows <- data.frame(domain = c("binary", "binary", "pairwise", "pairwise", "ovo3", "ovr3", "ovo2", "ovr2",
    "regression", "regression"), post = c("sigmoid", "tailor_logistic", "sigmoid", "tailor_logistic",
    "tailor_multinomial", "tailor_multinomial", "tailor_logistic", "tailor_logistic", "isotonic_numeric", "tailor_linear"))
  for (i in seq_len(nrow(rows))) for (v in seq_len(nrow(variants))) {
    design <- l8((i - 1L) %% 2L, (v - 1L) %% 2L, (v - 1L) %/% 2L)
    cases[[length(cases) + 1L]] <- c(list(part = "postprocessing", domain = rows$domain[i], post = rows$post[i]),
      design, as.list(variants[v, ]), seed = 100L + length(cases))
  }
}
if (part %in% c("v08", "all")) {
  for (domain in c("binary", "ovo3", "ovr3", "pairwise", "regression")) for (va in c("inductive", "cross"))
    for (mode in c("matched", "full")) for (v in seq_len(nrow(variants)))
      cases[[length(cases) + 1L]] <- c(list(part = "v08", domain = domain, post = NULL, strategy = "none",
        va = va, mode = mode, options = if (xor(va == "cross", variants$tuning[v] == "two_stage")) "tuned" else "fixed"),
        as.list(variants[v, ]), seed = 100L + length(cases))
}
# Optional MATRIX_ONLY regular expression restricts the run to matching labels.
only <- Sys.getenv("MATRIX_ONLY")
results <- list(); failures <- list()
for (case in cases) {
  label <- paste(case$part, case$domain, if (is.null(case$post)) "none" else case$post, case$strategy,
                 case$va, case$mode, case$tuning, case$search, paste0("options=", case$options))
  if (nzchar(only) && !grepl(only, label)) next
  r <- tryCatch(run_case(case), error = function(e) e)
  if (inherits(r, "error")) {
    failures[[label]] <- conditionMessage(r)
    cat("FAILED", label, ":", conditionMessage(r), "\n")
  } else {
    results[[label]] <- r
    cat("passed", label, "\n")
  }
}

# Fresh-process restoration of every passing final fit, with learning and
# search guards: predictions and details must be identical.
snapshot <- function(fit, new, regression) lapply(c(0L, 1L, 7L), function(n) {
  batch <- new[seq_len(n), , drop = FALSE]
  list(prediction = predict(fit, batch, type = if (regression) "numeric" else "prob"),
       details = venn_abers_details(fit, batch))
})
records <- lapply(results, function(r) list(fit = r$fit, new = r$new, regression = r$regression,
  expected = snapshot(r$fit, r$new, r$regression)))
saved <- file.path(out, paste0("fits-", part, ".rds")); script <- tempfile(fileext = ".R"); log <- file.path(out, paste0("fresh-", part, ".log"))
saveRDS(records, saved)
writeLines(c(
  paste0(".libPaths(", paste(deparse(.libPaths()), collapse = ""), ")"),
  "library(vennabers); loadNamespace('workflows')",
  "guard <- function(...) stop('Unexpected learning, planning or search')",
  "registerS3method('fit', 'workflow', guard, envir=asNamespace('generics'))",
  "registerS3method('fit', 'tailor', guard, envir=asNamespace('generics'))",
  "for (f in c('optim', 'glm.fit', 'isoreg')) trace(f, where=asNamespace('stats'), tracer=quote(guard()), print=FALSE)",
  "trace('prep.recipe', where=asNamespace('recipes'), tracer=quote(guard()), print=FALSE)",
  "for (f in c('initial_split', 'vfold_cv')) trace(f, where=asNamespace('rsample'), tracer=quote(guard()), print=FALSE)",
  "for (f in c('tune_grid', 'tune_bayes')) trace(f, where=asNamespace('tune'), tracer=quote(guard()), print=FALSE)",
  paste0("snapshot <- ", paste(deparse(snapshot), collapse = "\n")),
  paste0("records <- readRDS(", deparse(saved), ")"),
  "for (r in records) stopifnot(identical(r$expected, snapshot(r$fit, r$new, r$regression)))",
  "cat('fresh restoration identical for', length(records), 'fits\\n')"
), script)
status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), stdout = log, stderr = log)
unlink(saved)
summary <- do.call(rbind, lapply(results, `[[`, "summary"))
utils::write.csv(summary, file.path(out, paste0("matrix-", part, ".csv")), row.names = FALSE)
saveRDS(list(summary = summary, failures = failures, fresh_status = status,
             R = R.version.string, session = utils::sessionInfo(), package = as.character(utils::packageVersion("vennabers")),
             library = find.package("vennabers")), file.path(out, paste0("matrix-", part, ".rds")))
cat("cases", length(results) + length(failures), "passed", length(results), "failed", length(failures), "fresh status", status, "\n")
if (length(failures) || status != 0L) quit(status = 1L)
