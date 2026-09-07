# Pure post-fit log/Brier selection: bounded exception

Research date: 2026-09-07. This note evaluates feasibility, not release scope. Binary/multiclass loss support and common precision/loss are the user's planned contracts; the referenced v0.2 baseline implements only log aggregation.

## Primary-source facts

The VA paper constructs IVAP endpoint pairs from a proper training set and separate calibration set. Its Section 4 gives two deterministic ways to turn the same pairs into point probabilities: log minimax uses geometric means of upper endpoints and complements of lower endpoints; Brier minimax averages a quadratic expression in those endpoints. For one fold these also yield the corresponding IVAP rules. Neither formula needs a new base-model fit. [VA paper, Sections 2–4](https://arxiv.org/html/1511.00213#S4)

The formal calibration statement concerns a selector from binary IVAP endpoint pairs under iid assumptions. The paper distinguishes this from point predictions, which lose the perfect-calibration guarantee, and describes CVAP's benefit as empirical. It does not establish validity for the planned multiclass coupling or for validation-selected point rules. [VA paper, abstract, Proposition 1 and conclusion](https://arxiv.org/html/1511.00213#S2)

Using data to choose a winner and then reporting that winner's score on the same data can cause optimistic assessment. Separate test data or an outer resampling layer serve the independent assessment role. [tidymodels nested resampling](https://www.tidymodels.org/learn/work/nested-resampling/)

## Feasible narrow procedure (our dataflow inference)

Let B contain the base-training/calibration data, V be a separately reserved selection set, and T be untouched assessment data. V is disjoint from every fitted model's training and calibration observations, including every Cross fold. Its outcomes must not have been used for model/recipe tuning, precision, split choice, stopping, feature selection, or the procedure that produced the frozen endpoints.

1. Fit the intended procedure on B once, with all prior model/recipe selection confined to the corresponding training portions. Freeze models, fitted preprocessing, fold memberships, endpoint-producing calibration state, precision, class order and multiclass method.
2. Predict V with those exact fitted components. Compute both point rules from the same endpoint predictions. For multiclass, use one candidate loss consistently across all pairs/classes/folds and run the already specified coupling/normalization for each candidate.
3. Select one common loss using a predeclared primary metric on complete V predictions, with the agreed failure policy and a deterministic tie rule. The metric used for selection is distinct from the log/Brier aggregation option.
4. Retain the exact fitted components and chosen rule; use T only to assess the resulting frozen procedure.

This is selection between two post-processing rules, not joint retuning. It needs no additional model fitting or nested resampling solely to compare those two rules. Existing nested tuning inside B remains required wherever the accepted model-selection contract calls for it. V still costs held-out data: this exception removes repeated fitting and an additional *nested search* on selection data, not the need for independent selection observations. A previously reserved suitable V can fill that role; there is no reason to demand both S and V solely for this pure comparison.

## Reuse and limits

- Reuse unchanged base models, preprocessing and endpoint calibration state. Reuse saved endpoint predictions for comparing both loss rules on V; apply the chosen rule to endpoint predictions for future observations. Multiclass loss may change coupled point probabilities, but must not alter upstream scores/endpoints.
- V's result is a selection result, not an independent final performance estimate. Keep T distinct. An outer resampling assessment, if wanted, repeats the full fit-plus-V-selection procedure inside each outer training portion.
- Do not fold V back into B under the label 'same fitted procedure': refitting models or calibration changes the predictor that was compared. Whether some V observations can participate in a separately designed refit is a new data-role question, not a benefit proven by this exception. No automatic refit or reuse follows from accepting pure loss selection.
- In particular, do not retune fold models under the chosen loss: that makes this a feedback path and leaves the pure post-fit exception. A common loss selected through predictions depending on calibration folds can then feed those folds' outcomes back into model selection.
- Do not use calibration outcomes themselves as the independent selection set. This note provides no argument that such selection is safe under the agreed contract.
- Precision, regression moderation, model/recipe settings and fold structure are outside this exception because this proposal freezes them. The raw binary IVAP endpoint object being unchanged does not transfer its theoretical selector statement to the selected point probabilities, whole Cross aggregation or multiclass output.

## Decision implication

A narrow 'freeze fitted procedure, choose only common point-loss rule on independent V, keep fitted components' path is defensible and inexpensive. It can be offered as a separate explicit path if desired. Choosing it does not weaken the accepted S-first architecture for common options that can influence subsequent model selection, and does not justify claims of guaranteed point calibration or improved predictive performance.
