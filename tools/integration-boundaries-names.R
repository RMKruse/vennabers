# Research only: empirical class frequencies isolate names; no Venn-Abers model.
research_lib <- Sys.getenv('VENN_RESEARCH_LIB', '/tmp/venn-tidymodels-lib')
if (nzchar(research_lib)) .libPaths(c(research_lib, .libPaths()))
suppressPackageStartupMessages(library(parsnip))
suppressPackageStartupMessages(library(workflows))

name_fit <- function(x, y, schema=NULL) {
  if (!is.null(schema)) stopifnot(identical(levels(y), schema$code))
  structure(list(prob=as.numeric(table(y))/length(y), levels=levels(y), schema=schema), class='name_probe')
}
name_prob <- function(object, new_data) {
  out <- as.data.frame(matrix(rep(object$prob, each=nrow(new_data)), nrow=nrow(new_data), ncol=length(object$levels)))
  names(out) <- object$levels
  out
}
name_class <- function(object, new_data) factor(rep(object$levels[which.max(object$prob)], nrow(new_data)), levels=object$levels)
register_probe <- function() {
  parsnip::set_new_model('name_probe')
  parsnip::set_model_mode('name_probe','classification')
  parsnip::set_model_engine('name_probe','classification', eng='probe')
  parsnip::set_dependency('name_probe', eng='probe', pkg='workflows', mode='classification')
  parsnip::set_fit('name_probe','classification','probe', list(interface='data.frame', protect=c('x','y'), func=c(fun='name_fit'), defaults=list()))
  parsnip::set_encoding('name_probe','classification','probe', list(predictor_indicators='none', compute_intercept=FALSE, remove_intercept=FALSE, allow_sparse_x=FALSE))
  for (kind in c('prob','class')) parsnip::set_pred('name_probe','classification','probe',kind,list(pre=NULL,post=NULL,func=c(fun=if(kind=='prob') 'name_prob' else 'name_class'),args=list(object=quote(object$fit),new_data=quote(new_data))))
}
register_probe()
options(warn=1) # Print rsample pool=0 warnings beside the affected cases.
make_workflow <- function(outcome, predictors, schema=NULL) {
  spec <- parsnip::new_model_spec('name_probe', args=list(), eng_args=NULL, mode='classification', method=NULL, engine='probe')
  spec <- parsnip::set_engine(spec,'probe',schema=schema)
  workflows::workflow() |>
    workflows::add_variables(outcomes=tidyselect::all_of(outcome), predictors=tidyselect::all_of(predictors)) |>
    workflows::add_model(spec)
}
# Only values/names at the enclosing data boundary are encoded. No fitted object edit.
schema_for <- function(data, outcome) {
  stopifnot(is.data.frame(data), !anyDuplicated(names(data)), outcome %in% names(data), is.factor(data[[outcome]]), !anyNA(data[[outcome]]))
  list(original=levels(data[[outcome]]), code=sprintf('vaL%04d',seq_along(levels(data[[outcome]]))),
       columns=names(data), column_code=sprintf('vaV%04d',seq_along(data)), outcome=outcome,
       outcome_code=sprintf('vaV%04d', match(outcome,names(data))))
}
encode_data <- function(data, schema) {
  stopifnot(!anyDuplicated(names(data)), all(names(data) %in% schema$columns))
  if (schema$outcome %in% names(data)) {
    y <- data[[schema$outcome]]
    stopifnot(is.factor(y), identical(levels(y),schema$original), !anyNA(y))
    data[[schema$outcome]] <- factor(schema$code[match(as.character(y),schema$original)], levels=schema$code)
  }
  names(data) <- schema$column_code[match(names(data),schema$columns)]
  data
}
decode_class <- function(x, schema) {
  stopifnot(is.factor(x), identical(levels(x),schema$code), !anyNA(x))
  factor(schema$original[match(as.character(x),schema$code)],levels=schema$original)
}
decode_prob <- function(x, schema) {
  cols <- paste0('.pred_',schema$code)
  stopifnot(all(cols %in% names(x)), !anyDuplicated(names(x)))
  p <- as.matrix(x[,cols,drop=FALSE]); colnames(p) <- schema$original
  p
}
# Diagnostics keep truth, class and probability matrix in separate slots, so a
# raw outcome named '.pred_class' never overwrites a prediction column.
decode_predictions <- function(x, schema) {
  list(outcome=schema$outcome, truth=decode_class(x[[schema$outcome_code]],schema),
       class=decode_class(x$.pred_class,schema), probability=decode_prob(x,schema),
       occurrence=x[,intersect(c('id','id2','.row','.config'),names(x)),drop=FALSE], schema=schema)
}
run_outer <- function(wf,data,outcome) {
  set.seed(203)
  rs <- rsample::vfold_cv(data,v=3,repeats=2,strata=tidyselect::all_of(outcome),pool=0)
  suppressWarnings(tune::fit_resamples(wf,rs,metrics=yardstick::metric_set(yardstick::accuracy,yardstick::mn_log_loss,yardstick::brier_class),
    control=tune::control_resamples(save_pred=TRUE,extract=workflows::extract_fit_engine)))
}
brief <- function(x) if(inherits(x,'try-error')) paste('ERROR:',conditionMessage(attr(x,'condition'))) else 'OK'

if (identical(Sys.getenv('VENN_NAMES_CHILD'),'1')) {
  bundle <- readRDS(commandArgs(trailingOnly=TRUE)[1])
  stopifnot(identical(predict(bundle$fit,bundle$new,type='prob'),bundle$prob),
            identical(tune::collect_predictions(bundle$result,summarize=FALSE),bundle$pred),
            identical(decode_predictions(bundle$pred,bundle$schema),bundle$diagnostic))
  cat('PASS fresh-process RDS: native fit, resampling result, mapping and diagnostics\n')
  quit(status=0)
}

cat(R.version.string,'\n')
print(sapply(c('parsnip','workflows','hardhat','tune','yardstick','rsample','recipes','tibble','rlang'),function(p) as.character(packageVersion(p))))
raw_cases <- list(reserved=c('class','other'),prefix=c('.pred_yes','other'),spaces=c('a b','other'),nonsyntactic=c('1yes','other'),collision=c('a b','a-b','a.b'))
stopifnot(length(unique(make.names(raw_cases$collision)))==1L)
for (tag in names(raw_cases)) {
  lev <- raw_cases[[tag]]
  raw <- data.frame(x=seq_len(60),truth=factor(rep(lev,length.out=60),levels=lev))
  wf <- make_workflow('truth','x')
  fit <- generics::fit(wf,raw)
  p <- try(predict(fit,raw,type='prob'),silent=TRUE)
  r <- try(run_outer(wf,raw,'truth'),silent=TRUE)
  cat('\nRAW',tag,': predict',brief(p),'; outer',brief(r),'\n')
  if (!inherits(p,'try-error')) cat('columns:',paste(names(p),collapse=' | '),'\n')
  if (!inherits(r,'try-error')) {
    notes <- tune::collect_notes(r)
    cat('notes:',nrow(notes),'\n')
    if(nrow(notes)) cat(paste(unique(notes$note),collapse='\n'),'\n')
    cp <- try(tune::collect_predictions(r,summarize=FALSE),silent=TRUE)
    cm <- try(tune::collect_metrics(r,summarize=FALSE),silent=TRUE)
    cat('collect predictions:',brief(cp),'; metrics:',brief(cm),'\n')
    if (!inherits(cp,'try-error')) cat('collected:',paste(names(cp),collapse=' | '),'\n')
  }
  stopifnot(!inherits(r,'try-error'))
  if(tag=='reserved') stopifnot(inherits(p,'try-error'),nrow(notes)==6L,all(notes$type=='error'),
    all(grepl('level called',notes$note,fixed=TRUE)), !'.estimate' %in% names(cm), !'.pred_class' %in% names(cp))
  if(tag=='prefix') stopifnot(!inherits(p,'try-error'), !'.pred_.pred_yes' %in% names(p),
    nrow(notes)==6L,all(notes$type=='error'),all(grepl('.pred_.pred_yes',notes$note,fixed=TRUE)),
    inherits(cm,'try-error'),nrow(cp)==120L)
  if(tag %in% c('spaces','nonsyntactic','collision')) stopifnot(nrow(notes)==0L,nrow(cp)==120L,
    nrow(cm)==18L,all(is.finite(cm$.estimate)),identical(levels(cp$truth),lev),
    identical(names(p),paste0('.pred_',lev)))
}

# Native outcome collisions are independent of class spelling.
for (outcome in c('.pred_class','.pred_yes','.row','id','.config','a b')) {
  raw <- data.frame(x=seq_len(60), y=factor(rep(c('yes','no'),30),levels=c('yes','no')))
  names(raw)[2] <- outcome
  r <- try(run_outer(make_workflow(outcome,'x'),raw,outcome),silent=TRUE)
  cat('RAW OUTCOME',outcome,':',brief(r),'\n')
  if(!inherits(r,'try-error')) {
    notes <- tune::collect_notes(r)
    cp <- try(tune::collect_predictions(r,summarize=FALSE),silent=TRUE)
    cat('notes:',nrow(notes),'; collect:',brief(cp),'\n')
    if(nrow(notes)) cat(paste(unique(notes$note),collapse='\n'),'\n')
    if(!inherits(cp,'try-error')) cat('columns:',paste(names(cp),collapse=' | '),' rows:',nrow(cp),'\n')
  }
}

# The same coding contract covers every listed spelling at once and deliberately
# reverses lexical order to assert that the original factor order survives.
for (lev in list(c('class','.pred_yes'), c('a.b','class','.pred_yes','a b','1yes','a-b','ümlaut','vaL0001'))) {
for (outcome in c('truth','.pred_class','.pred_vaL0001','.row','id','.config','a b')) {
  counts <- seq(12,by=2,length.out=length(lev))
  raw <- data.frame(x=seq_len(sum(counts)),factor(rep(lev,times=counts),levels=lev),check.names=FALSE)
  names(raw) <- c('x',outcome)
  # Predictor collisions also vanish at the carrier boundary.
  raw[['vaV0001']] <- seq_len(nrow(raw))*2
  raw[['a-b']] <- rep(c(0,1),length.out=nrow(raw))
  schema <- schema_for(raw,outcome)
  coded <- encode_data(raw,schema)
  stopifnot(identical(decode_class(coded[[schema$outcome_code]],schema),raw[[outcome]]))
  wf <- make_workflow(schema$outcome_code,setdiff(schema$column_code,schema$outcome_code),schema)
  fit <- generics::fit(wf,coded)
  pred <- predict(fit,coded,type='prob')
  cls <- decode_class(predict(fit,coded,type='class')$.pred_class,schema)
  stopifnot(identical(colnames(decode_prob(pred,schema)),lev),identical(levels(cls),lev))
  state <- workflows::extract_fit_engine(fit)
  stopifnot(identical(state$schema,schema),isTRUE(all.equal(as.numeric(decode_prob(pred,schema)[1,]),counts/sum(counts))))
  result <- run_outer(wf,coded,schema$outcome_code)
  cp <- tune::collect_predictions(result,summarize=FALSE)
  cm <- tune::collect_metrics(result,summarize=FALSE)
  ex <- tune::collect_extracts(result)
  diagnostic <- decode_predictions(cp,schema)
  stopifnot(nrow(tune::collect_notes(result))==0L,nrow(cp)==2*nrow(raw),nrow(cm)==18L,all(is.finite(cm$.estimate)),nrow(ex)==6L,
            identical(as.character(diagnostic$truth),as.character(raw[[outcome]][cp$.row])),
            identical(levels(diagnostic$truth),lev),identical(colnames(diagnostic$probability),lev),
            all(vapply(ex$.extracts,function(x) identical(x$schema,schema),logical(1))))
  # Recompute each native metric after restoring original identities. This tests
  # semantics, rather than merely accepting a collector that returned something.
  for (id in unique(cp$id)) for (id2 in unique(cp$id2)) {
    use <- cp$id==id & cp$id2==id2
    truth <- diagnostic$truth[use]; estimate <- diagnostic$class[use]; prob <- diagnostic$probability[use,,drop=FALSE]
    stored <- ex$.extracts[[which(ex$id==id & ex$id2==id2)]]
    stopifnot(isTRUE(all.equal(as.numeric(prob[1,]),stored$prob)))
    metric_prob <- if(length(lev)==2L) prob[,1] else prob
    expected <- c(accuracy=yardstick::accuracy_vec(truth,estimate),mn_log_loss=yardstick::mn_log_loss_vec(truth,metric_prob),brier_class=yardstick::brier_class_vec(truth,metric_prob))
    if(length(lev)==2L) stopifnot(isTRUE(all.equal(yardstick::brier_class_vec(truth,prob[,1]),yardstick::brier_class_vec(truth,prob[,2],event_level='second'))))
    m <- cm[cm$id==id & cm$id2==id2,]
    stopifnot(isTRUE(all.equal(unname(expected[m$.metric]),m$.estimate)))
  }
  cat('PASS encoded native',length(lev),'-class boundary, original outcome =',outcome,':',nrow(cp),'predictions, 18 metrics, 6 states, exact decode\n')
}
}
# Fresh process rather than only an in-memory saveRDS/readRDS comparison.
bundle_file <- tempfile(fileext='.rds')
saveRDS(list(fit=fit,new=coded,prob=pred,result=result,pred=cp,schema=schema,diagnostic=diagnostic),bundle_file)
script <- sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)[1])
child <- system2(file.path(R.home('bin'),'Rscript'),c('--vanilla',shQuote(script),shQuote(bundle_file)),env=c('VENN_NAMES_CHILD=1',paste0('VENN_RESEARCH_LIB=',research_lib)),stdout=TRUE,stderr=TRUE)
cat(paste(child,collapse='\n'),'\n')
stopifnot(is.null(attr(child,'status')))
unlink(bundle_file)

# Frozen glm workflow: standard prob rejects class, but its documented raw path
# retains preprocessing and gives a checked, engine-specific probability vector.
frozen_raw <- data.frame(x=rep(seq(-2,2,length.out=20),3),truth=factor(rep(c('class','other','other','class','class','other'),10),levels=c('class','other')))
frozen_recipe <- recipes::recipe(truth ~ x, frozen_raw) |> recipes::step_normalize(recipes::all_numeric_predictors())
frozen <- workflows::workflow() |> workflows::add_recipe(frozen_recipe) |> workflows::add_model(parsnip::logistic_reg(engine='glm')) |> generics::fit(frozen_raw)
before <- serialize(frozen,NULL)
stopifnot(inherits(try(predict(frozen,frozen_raw,type='prob'),silent=TRUE),'try-error'))
praw <- predict(frozen,frozen_raw,type='raw',opts=list(type='response'))
stopifnot(length(praw)==nrow(frozen_raw),all(is.finite(praw)),all(praw>=0 & praw<=1),identical(before,serialize(frozen,NULL)))
# glm binomial response corresponds to second original factor level.
baked <- hardhat::forge(frozen_raw,workflows::extract_mold(frozen)$blueprint)$predictors
reference <- stats::predict(workflows::extract_fit_engine(frozen),newdata=baked,type='response')
stopifnot(isTRUE(all.equal(unname(praw),unname(reference))))
pmat <- cbind(1-praw,praw); colnames(pmat) <- levels(frozen_raw$truth)
cat('PASS frozen glm: native prob rejects class; workflow raw response + explicit original-level map succeeds without object mutation\n')
cat('ALL NAME-BOUNDARY ASSERTIONS PASSED\n')
