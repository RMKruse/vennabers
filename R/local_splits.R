# Selected predictors, in carrier order, then outcome. Row names and container
# classes are deliberately absent; column types/attributes and row order remain.
.local_split_data <- function(data, columns) {
  if (!is.data.frame(data)) stop("Split data binding must be a data frame.", call. = FALSE)
  .integration_names(names(data), "split data column")
  if (!all(columns %in% names(data))) {
    stop("Split data binding is missing selected raw columns: ",
         paste(setdiff(columns, names(data)), collapse = ", "), ".", call. = FALSE)
  }
  lapply(stats::setNames(columns, columns), function(column) data[[column]])
}

.inductive_split <- function(split, data) {
  if (!inherits(split, "rsplit") ||
      !all(class(split) %in% c("rsplit", "initial_split", "mc_split"))) {
    stop("`splits` must supply an Inductive IID holdout from initial_split() or make_splits().", call. = FALSE)
  }
  if (!identical(.local_split_data(split$data, names(data)),
                 .local_split_data(data, names(data)))) {
    stop("Split data binding does not match the local selected raw data (values, types, levels or row order).", call. = FALSE)
  }
  positions <- list(analysis = as.integer(split, data = "analysis"),
                    assessment = as.integer(split, data = "assessment"))
  n <- nrow(data)
  valid <- function(x) is.numeric(x) && is.vector(x) && length(x) > 0L &&
    all(is.finite(x)) && all(x == floor(x)) && all(x >= 1 & x <= n) && !anyDuplicated(x)
  if (!all(vapply(positions, valid, logical(1))) ||
      length(intersect(positions$analysis, positions$assessment)) ||
      !identical(sort(as.integer(unlist(positions, use.names = FALSE))), seq_len(n))) {
    stop("Inductive1 must partition all rows into nonempty, disjoint training and calibration positions with unique valid indices.", call. = FALSE)
  }
  lapply(positions, as.integer)
}

# A prepared mapping is checked in full before a resolver can be used for fitting.
local_calibration_splits <- function(splits, columns) {
  .integration_packages()
  .integration_names(columns, "selected raw column")
  if (!is.list(splits) || inherits(splits, "rsplit") || !length(splits)) {
    stop("`splits` must be a nonempty list of prepared Inductive rsplit objects.", call. = FALSE)
  }
  snapshots <- plans <- vector("list", length(splits))
  for (i in seq_along(splits)) {
    tryCatch({
      snapshots[[i]] <- .local_split_data(splits[[i]]$data, columns)
      data <- splits[[i]]$data[columns]
      plans[[i]] <- list(method = "inductive", folds = list(Inductive1 = .inductive_split(splits[[i]], data)))
    }, error = function(e) stop("Prepared entry ", i, ": ", conditionMessage(e), call. = FALSE))
    # ponytail: quadratic setup in plan count; index snapshots if this becomes costly.
    for (j in seq_len(i - 1L)) {
      if (identical(snapshots[[i]], snapshots[[j]]) && !identical(plans[[i]], plans[[j]])) {
        stop("Conflicting prepared plans for identical local data in entries ", j, " and ", i, ".", call. = FALSE)
      }
    }
  }
  # Keep local snapshots/plans, without retaining the original split containers.
  rm(splits)
  force(columns)
  function(data) {
    if (!identical(names(data), columns)) {
      stop("Prepared plan columns must match all canonical selected raw columns, including outcome, in order.", call. = FALSE)
    }
    snapshot <- .local_split_data(data, columns)
    matches <- which(vapply(snapshots, identical, logical(1), y = snapshot))
    if (!length(matches)) stop("No prepared plan matches the local selected raw data.", call. = FALSE)
    # All matching plans were proven identical; unique() does not pick a first hit.
    plan <- unique(plans[matches])[[1L]]
    rsample::make_splits(plan$folds$Inductive1, data)
  }
}
