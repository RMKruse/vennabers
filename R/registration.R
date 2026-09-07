.integration_versions <- c(parsnip = "1.6.0", workflows = "1.3.0", hardhat = "1.4.3",
                           rsample = "1.3.2", recipes = "1.4.0", rlang = "1.2.0",
                           tibble = "3.3.1", withr = "3.0.3", generics = "0.1.4",
                           tidyselect = "1.2.1")

.integration_packages <- function() {
  for (package in names(.integration_versions)) {
    version <- .integration_versions[[package]]
    if (!requireNamespace(package, quietly = TRUE) || utils::packageVersion(package) < version) {
      stop("calibrated_workflow() requires optional package ", sQuote(package),
           " >= ", version, "; install or update it explicitly.", call. = FALSE)
    }
  }
  invisible(NULL)
}

.registration <- new.env(parent = emptyenv())

.register_vennabers <- function() {
  if (utils::packageVersion("parsnip") < .integration_versions[["parsnip"]]) return(invisible(NULL))
  model <- "vennabers"
  if (model %in% parsnip::get_from_env("models")) {
    if (identical(.registration$fit, parsnip::get_fit(model))) return(invisible(NULL))
    stop("A foreign parsnip registration already owns model 'vennabers'; it will not be overwritten.", call. = FALSE)
  }
  parsnip::set_new_model(model)
  parsnip::set_model_mode(model, "classification")
  for (engine in c("inductive", "cross")) {
    parsnip::set_model_engine(model, "classification", engine)
    parsnip::set_dependency(model, engine, pkg = "vennabers", mode = "classification")
    parsnip::set_fit(model, "classification", engine,
                     list(interface = "data.frame", protect = c("x", "y"),
                          func = c(pkg = "vennabers", fun = "fit_vennabers"), defaults = list()))
    parsnip::set_encoding(model, "classification", engine,
                          list(predictor_indicators = "none", compute_intercept = FALSE,
                               remove_intercept = FALSE, allow_sparse_x = FALSE))
    for (type in c("prob", "class")) {
      parsnip::set_pred(model, "classification", engine, type,
                        list(pre = NULL, post = NULL,
                             func = c(pkg = "vennabers", fun = paste0("predict_vennabers_", type)),
                             args = list(object = quote(object$fit), new_data = quote(new_data))))
    }
  }
  .registration$fit <- parsnip::get_fit(model)
  invisible(NULL)
}

.onLoad <- function(libname, pkgname) {
  setHook(packageEvent("parsnip", "onLoad"), function(...) .register_vennabers())
  if ("parsnip" %in% loadedNamespaces()) .register_vennabers()
}
