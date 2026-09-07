# Each process uses the installed package; startup files cannot mask load order.
package_library <- dirname(find.package("vennabers"))
run_process <- function(code, libraries = .libPaths()) {
  script <- tempfile(fileext = ".R")
  output <- tempfile(fileext = ".log")
  on.exit(unlink(c(script, output)), add = TRUE)
  prefix <- c(paste0(".libPaths(", paste(deparse(libraries), collapse = ""), ")"),
              paste0("package_library <- ", deparse(package_library)))
  writeLines(c(prefix, code), script)
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), stdout = output, stderr = output)
  if (status != 0L) stop(paste(readLines(output), collapse = "\n"))
}
run_process(c(
  'stopifnot(!"parsnip" %in% loadedNamespaces())',
  'loadNamespace("vennabers", lib.loc = package_library)',
  'stopifnot(!"parsnip" %in% loadedNamespaces())',
  'stopifnot(nrow(predict(vennabers::venn_abers(c(FALSE, TRUE), c(.1, .9)), .5)) == 1L)',
  'stopifnot(!"parsnip" %in% loadedNamespaces())'
), libraries = .Library)

if (all(vapply(c("parsnip", "workflows", "rsample", "recipes", "rlang", "tibble", "withr", "generics", "tidyselect"),
               requireNamespace, logical(1), quietly = TRUE))) {
  construction <- c(
    'data <- data.frame(x = sin(1:80), truth = factor(rep(c("yes", "no", "no", "yes"), 20)))',
    'base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |> workflows::add_model(parsnip::logistic_reg(engine = "glm"))',
    'model <- vennabers::calibrated_workflow(base, "truth", seed = 42)',
    'second <- vennabers::calibrated_workflow(base, "truth", seed = 42)',
    'stopifnot(nrow(parsnip::get_fit("vennabers")) == 1L)',
    'fit <- generics::fit(model, data)',
    'stopifnot(identical(predict(fit, data, type = "prob"), vennabers::venn_abers_details(fit, data)$prediction))'
  )
  for (order in list(c('loadNamespace("vennabers")', 'loadNamespace("parsnip")'),
                    c('loadNamespace("parsnip")', 'loadNamespace("vennabers")'))) {
    run_process(c(order, construction, 'stopifnot(!"package:vennabers" %in% search(), !"package:parsnip" %in% search())'))
  }
  payload <- tempfile(fileext = ".rds")
  run_process(c(construction, paste0('saveRDS(list(fit = fit, data = data, prob = predict(fit, data, type = "prob"), details = vennabers::venn_abers_details(fit, data, loss = "brier")), ', deparse(payload), ')')))
  run_process(c('loadNamespace("vennabers")', 'loadNamespace("workflows")', paste0('saved <- readRDS(', deparse(payload), ')'),
                'stopifnot(identical(saved$prob, predict(saved$fit, saved$data, type = "prob")), identical(saved$details, vennabers::venn_abers_details(saved$fit, saved$data, loss = "brier")))'))
  unlink(payload)
  run_process(c(
    'loadNamespace("parsnip")',
    'parsnip::set_new_model("vennabers")',
    'before <- parsnip::get_fit("vennabers")',
    'error <- tryCatch(loadNamespace("vennabers"), error = identity)',
    'stopifnot(inherits(error, "error"), grepl("foreign", conditionMessage(error)), identical(before, parsnip::get_fit("vennabers")))'
  ))
}
