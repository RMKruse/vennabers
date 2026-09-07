# Native tidymodels-Integration: technischer Vertrag für den vorläufigen v0.5-Umfang

Recherche vom 2026-09-07 für [Native tidymodels-Schnittstelle und v0.5-Integrationsvertrag konkretisieren](https://github.com/RMKruse/venn-abers/issues/9).

**Ergebnis:** Ein eigenes parsnip-Modell für den vollständigen kalibrierten Prädiktor, eingebettet in einen normalen Workflow mit `add_variables()`, ist die geeignete öffentliche Erweiterungsstelle. Die Basismodell-Workflows mit ihrem gelernten Preprocessing liegen vollständig innerhalb dieses Modells. Damit können `fit()`, `predict()` und `tune::fit_resamples()` ihre normalen Aufgaben übernehmen. Ein eigener Predict-S3-Adapter erhält die beschlossene Loss-Wahl. Namens- und Sonderfallgrenzen erfordern die in Abschnitt 8 benannte Folgeentscheidung. Der folgende Vertrag ist ein technischer Implementierungsentwurf, keine bereits verfügbare vennabers-API oder durchgeführte numerische Integrationsabnahme.

Die verbindlichen fachlichen Vorgaben bleiben die Resolutionen [Nutzervertrag](https://github.com/RMKruse/venn-abers/issues/6#issuecomment-5562394965), [binäre Optionen](https://github.com/RMKruse/venn-abers/issues/8#issuecomment-5562516771), [Multiclass](https://github.com/RMKruse/venn-abers/issues/4#issuecomment-5561592433), [Multiclass-Optionen](https://github.com/RMKruse/venn-abers/issues/14#issuecomment-5562565289) und [Regression](https://github.com/RMKruse/venn-abers/issues/5#issuecomment-5561777290). Dieses Research entscheidet technische Details innerhalb dieser Vorgaben. Erkannte Konflikte werden ausdrücklich am Ende aufgeführt; sie reduzieren keine Zusage stillschweigend.

## 1. Erweiterungsstelle und Datenfluss

```text
normaler äußerer Workflow: Variablenauswahl ohne lernende Transformation
└── parsnip-Modell des vollständigen kalibrierten Prädiktors
    ├── lokale Rohdaten → innere Aufteilung
    ├── je Aufteilung: ungefitten Basis-Workflow nur auf analysis fitten
    ├── dieser Workflow → Vorhersagen auf assessment → manueller Kalibrator
    └── Predict: passende gespeicherte Workflows → Kalibratoren → Kernaggregation
```

`workflows::add_variables(outcomes=..., predictors=..., blueprint=...)` verwendet die XY-Schnittstelle. `hardhat::default_xy_blueprint(intercept=FALSE, allow_novel_levels=TRUE)` liefert Dataframes/Tibbles ohne Dummy-Kodierung, Imputation oder Skalierung. Neue Faktorlevels müssen bis zum jeweiligen inneren Workflow gelangen, dessen Recipe/Engine damit umgehen oder einen Fehler melden muss. Die äußere Blueprint merkt sich dennoch Typen und erforderliche Spalten; deshalb gehören temporäre Fold-IDs nicht in die Prädiktoren. Keine äußere Recipe, kein äußeres `add_formula(y ~ .)` mit potenzieller Modellmatrix-Erzeugung. [Öffentliche Variablen-API](https://workflows.tidymodels.org/reference/add_variables.html), [XY-Blueprint](https://hardhat.tidymodels.org/reference/default_xy_blueprint.html), [versionierter Workflow-Fit](https://github.com/tidymodels/workflows/blob/92e604424f8ee1d99f754c8c7e2b906d2cf7689d/R/fit.R).

Die registrierte Engine verwendet `interface="data.frame"`, `protect=c("x","y")`, einen Fit-Aufruf in vennabers und `set_encoding()` mit `predictor_indicators="none"`, `compute_intercept=FALSE`, `remove_intercept=FALSE`, `allow_sparse_x=FALSE`. Fit erhält Prädiktor-Dataframe und Zielvektor; der Zielspaltenname wird ausdrücklich in der Engine-Konfiguration gespeichert, weil die XY-Übergabe den ursprünglichen Namen nicht zuverlässig bewahrt. Der Engine-Fit rekonstruiert daraus die lokalen Rohdaten. Die Auswahl der Rohspalten und ihre kanonische Reihenfolge sind Teil der Konstruktion; beim Planvergleich werden nur diese Spalten, ihre Werte, Typen, Levels und Zeilenreihenfolge berücksichtigt. Dataframe-/Tibble-Klasse und Row Names sind keine Beobachtungsidentität. [parsnip-Registrierung](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/aaa_models.R), [Fit-Übersetzung](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/fit.R), [Entwickleranleitung](https://www.tidymodels.org/learn/develop/models/).

Der Konstruktor nimmt einen **ungefitten, fertig konfigurierten** Basis-Workflow entgegen. Modellmodus muss classification oder regression sein, genau eine originale Zielspalte ist erforderlich. Bereits gefittete Workflows, ge-preppte Recipes und nicht aufgelöste `tune()`-Platzhalter werden abgewiesen. Ein beliebiger zusätzlicher Basis-Tailor benötigt eigene Kalibrierungsdaten und ist nicht automatisch unterstützt: Die Erweiterung darf dessen Datenbedarf nicht durch Nutzung des inneren Kalibrierungsfolds als Trainingsdaten verdecken. Dasselbe gilt für unbekannte, zustandsbehaftete Engine-Spezialfälle. Die erste Abnahme verwendet normale Recipe-/Formel-/Variablen-Workflows ohne zusätzlichen Postprocessor; eine weitergehende Zusage ist gegebenenfalls eine gesonderte Entscheidung.

**Warum kein Postprocessor:** `tailor::adjust_predictions_custom()` ist für nicht geschätzte Anpassungen vorgesehen. `workflows::add_tailor()` plus `rsample::internal_calibration_split()` kann einen inneren Holdout für Postprocessing bereitstellen, erzeugt aber nicht den benötigten Verbund passender Fold-Workflows. `internal_calibration_split()` macht bei V-Folds einen Holdout innerhalb von analysis und ignoriert Wiederholungen; es ist nicht der Cross-Kalibrierungsplan. Ein neuer vollständiger Tailor-Schritt könnte eigene Orchestrierung nachbauen, bringt hier aber keinen Vorteil. [tailor-Vertrag](https://tailor.tidymodels.org/reference/adjust_predictions_custom.html), [Workflow-Postprocessing](https://workflows.tidymodels.org/reference/add_tailor.html), [rsample 1.3.2](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/internal_calibration_split.R).

**Bestehende Erweiterungen geprüft:** `baguette` 1.1.0 registriert seine Bagging-Engines über genau `set_model_engine`, `set_dependency`, `set_fit`, `set_encoding` und `set_pred`; dies belegt ein etabliertes Muster für zusammengesetzte Modelle. Dessen Formel-/Bagging-Implementierung ist kein Ersatz für den hier nötigen Rohdaten-/Foldvertrag, und dessen unbedingte `.onLoad()`-Registrierung wird wegen der optionalen Integration nicht kopiert. [baguette-Registrierung](https://github.com/tidymodels/baguette/blob/96bcbe4737a5b3ae31c2d9255e7d737f40f1e26d/R/bag_tree_data.R), [Ladehook](https://github.com/tidymodels/baguette/blob/96bcbe4737a5b3ae31c2d9255e7d737f40f1e26d/R/zzz.R). `probably` 1.2.0 nimmt bei `cal_estimate_logistic()` bereits vorliegende Vorhersagetabellen beziehungsweise tune-Ergebnisse entgegen und schätzt daraus einen Kalibrator; dieser untersuchte Pfad hält nicht die geforderten passenden Cross-Basisworkflows bereit. Er wird nicht als vollständiger trainierbarer Venn-Abers-Prädiktor ausgegeben. [probably-Quellpfad](https://github.com/tidymodels/probably/blob/4a2b767aa2c2f3bb1b0770db3ce8f7bf2873c80a/R/cal-estimate-logistic.R).

## 2. Vorgeschlagene öffentliche Aufrufe und Parameter

Die Namen in diesem Abschnitt sind **geplante vennabers-Funktionen**. Die umgebenden tidymodels-Aufrufe existieren bereits. Der bestehende manuelle Name `venn_abers()` wird nicht als parsnip-Konstruktor überladen.

```r
calibrated_workflow(
  workflow, outcome, predictors = NULL,
  method = "inductive", classification = "binary", event_level = "first",
  calibration_prop = 0.2, v = 5L, strata = NULL,
  splits = NULL, seed = NULL,
  precision = NULL, loss = "log", m = NULL, epsilon = NULL
)

# Beispiel: base enthält bereits Recipe/Formel und ein konfiguriertes Modell.
va <- calibrated_workflow(base, outcome = "truth", method = "cross",
                          classification = "ovo", v = 5, seed = 42,
                          precision = 2, loss = "log")
fitted <- generics::fit(va, data = development)
predict(fitted, new_data, type = "prob", loss = "brier")
predict(fitted, new_data, type = "class", loss = "brier")
venn_abers_details(fitted, new_data, loss = "brier")
state <- workflows::extract_fit_engine(fitted)
```

- `outcome`: ein Spaltenname; `predictors`: optional explizite Namen der Rohspalten, sonst alle anderen übergebenen Spalten. Die Basis-Recipe darf darin enthaltene ID-Spalten weiterhin als ID behandeln; der Carrier fordert sie bei Predict trotzdem an. Beispiele verwenden deshalb nur tatsächliche Eingabespalten. Ziel und ausgewählte Spalten müssen mit dem Basis-Workflow übereinstimmen. Die Konstruktion und das Drucken benennen die äußere Schicht als Datentransport, sodass Nutzer ihre Recipe im **Basis-Workflow** ändern.
- `method`: exakt `"inductive"` oder `"cross"`. **Entwurfsstandard Inductive**, weil ein Modell und eine einfach sichtbare Trainings-/Kalibrierungsgrenze genügen. Cross ist explizit auswählbar. Das ist eine Bedienvorgabe, keine Überlegenheitsbehauptung.
- `classification`: exakt `"binary"`, `"ovo"`, `"ovr"`; Standard `"binary"` verlangt genau zwei Faktorlevels. OvO/OvR müssen für mehr Klassen ausdrücklich gewählt werden und bleiben auch mit genau zwei Klassen eigene Multiclass-Wege. Der Modellmodus kommt aus der Basisspezifikation; numerische Regression, einschließlich ausschließlich 0/1 enthaltender Ziele, wird niemals als Klassifikation umgedeutet. Für Regression sind ausdrücklich angegebene Klassifikationsoptionen Fehler; implizite Klassifikationsdefaults werden nicht angewendet.
- `event_level`: `"first"`/`"second"`, nur für binary, Standard first wie yardstick. Die konkrete Ereignisklasse wird als Name gespeichert. Ein Wechsel verlangt erneute binäre Kalibrierung; dies ist kein bloßer Metrik-Schalter. OvO/OvR besitzen ihre fachlich bereits festgelegten Ereignisregeln.
- `precision`: Fit-Option nach dem Kernvertrag, NULL oder einzelne endliche numerische ganze Zahl, einschließlich negativer Zahlen, keine logischen Werte. `loss`: `"log"`/`"brier"`, Standard log; in der Spezifikation gespeicherte **Vorhersagevorgabe**, die native Resampling-Aufrufe verwenden. Ein ausdrücklich bei Predict angegebenes loss überschreibt sie ohne Refit. Gleiche Wahl für prob, class und Details. Regression weist beide ausdrücklich angegebenen Optionen ab.
- `m`/`epsilon`: ausschließlich Regression; beide NULL bedeutet effektiv `m=1`. Nur eine ausdrücklich angegebene Moderation ist erlaubt. Pro Kalibrierungsfold gelten `1 <= m <= floor((k-1)/2)` beziehungsweise `m_f=floor(epsilon*(k_f+1)/2)` und dieselbe Domäne. Angeforderte und wirksame Werte werden gespeichert.
- Unbekannte Argumente, mehrere/fehlende Werte, stilles Partial Matching und irrelevant ausdrücklich angegebene Optionen sind Fehler. Defaults werden intern von ausdrücklich gelieferten Argumenten unterschieden. `splits` und explizit gesetzte automatische Split-Optionen dürfen sich nicht widersprechen.

**Predict-Schnittstelle:** Die normale `predict.model_fit()` akzeptiert `loss` in `...` nicht; `opts` ist kein allgemeiner Ersatz für prob/class. parsnip versieht Fit-Objekte aber mit der dokumentierten Engine-Unterklasse `_<Engineklasse>`. Eine paketregistrierte Methode `predict._vennabers_fit(object, new_data, type=NULL, ..., loss=NULL)` konsumiert und validiert loss, verwendet eine lokale Kopie mit dieser Vorhersagevorgabe und delegiert an `parsnip::predict.model_fit()`; registrierte Engine-Pred-Funktionen lesen den gewählten Wert. `predict.workflow()` reicht die Argumente in einem Workflow ohne Tailor weiter. Das Umgehen von `check_dots_empty()` durch fremde Namespace-Manipulation ist nicht erforderlich. [parsnip Predict](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/predict.R), [Workflow Predict](https://github.com/tidymodels/workflows/blob/92e604424f8ee1d99f754c8c7e2b906d2cf7689d/R/predict.R), [Engine-Fit-Klassen](https://parsnip.tidymodels.org/reference/model_fit.html).

Für äußere Bewertung `loss="brier"` bereits am ungefitten `calibrated_workflow()` festlegen. Ein `loss`-Argument direkt an `fit_resamples()` ist nicht vorgesehen. Eine nachträgliche andere Auswertung darf gespeicherte Fit-Objekte ohne erneutes Training verwenden; automatische Multi-Loss-Submodelloptimierung gehört zum [Tuning des vollständigen kalibrierten Verfahrens bis v1.0 festlegen](https://github.com/RMKruse/venn-abers/issues/10).

## 3. Lokale Aufteilungen, Identität und Zufall

**Automatisch:** Inductive ruft lokal `initial_split(data, prop=1-calibration_prop, ...)` auf; `calibration_prop=0.2`, strikt zwischen 0 und 1. Cross verwendet `vfold_cv(data, v=v, repeats=1, ...)`, standardmäßig fünf, mindestens zwei Folds. Der Trainingsanteil ist jeweils analysis, Kalibrierung assessment. Bei Klassifikation bedeutet `strata=NULL` die Zielspalte, bei Regression keine Stratifikation; `strata=FALSE` schaltet sie ausdrücklich aus. Andere Werte gehören zum expliziten rsample-Plan. Klassifikations-Stratifikation verwendet `pool=0`, um Klassen nicht unbemerkt in größere Strata umzuhängen; Warnungen über kleine Klassen werden weitergegeben. Das garantiert weder alle Klassen in jedem Fold noch dessen Zulässigkeit. Statt automatischer Retry-Schleifen, Foldzahlreduktion oder Clipping folgt die gemeinsame Validierung. Dies ist bewusst strenger als die rsample-Defaults (`initial_split`: 3/4, `vfold_cv`: zehn Folds, `pool=.1`). [Holdout](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/initial_split.R), [V-Folds](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/vfold.R), [Strata/Pools](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/make_strata.R).

**Explizit:** `splits` ist bei Inductive ein `rsplit`; bei Cross ein `rset` mit eindeutigen einfachen Fold-IDs. Zugelassen sind normale IID-`initial_split`, unrepeated `vfold_cv` und mit `make_splits()`/`manual_rset()` konstruierte gleichwertige Aufteilungen nach Inhaltsprüfung. Ein Klassenname allein beweist keine gültige Partition. Für äußeres Resampling kann `splits` eine serialisierbare Funktion mit Signatur `function(data)` sein, die genau einen passenden lokalen Plan zurückgibt. Sie wird nur mit den aktuellen äußeren analysis-Daten aufgerufen. Ein auf allen Entwicklungsdaten aufgebauter statischer Plan kann nicht auf jede äußere Teilmenge angewendet werden.

```r
# Festgelegter direkter Cross-Plan:
set.seed(42)
inner <- rsample::vfold_cv(development, v = 5, strata = truth, pool = 0)
va <- calibrated_workflow(base, "truth", method = "cross", splits = inner)
fitted <- generics::fit(va, development)

# Automatische lokale Pläne während normaler äußerer Bewertung:
va <- calibrated_workflow(base, "truth", method = "cross", v = 5)
set.seed(104)
outer <- rsample::vfold_cv(development, v = 5, repeats = 2, strata = truth)
set.seed(105)
result <- tune::fit_resamples(
  va, resamples = outer,
  metrics = yardstick::metric_set(yardstick::brier_class, yardstick::mn_log_loss),
  control = tune::control_resamples(
    save_pred = TRUE, extract = workflows::extract_fit_engine,
    event_level = "first", parallel_over = "resamples", pkgs = "vennabers"
  )
)
```

**Vorab festgelegte innere Pläne für jeden äußeren Split:** Mit `analysis(outer$splits[[i]])` die lokalen Daten erzeugen und dafür je einen inneren Plan speichern. Eine `splits=function(data)`-Closure sucht nach *exakter* Übereinstimmung des kanonischen lokalen Daten-Snapshots und liefert den zugehörigen Plan. Kein globaler Zeilenzähler, kein Abgleich bloß anhand von Zeilenzahl, Foldname oder zufälligem Seed. Bei identischen lokalen Datensätzen sind nur identische Pläne zulässig; unterschiedliche Pläne für denselben Datenbestand erfordern zusätzliche Resample-Identität, die der normale Engine-Fit nicht erhält. Für wiederholte V-Folds sind die lokalen Bestände normalerweise verschieden; die äußeren Kennungen `id`/`id2` bleiben bei tune. Der einfache Resolver ist ein dokumentiertes O(B*n)-Verfahren für B vorbereitete äußere Pläne; erst bei gemessenem Bedarf ist eine zusätzliche Indizierung sinnvoll. Nutzerfunktionen sind vertrauenswürdiger R-Code: Sie dürfen auch über Closures keine Bewertungsdaten für Entscheidungen verwenden; eine API kann dies nicht allgemein beweisen.

**Validierung vor Modelltraining:**

1. Plan-Daten und aktuelle lokale Daten sind kanonisch identisch; nicht passende Werte, Typen, Faktorlevels, Spalten oder Zeilenreihenfolge sind Fehler. Doppelte inhaltlich identische Beobachtungen bleiben getrennte Positionen; Row Names sind keine IDs. Diese Identitätsprüfung belegt Datenzuordnung, nicht die historische Unabhängigkeit vorgelagerter Parameterwahl.
2. `as.integer(split, data="analysis"/"assessment")` liefert Indizes; jedes Set besteht aus eindeutigen gültigen Positionen, ist nichtleer, und analysis/assessment sind disjunkt. Bei Inductive bilden sie zusammen die lokalen Daten. Bei Cross ist jedes analysis-Set exakt das Komplement seines assessment-Sets und jedes lokale Element kommt insgesamt genau einmal als assessment vor. Eindeutige, nichtleere Fold-IDs bleiben erhalten. Keine abgeschnittenen, doppelt verwendeten oder übersprungenen Folds.
3. Je Methode die Kernregeln prüfen: binäre nichtleere Ein-Klassen-/Singleton-Kalibrierungen sind erlaubt; Multiclass muss jede gespeicherte Klasse global in seinen Kalibrierungsdaten beobachten, erlaubt fehlende Klassen einzelner Folds, weist aber leere OvO-Paar-/Fold-Kalibrierungen mit Paar und Fold ab. Bei Inductive ist hierfür das Kalibrierungsset maßgeblich, bei Cross die gemeinsame OOF-Kalibrierung. Regressionsfolds müssen die Moderationsgröße erfüllen. Die Trainingsfähigkeit des jeweiligen Basismodells wird zusätzlich geprüft: Ein zulässiger Ein-Klassen-Kalibrator macht ein dort nicht trainierbares Basismodell nicht trainierbar.
4. Repeated inner V-Folds, Bootstrap-Duplikate, überlappende Monte-Carlo-Holdouts, Zeit-/Gruppen-/permutierte Splits erfüllen diesen inneren Vertrag nicht oder tragen zusätzliche Semantik und werden nicht still als Cross-Partition akzeptiert. Gruppen-/Zeitreihen bleiben beim vorhandenen Ausbauticket.

Die Indizes lassen sich mit exportierter S3-Methode lesen; Inhaltsabgleich kann ausschließlich über `analysis()`/`assessment()` und die entsprechenden aktuellen Datenausschnitte erfolgen. Zusätzlich muss die Gesamtgröße passen. Ein Produktadapter muss keine privaten rsample-Funktionen aufrufen. [rsplit-Methoden](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/rsplit.R), [Konstruktoren](https://rsample.tidymodels.org/reference/make_splits.html), [manuelle rsets](https://rsample.tidymodels.org/reference/manual_rset.html).

**Äußere Bewertung:** Geprüfter v0.5-Weg ist normales und wiederholtes IID-V-Fold sowie ein disjunkter Holdout über `manual_rset`. Äußere Bewertungssets dürfen über unterschiedliche Resamples überlappen; sie dürfen nie mit dem *eigenen* äußeren Trainingsset überlappen. Ein `mc_cv` ohne Zurücklegen je Split kann dieselbe Eigenschaft erfüllen, muss explizit geprüft werden. Bootstrap-, Gruppen- und Zeitverfahren sind keine implizite Zusage. Der Engine-Fit sieht allein die lokalen Daten, nicht den äußeren `rsplit`; eine vollständige Prüfung äußerer Provenienz liegt deshalb in Beispielen/Abnahme und bei den Aufrufern, nicht in einer behaupteten magischen Engine-Prüfung. Ein vom Nutzer absichtlich mit überlappenden analysis/assessment erzeugtes äußeres `manual_rset` kann der native Aufruf nicht nachträglich erkennen.

**Zufall:** `seed=NULL` benutzt den vom Aufrufer beziehungsweise tune bereitgestellten RNG-Strom. Ein einzelner endlicher ganzzahliger Seed in der Spezifikation setzt mit `withr::with_seed()` einen lokalen RNG-Zustand für den vollständigen Engine-Fit einschließlich Planfunktion und sequenzieller Fold-Fits und stellt den Aufruferzustand wieder her. Nicht denselben Seed in jedem Fold neu setzen. Inneres Modelltraining bleibt zunächst seriell; tune parallelisiert außen mit `parallel_over="resamples"`. Gleiche Daten, R-/Paketversionen, Engine, Threadzahl, Seed und Parallelstrategie müssen reproduzierbar sein, soweit die Engine deterministisch arbeitet. Wechsel der Strategie, GPUs und externe Engine-Zufallsquellen sind keine automatische Bitgleichheitszusage. Der Seed des äußeren Plans wird vor dessen Erzeugung separat gesetzt. Speicherung umfasst Seed-Einstellung, RNG-Art, tatsächliche Fold-Zuordnung und Engineparameter. [tune-Zufallsvertrag](https://tune.tidymodels.org/reference/control_grid.html), [withr-Seed](https://withr.r-lib.org/reference/with_seed.html).

## 4. Klassen, Kernadapter und Ausgaben

Das Klassenuniversum wird aus den ursprünglichen Faktorlevels gespeichert; Namen bestimmen die Zuordnung der Modellwahrscheinlichkeiten. Character-/Logical-/Numerik-Ziele werden nicht still in Faktoren umkodiert. Ein binärer Adapter bildet `truth == event_class` auf den logischen Kernvektor ab und nimmt die dazugehörige benannte Wahrscheinlichkeitsspalte. Er liefert zwei Klassenwahrscheinlichkeiten, die Ereigniswahrscheinlichkeit und ihr Komplement, in gespeicherter Level-Reihenfolge. Bei genau 0.5 gewinnt die Ereignisklasse. OvO/OvR verwenden dagegen den Faktor-/Matrix-Kern; auch bei zwei Klassen gewinnt bei Gleichstand das erste gespeicherte Level.

Für Multiclass validiert der Adapter vollständige eindeutige Klassenspalten, Endlichkeit, [0,1] und Zeilensummen mit der bestehenden Toleranz 1e-8, ordnet nach Namen und normiert innerhalb dieser Toleranz. OvO erstellt Paare auf dem **gemeinsamen** R-Foldplan, nimmt die spätere Klasse als Ereignis und behandelt exakt nullwertige Paarsummen zuerst mit (0.5,0.5). OvR verwendet die betrachtete Klasse als Ereignis. Erst dann wird ausschließlich die binäre Kalibrierungswahrscheinlichkeit optional nativ in R gerundet; bei precision=0 wird auch der Ersatzwert 0.5 zu 0. Neue Wahrscheinlichkeiten bleiben ungerundet.

Bei Cross werden zuerst die binären Fold-Ergebnisse zusammengeführt: Log stabil über Endpunkte, Brier über gleichgewichtete Fold-Punktwerte `u+(l^2-u^2)/2`. Danach folgt die vereinbarte OvO-Kopplung beziehungsweise OvR-Normierung. Keine Mittelung bereits gekoppelter Multiclass-Foldvorhersagen. Regression verwendet ihre gewichteten IVAR-Punktwerte und getrennte gleichgewichtete CVAR-Mittelwerte, ohne Klassifikations-Loss/Rundung. Der gemeinsame R-Foldplan ersetzt nicht die paarweisen Python-Modell-/Foldwege; deren zusätzliche Parität liegt beim vorhandenen Vollmodell-Ticket. [Verbindlicher Options- und Ereignisvertrag](https://github.com/RMKruse/venn-abers/issues/14#issuecomment-5562565289).

| Zugang | Geplantes Ergebnis |
|---|---|
| `predict(fitted, new_data, type="prob", loss=...)` | Tibble mit einer Double-Spalte `.pred_<Klasse>` je ursprünglicher Klasse, gespeicherte Reihenfolge |
| `type="class"` | Tibble `.pred_class`, Faktor mit allen gespeicherten Levels, Entscheidung aus denselben endgültigen Wahrscheinlichkeiten |
| Regression `type="numeric"` | Tibble `.pred` als Double, in Zielgrößeinheiten |
| `venn_abers_details(fitted, new_data, loss=...)` | Liste `prediction` mit derselben nativen Punkt-/Wahrscheinlichkeitstabelle und `details` mit eindeutiger Zeilen-/Fold-/Teilproblemzuordnung |
| `workflows::extract_fit_engine(fitted)` | Dokumentiertes `vennabers_fit`-Objekt mit vollständigem Modell-/Kalibratorzustand |

Details für binary: `row`, `fold` (Inductive stabile Einzel-ID), `event_class`, `lower`, `upper`, `probability`. Für Multiclass zusätzlich `method`, `class_1`, `class_2` bei OvO oder `class` bei OvR; `event_class` ist ausdrücklich enthalten. `probability` ist der gewählte binäre Fold-Punktwert, nicht die endgültige gekoppelte Wahrscheinlichkeit. Regression: `row`, `fold`, `prediction`, `lower`, `upper`; eine zusätzliche Tabelle `aggregate` mit `row`, `lower`, `upper` enthält bei Cross die beschreibenden gemittelten Grenzen. `prediction` bleibt die native `.pred`-Tabelle. Null/eine neue Zeile behalten sämtliche Spalten, Typen, Klassen- und Fold-Schemata. Für null Zeilen erzeugt der Adapter die typisierte leere Ausgabe vor dem Aufruf der inneren Engines; schon glm kann sonst bei leerer Wahrscheinlichkeitsvorhersage scheitern. Weder `conf_int` noch `pred_int` werden registriert.

Der separate Diagnosezugriff verwendet dieselbe öffentliche `hardhat::forge()`-Validierung mit `workflows::extract_mold(fitted)$blueprint` wie der native Workflow und dann denselben Engine-Vorhersagekern. So führen Schema-/Faktorbehandlung und Loss-Wahl bei Standardvorhersage und Details nicht zu verschiedenen Ergebnissen. [Forge-Vertrag](https://hardhat.tidymodels.org/reference/forge.html).

Der Engine-Zustand dokumentiert `parameters` (angefordert und effektiv), `class_levels`/`event_class`, `folds` (IDs, Trainings-/Kalibrierungspositionen und Größen, effektive m/epsilon), `models` als nach denselben IDs benannte Liste **vollständiger gefitteter Basis-Workflows**, `calibrator` als passendes Kernobjekt und `versions`. Im Cross-Fall gibt es kein zusätzliches Vollmodell. Nutzer können etwa `workflows::extract_recipe(state$models[[id]], estimated=TRUE)` zur Inspektion verwenden, müssen neue Daten aber mit dem vollständigen Workflow vorhersagen. [Öffentliche Extraktoren](https://workflows.tidymodels.org/reference/extract-workflow.html).

`saveRDS()`/`readRDS()` müssen für die geprüften reinen R-Referenzengines alle Fold-Zuordnungen, Parameter und Ergebnisse erhalten. Ein frischer Prozess lädt vennabers und erforderliche Basisengine-Pakete. Externe Pointer/GPU-/Remote-Modelle können eigene Serialisierung benötigen; keine allgemeine Portabilitätsgarantie allein durch die äußere R-Liste. Die geplante Integration darf Fold-Modelle nicht zur Speicheroptimierung entfernen. Für große Resampling-Ergebnisse ist explizite Wahl zwischen kompakten Diagnoseextrakten und vollständigen Modellen nötig.

## 5. Native Bewertung und vollständige Ergebnisprüfung

`tune::fit_resamples()` wertet jede äußere Vorhersage nach den normalen yardstick-Konventionen aus. Es liefert `resample_results`/`tune_results`; Zugriff über `collect_metrics(summarize=FALSE)`, `collect_predictions(summarize=FALSE)`, `collect_notes()` und `collect_extracts()`. `control_resamples(extract=workflows::extract_fit_engine)` behält die Fold-Verbundmodelle; `extract=identity` bewahrt jeweils den gesamten äußeren gefitteten Workflow. `save_workflow=TRUE` allein speichert nicht jeden gefitteten Resample-Verbund. [Fit-Resamples](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/resample.R), [Control](https://tune.tidymodels.org/reference/control_grid.html), [Ergebniszugriff](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/collect.R).

- Binär muss die ausgewählte Ereigniswahrscheinlichkeit zur `event_level`-Einstellung der Metrik passen. Am Konstruktor und `control_resamples()` dieselbe Einstellung verwenden; die native Workflow-Spezifikation ändert tune-Control nicht heimlich. Bei Multiclass stehen Wahrscheinlichkeitsspalten in Faktorlevel-Reihenfolge; One-vs-All-Metriken haben ihre eigene Ereignisdefinition.
- Yardstick-Brier ist `sum((one_hot-p)^2)/(2*n)`. Der manuelle Multiclass-Score bleibt doppelt so groß, auch im Zwei-Klassen-Matrixweg. Der binäre Vektor-Brier `mean((truth-p_event)^2)` entspricht yardstick ohne diesen Faktor. `loss="brier"` bezeichnet Kalibrierung und verändert keine dieser Score-Definitionen. [Brier 1.4.0](https://github.com/tidymodels/yardstick/blob/304a28903392b1a937056ced4e0260a0ccad237c/R/prob-brier_class.R).
- Yardstick 1.4.0 begrenzt nur für die Log-Loss-Berechnung die Wahrscheinlichkeiten auf `[.Machine$double.eps,1-.Machine$double.eps]`. Daher ist eine sichere Fehlklassifikation mit Wahrscheinlichkeit null endlich bewertet (ca. 36.04365), während der bestehende manuelle `log_loss()` dafür Inf liefert. Die gespeicherten Vorhersagen werden dafür nicht geclippt. [Log Loss 1.4.0](https://github.com/tidymodels/yardstick/blob/304a28903392b1a937056ced4e0260a0ccad237c/R/prob-mn_log_loss.R), [bestehender R-Kern](https://github.com/RMKruse/venn-abers/blob/e5dce5e/R/venn_abers.R).
- Regression: RMSE und MAE auf `.pred`; R² ist bei konstanten Zielwerten keine immer definierte Erfolgskontrolle. Kein Coverage-Score für die VA-Regressionsgrenzen.
- Ein fehlgeschlagener innerer Fit macht den **ganzen** äußeren Fit ungültig; keine Teilergebnisse als verkleinertes Ensemble. tune kann andere äußere Fits fortsetzen und sammelt Fehler/Warnungen. Ein Mittelwert über die übrigen Fits ist keine vollständige Bewertung. `collect_notes()`, erwartete gegen vorhandene `(id,id2,.row)`-Vorhersagen und endliche Metric-Werte je Resample müssen geprüft werden. Auch reine Metrikfehler oder NA-Entfernung (`na_rm=TRUE` ist oft Default) können die tatsächlich ausgewertete Menge verkleinern. Bei vollständigem Ausfall können Collector-Funktionen selbst fehlschlagen; die Abnahme muss auch diesen Fall abdecken.
- `collect_predictions(summarize=TRUE)` mittelt Vorhersagen über äußere Wiederholungen und kann Klassen neu ableiten. Das ist weder der innere Cross-Merger noch eine Zusage der binären Ereignis-Gleichstandsregel für diese nachträgliche Zusammenfassung. Für Vertragsabnahme und eigene Zusammenfassungen werden die unzusammengefassten Ergebnisse verwendet.

## 6. Optionale Pakete, Versionen und Registrierung

Die Versionsuntergrenzen sind **konservative technische Baselines**, keine Behauptung, die jeweilige API sei erst dort eingeführt worden. Niedrigere Kombinationen können später separat geprüft werden. Die manuelle Kerninstallation behält R >= 4.1.0; Die DESCRIPTION-Dateien der gewählten direkten Modellierungspakete verlangen ebenfalls R >= 4.1; der vollständige transitive Abhängigkeitsbaum muss auf der später zugesagten R-Untergrenze gesondert installiert und geprüft werden. Die hier erfolgreiche Ausführung unter R 4.6.1 ersetzt diese Prüfung nicht.

| Teilpaket | Vorgeschlagene Mindestversion | Direkte Verwendung |
|---|---:|---|
| parsnip | 1.6.0 | Modellspezifikation, öffentliche Engine-Registrierung, Predict-Adapter |
| workflows | 1.3.0 | Rohdaten-Carrier und vollständige innere Workflows |
| hardhat | 1.4.3 | XY-Blueprint, öffentliche Extraktoren |
| rsample | 1.3.2 | lokale Pläne und deren öffentliche Zugriffsfunktionen |
| tune | 2.1.0 | äußere Bewertung; nur dafür zwingend erforderlich |
| yardstick | 1.4.0 | Metriken; nur für Bewertung zwingend erforderlich |
| recipes | 1.4.0 | wenn der Basis-Workflow eine Recipe verwendet; im workflows-Abhängigkeitsbaum enthalten |
| rlang | 1.2.0 | Quosures für Spezifikation |
| tibble | 3.3.1 | native Vorhersagetabellen |
| withr | 3.0.3 | lokale, wiederhergestellte RNG-Zustände |
| generics | 0.1.4 | dokumentierter `fit()`-Einstieg in Beispielen |

Diese direkt verwendeten Pakete gehören in `Suggests`, nicht `Imports`/`Depends` des manuellen Kerns. Hinzu kommen die vom Nutzer gewählten Basisengines; kein obligatorisches `tidymodels`-Metapaket und kein tailor, dials oder zusätzlicher Parallel-Backend allein für die hier beschriebene Orchestrierung. Transitive Abhängigkeiten von workflows/tune können diese trotzdem installieren. Der Integrationskonstruktor prüft Verfügbarkeit und Mindestversionen und meldet konkret fehlende Pakete. Bewertung prüft zusätzlich tune/yardstick; Beispiele können diese mit `requireNamespace()` prüfen. Keine automatische Paketinstallation beim Laden von vennabers.

Für die Engine-Registrierung und Spezifikation werden `new_model_spec`, `set_new_model`, `set_model_mode`, `set_model_engine`, `set_dependency`, `set_fit`, `set_encoding` und `set_pred` verwendet; keine direkten Schreibzugriffe auf parsnips Registry. Die optionale Registrierung muss bei beiden Ladereihenfolgen und in frischen Workerprozessen funktionieren. Verwendet wird ein Base-R-Hook `setHook(packageEvent("parsnip", "onLoad"), ...)`, plus sofortige Registrierung, falls parsnip bereits geladen ist, und ein idempotenter Aufruf aus dem Integrationskonstruktor. `rlang::on_load()` ist hierfür nicht die genannte Paketnamen-Schnittstelle. Laden des Kerns ohne optionale Pakete löst kein `requireNamespace("parsnip")` aus. Vorhandene fremde Registrierung unter demselben Modellnamen ist ein Fehler, kein Anlass zum Überschreiben. Die eigene `predict._vennabers_fit`-Methode wird als stats-S3-Methode in vennabers registriert und nutzt parsnip erst im Integrationsaufruf. [Öffentliche R-Ladehooks](https://stat.ethz.ch/R-manual/R-devel/library/base/html/ns-hooks.html). Worker müssen vennabers sowie die Basisengine-Namespaces laden; `pkgs`/Engine-Dependencies müssen die verschachtelten Basisengine-Abhängigkeiten ausdrücklich erfassen, denn parsnip erkennt nicht automatisch jedes Paket im gespeicherten Basis-Workflow.

Versionierte Quellstände: parsnip v1.6.0 `82c45c12d735143923449194fab9c462dec5fcf7`, workflows v1.3.0 `92e604424f8ee1d99f754c8c7e2b906d2cf7689d`, hardhat v1.4.3 `2f28f1f6f721c2afe39d765a7d9247edd4bad652`, rsample v1.3.2 `658545caf9855dd74ec13c2ac63163889e632a7b`, yardstick v1.4.0 `304a28903392b1a937056ced4e0260a0ccad237c`, tune v2.1.0 `4c74638b2b0d486dc12b39d037bbeb26326ad35c`. Die Tags wurden über die jeweiligen offiziellen GitHub-Repositories aufgelöst.

## 7. Ausführbare Abnahme nach Implementierung

Die folgenden Prüfungen sind auszuführen, sobald die geplante Integration und die vorausgesetzten Kernoptionen vorhanden sind. Sie sind nicht durch einen Schnittstellen-Smoke-Test ersetzt.

1. **Alle Verfahren:** binary/OvO/OvR/regression × Inductive/Cross; Klassifikation zusätzlich Log/Brier × precision NULL/0/2/-1 und zwei bis vier Klassen. Mit gespeicherten Modellvorhersagen und denselben Plänen separat den manuellen Kern aufrufen und native Ergebnisse/Details vergleichen. Klassifikation absolut 1e-10, Regression die beschlossene skalenbezogene absolute+relative Toleranz. Keine Python-Trainingsparität aus identischen Seeds ableiten.
2. **Leakage:** Inneres Recipe lernt Imputation/Skalierung nur auf analysis. Ein extremer Wert ausschließlich in Kalibrierung darf die Trainingsstatistik nicht ändern; ein extremer Wert ausschließlich außen darf keinen inneren Zustand verändern. Äußere Assessment-Zielwerte ändern nur Metriken. Fünf äußere × fünf innere Folds erzeugen genau 25 Basismodell-Fits.
3. **Zustand:** Modell-/Kalibrator-Foldzuordnung absichtlich vertauschen und Abweichung erkennen. Predict ändert keine Fits, ruft kein fit/prep auf und ist für deterministische Engines zeilen-/batchinvariant. RDS-Roundtrip im frischen Prozess; null/eine neue Beobachtung für alle Ergebnisformen.
4. **Pläne:** Automatische/feste lokale Pläne liefern bei identischen Aufteilungen dieselben Ergebnisse. Fremde gleich große Daten, Umordnung, wiederholte innere Folds, doppelte/missing Fold-IDs, Überschneidung, unvollständige Partition und ungültige Indizes werden abgewiesen. Äußere Wiederholungen bleiben zulässig und behalten id/id2. Mehrdeutige vorab berechnete Pläne für identische lokale Daten melden einen Fehler.
5. **Klassen:** Vertauschte benannte Wahrscheinlichkeitsspalten unverändert zuordnen; unbekannte/fehlende/doppelte Namen und globale fehlende Klassen abweisen. Binär Ereignis bei 0.5, Multiclass erstes Level auch im Zwei-Klassen-Fall. OvO-/OvR-Ereignisnamen und sämtliche Merger aus Details rekonstruieren. Leere OvO-Teilkalibrierung abweisen, erlaubte Singleton-Folds erhalten.
6. **Regression:** Minimale Folds, m/epsilon-Grenzen, ungleiche Größen, Konstantfälle und zwei Nullgewichte. Numerische 0/1-Ziele bleiben Regression. Keine Loss-/Rundungsoption durchreichen.
7. **Metriken/Fehler:** Brier-Faktor zwei, binäre Ereigniszuordnung, Extrem-Log-Loss, RMSE/MAE; ein innerer Enginefehler, ein reiner Metrikfehler, fehlende Assessment-Zeilen und sämtliche äußeren Fits fehlgeschlagen. Unvollständige Bewertung sichtbar ausweisen. Keine Einträge aus `collect_predictions(summarize=TRUE)` als innere Cross-Diagnostik verwenden.
8. **Optionalität/Versionen/Parallelität:** Kern unter minimaler R-Installation ohne Teilpakete installieren, laden und bisherige Tests ausführen. Integration auf konservativer Mindestkombination und aktueller Kombination mit gebauten Paketen; beide Ladereihenfolgen, frische Worker und Namespace-only-Nutzung. Dieselbe dokumentierte Parallelstrategie/Seedkonfiguration wiederholen. R CMD check, vollständige Beispiele und getrennte statistische Aussagegrenzen dokumentieren.

## 8. Evidenzstand und offene Konflikte

Die [ausführbare Forschungsprobe](tidymodels-interface-probe.R) lief am 2026-09-07 unter R 4.6.1 auf macOS arm64 mit den Tabellen-Versionen erfolgreich. Die Pakete wurden aus CRAN-Quellen in eine temporäre Bibliothek installiert; am Produktionspackage wurden keine Abhängigkeiten oder Features geändert.

```sh
# Bei bereits verfügbaren Forschungspaketen:
Rscript --vanilla tools/tidymodels-interface-probe.R
# In der hier benutzten temporären Bibliothek:
VENN_RESEARCH_LIB=/tmp/venn-tidymodels-lib \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/tidymodels-interface-probe.R
```

Ausgeführt und bestanden:

- Native parsnip-Registrierung und XY-Carrier; Zahlen, Faktor und fehlender Prädiktorwert erreichen den Engine-Fit unverändert.
- Drei innere glm-Workflows mit Imputation/Skalierung; jede gelernte Skalierungsmitte stimmt mit dem eigenen Trainingsanteil nach dessen Imputation überein.
- `fit()`/`predict()` einschließlich zusätzlichem loss über die Engine-S3-Klasse, unveränderter gespeicherter Default, Klassenausgabe und typisierte leere Ausgabe.
- RDS-Roundtrip im selben Prozess.
- Drei äußere V-Folds, darin jeweils drei erhaltene innere Modelle; alle 30 äußeren Vorhersagen, keine Notes; öffentliche Extraktion liefert die zugehörigen lokalen Rohdaten und Modellverbünde.
- rsample-Partition und Komplemente, reproduzierbarer fester Seed, Unterscheidung wiederholter und überlappender Pläne.
- Handrechenbarer Brier-Faktor zwei, richtige binäre Ereignisspalte und endliche yardstick-Extrem-Log-Loss von 36.04365.
- Erwarteter Negativfall für das Klassenlevel `class`: drei native äußere Predict-Fehler trotz funktionierendem alleinstehendem eigenen Predict; Notes vollständig und Metric-Collector meldet den Totalausfall.

Die Probe verwendet **absichtlich Mittelung von Modellwahrscheinlichkeiten und einen künstlichen Loss-Effekt**, keine Venn-Abers-Kalibrierung. Das isoliert den fraglichen API-Datenfluss. Sie beweist keine numerische VA-Parität, fertige Splitvalidierung, automatische Callback-Auflösung, optionale Namespace-Registrierung aus einem installierten vennabers-Package, frische Workerprozesse, Parallelreproduzierbarkeit oder engineübergreifende Serialisierung. Diese Abnahmen bleiben Abschnitt 7 vorbehalten.

### Präzise Grenzen für die anschließende menschliche Entscheidung

1. **Native Namen:** Die unveränderte parsnip-Wahrscheinlichkeitsmethode weist das Faktorlevel `class` ab; dessen `.pred_class` würde mit der nativen Klassenausgabe kollidieren. Bereits mit `.pred_` beginnende Levelnamen können zudem die Standardpräfixierung umgehen. Die zusätzliche Gegenprobe bestätigt: Eine eigene `predict._<Engineklasse>`-Methode kann die alleinstehende Vorhersage für `class` erzeugen, doch tune 2.1.0 ruft für diesen normalen Resampling-Pfad direkt `parsnip::predict.model_fit()` auf und umgeht sie. Alle drei äußeren Vorhersagen scheitern an der reservierten Klasse; `collect_notes()` enthält drei Fehler, `collect_metrics()` meldet den vollständigen Ausfall. Selbst ein zusätzlicher tieferer Predict-Adapter müsste noch die gleichnamigen Spalten lösen, die tune beim Zusammenführen der Vorhersagetypen erhält. Ähnliche Konflikte entstehen mit reservierten Ziel-/Prädiktionsspalten in gesammelten Tabellen. Alternativen: ausdrücklich beschränkte native Namensdomäne mit frühem Fehler und frei benanntem manuellem Kern; oder reversible Klassen-/Spaltenkodierung mit originaler Identität in Diagnose/Klassenausgabe und einem dafür geprüften nativen Metrikpfad. Ungeprüftes `make.names()` würde Identitäten zusammenfallen lassen und ist keine Lösung. [parsnip-Wahrscheinlichkeiten](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/predict_classprob.R), [Präfixierung](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/predict.R), [tune-Aufruf und Zusammenführen](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/loop_over_all_stages-helpers.R).
2. **Gleiche lokale Daten, verschiedene explizite Pläne:** Der normale Engine-Fit erhält keine äußere Resample-ID. Ein Callback kann dieselben lokalen Daten nicht reproduzierbar zwei verschiedenen vorab festgelegten Plänen pro äußerem Vorkommen zuordnen. Alternativen: pro identischem lokalem Datenbestand derselbe Plan; oder zusätzliche belegte Übergabe äußerer Identität beziehungsweise eine orchestrationserweiterte Schnittstelle. Der Entwurf liefert bei Mehrdeutigkeit einen Fehler, behauptet aber keine vollständige Unterstützung dieses Sonderfalls.
3. **Zusätzliche Kalibrierung im Basis-Workflow:** Für eine Basis mit eigenem Tailor/Postprocessor müssen dessen eigene Trainings-/Kalibrierungsdaten vollständig innerhalb des jeweiligen inneren Modelltrainingsanteils liegen. Einfaches `fit(base, data=analysis)` kann bei einem benötigten zusätzlichen Kalibrierungssatz nicht genügen. Alternativen: erste native Zusage ausdrücklich auf Basis-Workflows ohne zusätzlichen Postprocessor begrenzen oder eine zusätzliche geschachtelte Aufteilung mit klarer Zuständigkeit planen. Kein stiller Rückgriff auf den für Venn-Abers gehaltenen Kalibrierungsfold.

Diese Fragen sind keine Widerlegung des nachgewiesenen normalen parsnip-Wegs, aber verhindern eine unbeschränkte Zusage für jede Namens-/Workflow-/Planform. Sie sind im HITL-Folgeticket [Namens- und Sonderfallgrenzen der nativen tidymodels-Integration entscheiden](https://github.com/RMKruse/venn-abers/issues/15) erfasst; diese AFK-Recherche entscheidet sie nicht stellvertretend. Die bestehenden Fragen zu Tuning, Vollmodell-/paarweisen Python-Pfaden, eingefrorenen Modellen, Gruppen-/Zeitreihen und finalen Releases bleiben bei ihren bereits vorhandenen Tickets. Implementierung des vollständigen Prädiktors, Produktabnahme, Release-Publishing und CRAN bleiben außerhalb dieser Planungs-Map.
