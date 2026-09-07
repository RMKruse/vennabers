# Research seam probe only: mean fold probabilities + artificial loss shift,
# deliberately NOT a Venn-Abers implementation.
research_lib <- Sys.getenv('VENN_RESEARCH_LIB')
if (nzchar(research_lib)) .libPaths(c(research_lib, .libPaths()))
suppressPackageStartupMessages(library(parsnip))
suppressPackageStartupMessages(library(workflows))

probe_fit <- function(x, y, base_workflow) {
  raw <- as.data.frame(x)
  raw$outcome <- y
  held <- split(seq_len(nrow(raw)), rep(1:3, length.out=nrow(raw)))
  fits <- lapply(held, function(i) generics::fit(base_workflow, data=raw[-i,,drop=FALSE]))
  calibration <- Map(function(f,i) predict(f, raw[i,,drop=FALSE], type='prob'), fits, held)
  structure(list(fits=fits, held=held, calibration=calibration, raw=raw, loss='log'), class='va_seam_probe')
}
probe_prob <- function(object, new_data) {
  if (nrow(new_data)==0L) return(data.frame(no=numeric(),yes=numeric()))
  p <- Reduce('+', lapply(object$fits, function(f) predict(f, new_data, type='prob')$.pred_yes))/length(object$fits)
  if (object$loss == 'brier') p <- pmin(.99, p + .1)
  data.frame(no=1-p, yes=p)
}
probe_class <- function(object, new_data) {
  p <- probe_prob(object, new_data)
  factor(ifelse(p$yes > p$no, 'yes', 'no'), levels=c('no','yes'))
}
`predict._va_seam_probe` <- function(object, new_data, type=NULL, opts=list(), ..., loss=NULL) {
  if (!is.null(loss)) object$fit$loss <- match.arg(loss, c('log','brier'))
  parsnip::predict.model_fit(object, new_data, type=type, opts=opts, ...)
}
parsnip::set_new_model('va_seam_probe')
parsnip::set_model_mode('va_seam_probe','classification')
parsnip::set_model_engine('va_seam_probe','classification', eng='probe')
parsnip::set_dependency('va_seam_probe', eng='probe', pkg='workflows', mode='classification')
parsnip::set_fit('va_seam_probe','classification','probe', list(interface='data.frame', protect=c('x','y'), func=c(fun='probe_fit'), defaults=list()))
parsnip::set_encoding('va_seam_probe','classification','probe', list(predictor_indicators='none', compute_intercept=FALSE, remove_intercept=FALSE, allow_sparse_x=FALSE))
for (kind in c('prob','class')) {
  parsnip::set_pred('va_seam_probe','classification','probe', kind, list(pre=NULL, post=NULL, func=c(fun=if (kind=='prob') 'probe_prob' else 'probe_class'), args=list(object=quote(object$fit), new_data=quote(new_data))))
}
spec <- parsnip::new_model_spec('va_seam_probe', args=list(), eng_args=NULL, mode='classification', method=NULL, engine='probe')
dat <- data.frame(x=c(NA,seq_len(29)), z=factor(rep(c('a','b'),15)), outcome=factor(rep(c('no','yes','yes','no','no','yes'),5),levels=c('no','yes')))
rec <- recipes::recipe(outcome ~ x + z, data=dat)
rec <- recipes::step_impute_median(rec, recipes::all_numeric_predictors())
rec <- recipes::step_normalize(rec, recipes::all_numeric_predictors())
base <- workflows::workflow() |> workflows::add_recipe(rec) |> workflows::add_model(parsnip::logistic_reg(engine='glm'))
spec <- parsnip::set_engine(spec,'probe',base_workflow=base)
outer <- workflows::workflow() |> workflows::add_variables(outcomes=outcome,predictors=c(x,z),blueprint=hardhat::default_xy_blueprint(allow_novel_levels=TRUE)) |> workflows::add_model(spec)
fitted <- generics::fit(outer,data=dat)
engine <- workflows::extract_fit_engine(fitted)
stopifnot(identical(engine$raw, dat), length(engine$fits)==3)
for (j in seq_along(engine$held)) {
  raw_x <- dat$x[-engine$held[[j]]]
  raw_x[is.na(raw_x)] <- median(raw_x,na.rm=TRUE)
  trained <- workflows::extract_recipe(engine$fits[[j]])
  stopifnot(isTRUE(all.equal(unname(trained$steps[[2]]$means),mean(raw_x))))
}
new <- dat[2:4,c('x','z')]
p <- predict(fitted,new,type='prob')
shifted <- predict(fitted,new,type='prob',loss='brier')
stopifnot(all(shifted$.pred_yes > p$.pred_yes), identical(p,predict(fitted,new,type='prob')), identical(engine$loss,'log'))
stopifnot(identical(names(predict(fitted,new,type='class',loss='brier')),'.pred_class'))
stopifnot(nrow(predict(fitted,new[FALSE,],type='prob'))==0)
f <- tempfile(fileext='.rds'); saveRDS(fitted,f); stopifnot(identical(p,predict(readRDS(f),new,type='prob')))
set.seed(123)
rs <- rsample::vfold_cv(dat,v=3,strata=outcome)
res <- tune::fit_resamples(outer,rs,metrics=yardstick::metric_set(yardstick::accuracy,yardstick::brier_class),control=tune::control_resamples(save_pred=TRUE,extract=function(x) workflows::extract_fit_engine(x)))
stopifnot(nrow(tune::collect_predictions(res))==nrow(dat), nrow(tune::collect_notes(res))==0)
ex <- tune::collect_extracts(res)
stopifnot(nrow(ex)==3)
for(i in seq_len(nrow(ex))) {
  got <- ex$.extracts[[i]]
  stopifnot(length(got$fits)==3, identical(got$raw, as.data.frame(rsample::analysis(rs$splits[[i]]))))
}
print(tune::collect_metrics(res))
cat('PASS: raw XY, fold preprocessing, fit/predict, native loss dispatch, zero rows, RDS, outer resampling + extraction\n')
print(sapply(c('parsnip','workflows','hardhat','recipes','rsample','tune','yardstick','rlang','tibble','withr'),function(p) as.character(packageVersion(p))))

# Independent rsample and metric conventions.
library(rsample)
library(yardstick)
cat(R.version.string, '\n')
for (p in c('rsample', 'yardstick', 'tune')) cat(p, as.character(packageVersion(p)), '\n')
d <- data.frame(x=seq_len(60), y=factor(rep(c('event','other','third'), 20)))
set.seed(42)
r <- vfold_cv(d, v=5, strata=y, pool=0)
a <- lapply(r$splits, as.integer, data='analysis')
b <- lapply(r$splits, as.integer, data='assessment')
stopifnot(identical(sort(unlist(b, use.names=FALSE)), seq_len(nrow(d))))
for (i in seq_along(a)) stopifnot(setequal(a[[i]], setdiff(seq_len(nrow(d)), b[[i]])))
set.seed(42)
r2 <- vfold_cv(d, v=5, strata=y, pool=0)
stopifnot(identical(r, r2))
rr <- vfold_cv(d, v=5, repeats=2, strata=y, pool=0)
stopifnot(anyDuplicated(unlist(lapply(rr$splits, as.integer, data='assessment'))) > 0L)
# A supported explicit partition must be checked beyond manual_rset's constructor.
bad <- manual_rset(list(make_splits(list(analysis=1:30, assessment=30:60), d)), 'overlap')
stopifnot(length(intersect(as.integer(bad$splits[[1]], 'analysis'), as.integer(bad$splits[[1]], 'assessment'))) == 1L)
truth <- factor(c('a','b','c'), levels=c('a','b','c'))
p <- rbind(c(.6,.3,.1),c(.2,.7,.1),c(.2,.2,.6))
colnames(p) <- levels(truth)
y <- diag(3)
core <- mean(rowSums((y-p)^2))
stopifnot(isTRUE(all.equal(2*brier_class_vec(truth,p),core)))
yb <- factor(c('event','other'),levels=c('event','other'))
stopifnot(identical(brier_class_vec(yb,c(.8,.3)),brier_class_vec(yb,c(.2,.7),event_level='second')) ||
          isTRUE(all.equal(brier_class_vec(yb,c(.8,.3)),brier_class_vec(yb,c(.2,.7),event_level='second'))))
extreme <- mn_log_loss_vec(yb,c(0,1))
stopifnot(is.finite(extreme), isTRUE(all.equal(extreme,-log(.Machine$double.eps))))
cat('PASS: partition/complements; fixed-seed repeat; repeated/overlapping plans distinguishable; Brier factor two; event mapping; finite extreme log loss =', extreme, '\n')

# Expected incompatibility, not a passing product capability.
original_probe_fit <- probe_fit
probe_fit <- function(x,y,base_workflow) original_probe_fit(x, factor(ifelse(as.character(y)=='class','no',as.character(y)),levels=c('no','yes')),base_workflow)
`predict._va_seam_probe` <- function(object,new_data,type=NULL,opts=list(),...,loss=NULL) {
  if (!is.null(loss)) object$fit$loss <- loss
  p <- probe_prob(object$fit,new_data)
  if (is.null(type) || type=='class') return(tibble::tibble(.pred_class=factor(ifelse(p$yes>p$no,'yes','class'),levels=c('class','yes'))))
  stopifnot(type=='prob')
  tibble::tibble(.pred_class=p$no,.pred_yes=p$yes)
}
bad <- dat
bad$outcome <- factor(ifelse(as.character(bad$outcome)=='no','class','yes'),levels=c('class','yes'))
bad_fit <- generics::fit(outer,bad)
stopifnot(identical(names(predict(bad_fit,new,type='prob')),c('.pred_class','.pred_yes')))
set.seed(10)
bad_rs <- rsample::vfold_cv(bad,v=3,strata=outcome)
result <- try(tune::fit_resamples(outer,bad_rs,metrics=yardstick::metric_set(yardstick::accuracy,yardstick::brier_class), control=tune::control_resamples(save_pred=TRUE)),silent=TRUE)
stopifnot(!inherits(result,'try-error'))
notes <- tune::collect_notes(result)
stopifnot(nrow(notes)==3L, all(notes$type=='error'), all(grepl('level called', notes$note, fixed=TRUE)))
stopifnot(inherits(try(tune::collect_metrics(result), silent=TRUE), 'try-error'))
cat('PASS: standalone class-labelled predictions succeed; all three native outer predictions reject reserved class level.\n')
