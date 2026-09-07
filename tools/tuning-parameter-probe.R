# Research probe: parameter transport + fold preprocessing, NOT VA calibration.
suppressPackageStartupMessages(library(parsnip))
suppressPackageStartupMessages(library(workflows))
set.seed(42)
dat <- data.frame(x=rnorm(60), z=rnorm(60), outcome=rnorm(60))
rec <- recipes::recipe(outcome ~ x + z, dat) |>
  recipes::step_normalize(recipes::all_predictors()) |>
  recipes::step_pca(recipes::all_predictors(), num_comp=tune::tune('pc'))
base <- workflow() |> add_recipe(rec) |>
  add_model(decision_tree(cost_complexity=tune::tune('cp'), mode='regression', engine='rpart'))
proxy_fit <- function(x, y, base_workflow, va_components, va_penalty, va_precision) {
  raw <- as.data.frame(x); raw$outcome <- y
  chosen <- tune::finalize_workflow(base_workflow, list(pc=va_components, cp=va_penalty))
  held <- split(seq_len(nrow(raw)), rep(1:2, length.out=nrow(raw)))
  models <- lapply(held, function(i) generics::fit(chosen, raw[-i,,drop=FALSE]))
  list(models=models, held=held, raw=raw, pc=va_components, cp=va_penalty,
       precision=if (va_precision=='none') NULL else as.integer(va_precision))
}
proxy_predict <- function(object,new_data) {
  Reduce('+', lapply(object$models, function(m) predict(m,new_data)$.pred))/length(object$models)
}
update.va_tuning_probe <- function(object, ..., fresh=FALSE) {
  replacements <- rlang::enquos(...)
  object$eng_args[names(replacements)] <- replacements
  object
}
set_new_model('va_tuning_probe')
set_model_mode('va_tuning_probe','regression')
set_model_engine('va_tuning_probe','regression','probe')
set_dependency('va_tuning_probe','probe','workflows',mode='regression')
set_fit('va_tuning_probe','regression','probe',list(interface='data.frame', protect=c('x','y'), func=c(fun='proxy_fit'), defaults=list()))
set_encoding('va_tuning_probe','regression','probe',list(predictor_indicators='none',compute_intercept=FALSE,remove_intercept=FALSE,allow_sparse_x=FALSE))
set_pred('va_tuning_probe','regression','probe','numeric',list(pre=NULL,post=NULL,func=c(fun='proxy_predict'),args=list(object=quote(object$fit),new_data=quote(new_data))))
spec <- new_model_spec('va_tuning_probe',args=list(),eng_args=NULL,mode='regression',method=NULL,engine='probe') |>
  set_engine('probe', base_workflow=base, va_components=tune::tune('pc'), va_penalty=tune::tune('cp'), va_precision=tune::tune('rounding'))
outer <- workflow() |> add_variables(outcomes=outcome,predictors=c(x,z)) |> add_model(spec)
args <- generics::tune_args(outer)
stopifnot(setequal(args$id,c('pc','cp','rounding')))
params <- dials::parameters(list(pc=dials::num_comp(c(1L,2L)), cp=dials::cost_complexity(c(-3,-1)),
  rounding=dials::new_qual_param(type='character',values=c('none','0','2'),label=c(rounding='Calibration rounding'))))
grid <- data.frame(pc=c(1L,2L,1L,2L),cp=c(.001,.001,.1,.1),rounding=c('none','0','2','none'))
folds <- rsample::vfold_cv(dat,v=3)
res <- tune::tune_grid(outer,resamples=folds,grid=grid,param_info=params,metrics=yardstick::metric_set(yardstick::rmse),
  control=tune::control_grid(save_pred=TRUE,allow_par=FALSE,extract=function(w) extract_fit_engine(w)))
print(tune::collect_notes(res))
stopifnot(nrow(tune::collect_notes(res))==0L)
stopifnot(nrow(tune::collect_predictions(res))==nrow(dat)*nrow(grid))
ex <- tune::collect_extracts(res)
stopifnot(nrow(ex)==nrow(grid)*nrow(folds))
for (i in seq_len(nrow(ex))) {
  obj <- ex$.extracts[[i]]
  stopifnot(obj$pc==ex$pc[i],obj$cp==ex$cp[i])
  expected <- if(ex$rounding[i]=='none') NULL else as.integer(ex$rounding[i])
  stopifnot(identical(obj$precision,expected))
  for(j in seq_along(obj$held)) {
    trained <- extract_recipe(obj$models[[j]])
    stopifnot(isTRUE(all.equal(trained$steps[[1]]$means,
      colMeans(obj$raw[-obj$held[[j]],c('x','z')]))))
    stopifnot(trained$steps[[2]]$num_comp==obj$pc)
  }
}
finalized <- tune::finalize_workflow(outer, grid[1,,drop=FALSE])
stopifnot(nrow(generics::tune_args(finalized))==0L)
fit <- generics::fit(finalized,dat)
stopifnot(extract_fit_engine(fit)$pc==1L,extract_fit_engine(fit)$cp==.001,
          identical(extract_fit_engine(fit)$precision,NULL))
print(tune::collect_metrics(res))
cat('PASS: proxy model/recipe/categorical parameters; native grid and finalize; per-fold preprocessing.\n')
set.seed(99)
bayes <- tune::tune_bayes(outer,resamples=folds,initial=res,iter=1,param_info=params,
  metrics=yardstick::metric_set(yardstick::rmse),
  control=tune::control_bayes(seed=99,allow_par=FALSE,save_pred=TRUE))
stopifnot(nrow(tune::collect_notes(bayes))==0L,
          nrow(tune::collect_metrics(bayes))==5L)
cat('PASS: one native Bayes iteration with numeric, integer and categorical proxies (no failure cases).\n')
print(sapply(c('tune','parsnip','workflows','dials','recipes','rsample','yardstick'),function(p) as.character(packageVersion(p))))
