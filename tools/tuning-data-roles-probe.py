"""Research-only dependency trace for the proposed A/B/C/D plan.
No model scores, Venn-Abers mathematics, or production implementation are tested.
Run: python3 tools/tuning-data-roles-probe.py
"""


def partitions(rows, method):
    if method == "inductive":
        held = rows[-max(1, len(rows) // 4):]
        return [(rows[:-len(held)], held)]
    assert len(rows) >= 3
    return [
        ([r for j, r in enumerate(rows) if j % 3 != f], rows[f::3])
        for f in range(3)
    ]


def resamples(rows):
    return [([r for j, r in enumerate(rows) if j % 2 != f], rows[f::2])
            for f in range(2)]


def trace(strategy, method, automatic):
    outer_train = list(range(200))
    outer_assessment = set(range(200, 220))
    final_test = set(range(220, 240))
    events = []

    def record(kind, seen, allowed, held=()):
        seen, allowed, held = set(seen), set(allowed), set(held)
        assert seen <= allowed
        assert seen.isdisjoint(held | outer_assessment | final_test)
        events.append((kind, seen))

    def fit_base(training, calibration, upstream=()):
        record("base training", training, outer_train, calibration)
        # Dependencies include earlier choices of shared calibration options.
        record("complete model dependency", set(training) | set(upstream),
               outer_train, calibration)
        record("calibrator", calibration, outer_train, training)

    def fixed_procedure(rows, held):
        start = len(events)
        record("fixed procedure input", rows, outer_train, held)
        for training, calibration in partitions(rows, method):
            fit_base(training, calibration)
        assert all(seen <= set(rows) for _, seen in events[start:])

    def local_search(training, calibration):
        record("local selection dependency", training, outer_train, calibration)
        for analysis, assessment in resamples(training):
            for _ in range(2):  # Two fixed model/recipe candidates.
                if strategy == "joint":
                    fixed_procedure(analysis, assessment)
                else:
                    record("uncalibrated candidate", analysis, training, assessment)
                record("selection metric", assessment, training, analysis)

    def selected_procedure(rows, held, upstream=()):
        start = len(events)
        record("selected procedure input", rows, outer_train, held)
        for training, calibration in partitions(rows, method):
            local_search(training, calibration)
            fit_base(training, calibration, upstream)
        assert all(seen <= set(rows) for kind, seen in events[start:]
                   if kind != "complete model dependency")

    if automatic:
        selection, final_fit = outer_train[:100], outer_train[100:]
        for analysis, assessment in resamples(selection):
            for _ in range(2):  # Two shared calibration configurations.
                selected_procedure(analysis, assessment)
                record("shared option selection", assessment, selection, analysis)
        before_final = len(events)
        selected_procedure(final_fit, selection, upstream=selection)
        # S may influence fixed lambda, but is never read by final training/calibration.
        for kind, seen in events[before_final:]:
            if kind in {"base training", "calibrator", "uncalibrated candidate"}:
                assert seen.isdisjoint(selection)
    else:
        selected_procedure(outer_train, ())

    # Negative control: a final held-out calibration row influencing its model
    # through parameter selection must be rejected even if direct fit excludes it.
    try:
        record("tainted model selection", [0, 1], outer_train, held=[1])
    except AssertionError:
        pass
    else:
        raise AssertionError("Calibration leakage was not detected")
    return len(events)


if __name__ == "__main__":
    count = 0
    for method in ("inductive", "cross"):
        for strategy in ("joint", "two_stage"):
            for automatic in (False, True):
                assert trace(strategy, method, automatic) > 0
                count += 1
    print(f"PASS: {count} structural data-role traces and negative leakage controls")
