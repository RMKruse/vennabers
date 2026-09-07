# Strict candidate failures with tune 2.1.0

Research date: 2026-09-07. Primary sources: tagged `tidymodels/tune` v2.1.0 source and current official documentation (currently identifying itself as 2.1.0). Runtime probes used tune 2.1.0, R at `/opt/homebrew/opt/r/bin/Rscript`, `R_LIBS_USER=/tmp/venn-tidymodels-lib`.

## Finding

**The accepted strict contract is not the default behavior of either native selection or continuous `tune_bayes()`.** Grid search can meet it with a small validation/filtering layer. Continuous native Bayes lacks a documented cross-resample candidate-validity callback; filtering only its final output is too late to exclude a partial candidate from the search trajectory.

### Native aggregation and selection

For ordinary unweighted resampling, `estimate_tune_results()` computes the mean with `na.rm=TRUE`, counts nonmissing estimates, and also drops resample entries that do not contain metric tibbles. It does not compare the observed fold identities to the planned ones. Weighted aggregation is not a general workaround: absent rows are still absent. Therefore a candidate with two successful folds out of three can have a finite, favorable mean. [Tagged aggregation implementation](https://github.com/tidymodels/tune/blob/v2.1.0/R/collect.R#L645-L759)

`show_best()` sorts the summarized metric, and `select_best()` delegates to it; neither applies an all-planned-resamples requirement. [Tagged selection implementation](https://github.com/tidymodels/tune/blob/v2.1.0/R/select_best.R#L80-L140)

The runnable probe [tuning-error-probe.R](tuning-error-probe.R) generated actual rpart tuning results and deliberately injected one missing main metric. Native selection chose the incomplete candidate (mean 0, n=2/3) over complete candidates (means 2 and 3). Filtering eligible parameter combinations through the public `filter_parameters()` changed the winner to the valid one. Output: the reproducible probe stdout. This is a synthetic result-corruption probe, not an assertion that rpart naturally produced those values.

### Minimal strict grid path

Run `tune_grid()` with saved predictions; validate unsummarized main metrics and prediction coverage against the immutable planned resamples; pass only eligible configurations to selection. Public collectors and `filter_parameters()` support this without private field edits. Keep original failure diagnostics separately. [Collectors](https://tune.tidymodels.org/reference/collect_predictions.html), [public filtering](https://tune.tidymodels.org/reference/filter_parameters.html)

Eligibility needs exact resample identity and expected assessment `.row` membership/multiplicity, valid required predictions, and one valid main metric per planned resample. Merely checking summary `n` is insufficient: it neither checks distinct resample identities nor guarantees complete predictions. Repeated CV/bootstrap require resample IDs alongside row IDs. This validation design is our inference from the public output structure; the probe's `n` filter only illustrates the simplest missing-fold failure.

### Auxiliary metrics must be isolated

Native metric calculation evaluates the supplied metric set inside a catch for the resample's metric computation. A throwing auxiliary metric can discard valid main results too. In the runtime probe, `metric_set(rmse, broken_aux)` produced no usable metric tibble for any fold, although saved predictions remained. [Tagged metric evaluation](https://github.com/tidymodels/tune/blob/v2.1.0/R/grid_performance.R#L64-L145), [tagged catch scope](https://github.com/tidymodels/tune/blob/v2.1.0/R/loop_over_all_stages.R#L460-L529)

Minimal reliable solution: calculate only the main metric during search; calculate each reporting metric independently afterward from saved predictions, catching and reporting each failure. Public `compute_metrics()` supports additional metrics without refitting when their prediction type was generated originally. Extra prediction types need explicit provision (or documented class derivation); saving probabilities does not magically save every prediction type. [Post-hoc metrics](https://tune.tidymodels.org/reference/compute_metrics.html)

### Why continuous native Bayes does not satisfy the strict contract

`tune_bayes_workflow()` uses the same internal aggregation to create GP training data, evaluate every new candidate, and update the incumbent before the next iteration. Consequently an incomplete candidate's finite mean can affect later proposals and stopping. The GP input check removes wholly missing means, not candidates missing some planned folds. [Tagged Bayes loop](https://github.com/tidymodels/tune/blob/v2.1.0/R/tune_bayes.R#L304-L597), [tagged GP input check](https://github.com/tidymodels/tune/blob/v2.1.0/R/checks.R#L624-L669)

Documented controls offer extraction, prediction saving, acquisition, budgets and parallelism, but no hook between all-fold evaluation and GP/incumbent update. Extraction sees a fitted workflow; a yardstick metric sees predictions for its current evaluation, not a barrier containing outcomes of every planned fold. Returning NA on one bad fold still allows other folds to be averaged. Returning a large penalty or infinity would change the agreed contract and can poison GP fitting. Custom acquisition acts after GP fitting and cannot undo contamination of its training data. [Bayes API](https://tune.tidymodels.org/reference/tune_bayes.html), [Bayes controls](https://tune.tidymodels.org/reference/control_bayes.html), [GP call site](https://github.com/tidymodels/tune/blob/v2.1.0/R/gp_helpers.R#L136-L222)

### Public alternatives, with exact limitations

1. **One-step continuation:** Start from validated grid results, call `tune_bayes(initial=eligible_results, iter=1)`, validate/filter its returned results before any next call, repeat. Public API supports results of prior Bayes runs as initialization. This can prevent invalid performance values reaching the *next* GP, without writing a GP/optimizer. However this is orchestration, not identical native continuous Bayes: each call reconstructs the score card with zero no-improvement/uncertainty counts; removing a latest candidate loses its iteration identity, and rejected points vanish from the set excluded from future proposals. Global budgets, seeds, rejected-candidate identity and stopping must be specified; failed-candidate penalties are not an acceptable shortcut. The runtime probe verified one resumed iteration and saved GP training data containing only eligible initial candidates. It also proved that different initial/continuation splits are accepted; the adapter must enforce immutable resample identity itself. Source `check_initial()` does not compare that identity. No dedicated public rejected-candidate exclusion option was found; an exclusion policy beyond previously retained results remains unproven. No complete adapter was implemented or verified here. [Resume API](https://tune.tidymodels.org/reference/tune_bayes.html#initial-values), [score-card reset](https://github.com/tidymodels/tune/blob/v2.1.0/R/tune_bayes.R#L715-L750), [candidate exclusion](https://github.com/tidymodels/tune/blob/v2.1.0/R/gp_helpers.R#L224-L286)
2. **Upstream validity callback / supported backend change:** Cleanest route to faithful continuous native Bayes semantics, but needs upstream work and compatibility tests; presently no documented callback identified.
3. **Fail the whole search on any invalid candidate:** Not established as implementable through a public whole-run interrupt hook, especially under parallel resampling. Do not recommend a warning trap as proven. It would also change the accepted continue-with-other-candidates behavior.
4. **Final-only strict filter:** Fine for grid; insufficient for the explicit Bayes optimization contract. Do not describe it as full enforcement.

## Submodel identity

Parsnip's `multi_predict()` can obtain predictions for several model configurations from one fitted object; tune extraction runs once per actual fit and intentionally recycles its fitted hyperparameter identity across submodel `.config`s. The extracted object is therefore not automatically the fitted calibrated procedure corresponding to every candidate. [Submodel semantics](https://parsnip.tidymodels.org/articles/Submodels.html), [extraction identity](https://tune.tidymodels.org/reference/control_bayes.html#hyperparameters-and-extracted-objects)

For a calibrated wrapper, reuse is correct only if each candidate's own calibration scores and assessment scores correspond to that candidate's base submodel, and its calibration/aggregation uses those same scores and options. Reusing a calibrator fitted to maximum-tree scores for a smaller-tree submodel would change the candidate procedure. This is an architectural inference, not an upstream guarantee. Minimal safe initial choice: do not advertise calibrated-wrapper submodel reuse until equivalence is tested; base engines may still use their own supported native reuse inside a properly separated uncalibrated stage.

## Verification scope

Source, native grid/auxiliary failure behavior, one filtered Bayes continuation, and lack of initial/continuation split-identity validation verified; no production files modified, no internal tune monkey patch, no custom optimizer, no complete Bayes continuation adapter implemented. Existing accepted candidate validity must remain intact when resolving this integration gap.

## Follow-up: real fit failure between public Bayes steps (verified)

[tuning-bayes-failure-probe.R](tuning-bayes-failure-probe.R) registers an isolated test engine using public parsnip extension functions. Initial parameter values 1, 2 and 3 succeed on all three planned folds. Every new parameter (4–8) deliberately fails only on the fold whose analysis data exclude one unique outcome observation. This tests actual fit failure, not injected result corruption.

One-step native Bayes proposed value 8: it returned a favorable mean RMSE around 5.30 from only two folds versus complete initial means around 6.25–6.28. The public collectors expose the missing fold and failure note. Filtering by a validity decision computed from unsummarized main metrics removed the failed candidate. Passing that filtered `iteration_results` object to a second one-step native Bayes call succeeded; saved GP training data contained exactly the three valid initial parameter values, with no failed candidate. The result class remained intact, and all planned fold IDs and analysis memberships remained present and unchanged through filtering and continuation. Output is in the reproducible probe stdout; script exits successfully with assertions.

This substantiates **a thin public continuation layer** as a feasible direction for the strict contract: validate every completed candidate before permitting the next Bayes call. It does not yet implement a controller. Global attempt IDs, budgets, stopping and seeds remain necessary wrapper responsibilities; filtered failures may be proposed again and can explicitly count against the global budget. Native `.iter` is not a reliable global attempt identity after filtering the latest iteration: initialization takes the maximum iteration present in summarized metrics, so the next call can reuse that number. Keep an external attempt identity/ledger for audit and global counting. Any native incumbent/log update on the failed last evaluation is discarded as authoritative selection state before continuation.

Prediction-row completeness and invalid-main-metric cases still need the same explicit validator as the grid route. This follow-up proves fit-failure exclusion before the next GP and preservation of the three vfold identities; it does not claim full validation coverage, identical behavior to uninterrupted native Bayes, or safe resumability under changed inputs.
