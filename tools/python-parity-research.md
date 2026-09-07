# Python 1.5.4 ↔ R 0.2.0: Funktionsumfang und Paritätslücken

Recherche vom 2026-09-06 für [Python-Funktionsumfang und Paritätslücken erfassen](https://github.com/RMKruse/venn-abers/issues/3). R deckt bereits den binären Inductive-Kern und die stabile Cross-Log-Aggregation auf vorgegebenen Wahrscheinlichkeiten ab. Die wesentlichen offenen Bereiche sind Multiclass, moderierte Regression, zusätzliche Kalibrierungsoptionen und vollständige Modell-/Resampling-Abläufe.

Die Matrix beschreibt nachgewiesene Python-Fähigkeiten und ihre Grenzen, den R-Iststand sowie mögliche Abnahmen. Sie entscheidet nicht über Aufnahme oder Release-Zuordnung. API-Äquivalenz, numerische Verfahrensparität und bewusst abweichendes Verhalten gegenüber Referenzfehlern sind getrennt zu behandeln.

## Identität und Evidenz

- PyPI 1.5.4, veröffentlicht am 2026-08-12: [Release-Metadaten](https://pypi.org/pypi/venn-abers/1.5.4/json).
- Sdist `venn_abers-1.5.4.tar.gz`, SHA-256 `a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69`; heruntergeladen und geprüft.
- Git-Commit `0e7b4bc575ce230134576ba1c76688d46bf99ac7`; `src/venn_abers.py` ist bytegleich mit der Sdist-Datei; SHA-256 `ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`.
- Fünf öffentliche Klassen und zwei direkt exportierte Funktionen: `VennAbers`, `VennAbersCV`, `VennAbersMultiClass`, `VennAbersCalibrator`, `VennAbersRegressor`, `calc_p0p1`, `calc_probs`. [Paketexporte](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/__init__.py#L1)
- Die Sdist enthält alle vier Testdateien, aber keine Notebooks. Beispiele wurden deshalb aus genau diesem Git-Commit gelesen: [binär](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/simple_classification.ipynb), [Multiclass](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/multiclass_classification.ipynb), [Regression](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/ivar_example.ipynb), [sklearn](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/scikit_learn_integration.ipynb).
- Ausgeführt: alle 18 Release-Tests bestanden; fünf `All-NaN slice encountered`-Warnungen aus Zwischenrechnungen. Umgebung Python 3.14.6, NumPy 2.5.3, pandas 3.0.5, scikit-learn 1.9.0; ungepinnte Abhängigkeiten sind durch das Release erlaubt. Das ist eine dokumentierte Ausführungsumgebung, kein Nachweis für alle Dependency-Versionen.
- Zusätzliche Probes decken die unten ausdrücklich als ausgeführt markierten Kombinationen und Defekte ab. Andere Feststellungen stammen aus dem vollständigen Lesen der tatsächlichen Aufrufketten.

## Fähigkeitsmatrix der öffentlichen Wege

`n` bezeichnet Testzeilen, `K` Klassen, `F` Kalibrierungsfolds; bei induktivem Training ist `F=1`.

| Referenz / Zugang | Tatsächliches Python-Verhalten | R-Iststand | Lücke / Unterschied | Denkbare Abnahme / offene Entscheidung und Fundstelle |
|---|---|---|---|---|
| Manueller binärer Kern `VennAbers().fit(p_cal,y_cal)`; `predict_proba(p_test)` | Erwartet tatsächlich zweispaltige numerische Score-/Wahrscheinlichkeitsmatrizen; verwendet nur Spalte 1 (zweite Spalte), Labels numerisch 0/1. Liefert immer Tupel `(p_prime[n,2], p0_p1[n,2])`; Punktwert `p1/(1-p0+p1)`, erste Spalte Komplement. Keine Verlustwahl. `predict()` liefert 0/1 mit Schwelle `>=0.5`. `precision` ist Fit-Keyword. | Binärer IVAP vorhanden; [Fit][r-core], [Vorhersage][r-predict]. | Keine Rundungsoption oder Klassenentscheidung; R-Ausgabe ist dreispaltiger Dataframe. | Ties, einseitige Labels, Extrapolation und unabhängige PAVA-Referenz; Präzision und Klassenschwelle separat entscheiden. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L501-L565) |
| Direkte Funktionen `calc_p0p1`, `calc_probs` | Erzeugen dieselben Lookup-Tabellen bzw. Ergebnisse wie die Kernklasse; `setting` wählt Klassifikation oder Regression. Tabellen besitzen zweite Wertspalte und Länge Anzahl verschiedener Scores plus 1, entgegen vereinfachten Shape-Docstrings. | Numerische Entsprechung im [internen R-Kern][r-core]. | Keine exportierten Lookup-Funktionen; Schnittstellenunterschied, keine belegte numerische Lücke im binären Standardpfad. | Funktionale Äquivalenz reicht möglicherweise; kein Zwang zu identischen internen Tabellen/Exportnamen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L14-L278) |
| Manuelle binäre Fassade `VennAbersCalibrator(estimator=None).predict_proba(p_cal=...,y_cal=...,p_test=...)` | Kalibriert bei jedem Vorhersageaufruf neu über `VennAbers`; `fit()` ist hierfür nicht nötig. `loss`, `inductive`, `n_splits`, `cv_ensemble` erzeugen hier keinen CVAP. Optional `p0_p1_output=True` liefert das Tupel `(p_prime, p0_p1)` mit einer direkten `[n,2]`-Endpunktmatrix als zweitem Element. | Manuelles Fit/Predict über [venn_abers][r-predict]. | Kein zustandsloser Fassadenaufruf; Form und Zeitpunkt des Fits unterscheiden sich. | Bestehende manuelle CV-Schnittstelle eines anderen Ökosystems ist nicht aus diesem Fassadenpfad herzuleiten. Prüfen, dass unnütze Optionen nicht still eine andere Methode vortäuschen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1305-L1335) |
| Binäres Training `VennAbersCV` | Klont und trainiert Basismodell, erzeugt Kalibrierungsscores intern. IVAP via Holdout; CVAP via `StratifiedKFold`. Log- oder Brier-Merger. `cv_ensemble=True` nutzt jeweiliges Teilmodell, `False` nutzt für alle Test-Scores Vollmodell. Beide Varianten trainieren trotzdem Voll- und Teilmodelle. | [cross_venn_abers][r-cross] verarbeitet vom Aufrufer gelieferte passende Folds. | Training, Split-Erzeugung, Brier und Vollmodell-Variante fehlen als Paketfunktionen. | Numerische Prüfung bei identischen Fold-IDs und gelieferten Scores; Split-/Trainingstreue getrennt von Score-Kalibrierung prüfen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L669-L837) |
| Klassifikationsfassade mit Modell | Führt auch binäre Aufgaben durch `VennAbersMultiClass`: Kategorien werden vor dem Split per pandas dummykodiert; dann paarweise Modelle. `.fit()` und `.predict_proba()` über X/y; alte `_x_train`, `_y_train`, `_x_test` Keywords weiter akzeptiert. | Nur [Ablaufbeispiel mit vom Aufrufer trainierten GLMs][r-example]. | Kein Trainingswrapper, automatische Kategoriekodierung oder tidymodels-Integration. | Native R-Integration darf andere Objekte/Rückgaben verwenden; Feature-Kodierung, Modelltraining und Kalibrierung als getrennte Verträge festlegen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1231-L1257) |
| Manuelles Multiclass OvO | `va_type='one_vs_one'`: alle `K(K-1)/2` Paare; nur Kalibrierzeilen der beiden Klassen; Paarspalten durch ihre Summe normieren; binär kalibrieren; reziprokes Pairwise-Coupling, danach Zeilennormierung. Output `[n,K]`, optionale Liste aus `K(K-1)/2` Matrizen `[n,2]`. | Nicht vorhanden; ausschließlich [binäre Exporte][r-exports]. | OvO-Kalibrierung, Kopplung, Klassenmapping und Paar-Diagnostik fehlen. | Handrechenbares 3-/4-Klassen-Beispiel, Reihenfolge der Klassen/Paare, Zeilensumme und Nichtnegativität. Null-Paarsummen und fehlende Klassen müssen einen bewussten Vertrag bekommen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L357-L425) |
| Manuelles Multiclass OvR/OvA | Jede Klasse gegen alle anderen; jeweilige Score-Spalte und Komplement; alle Kalibrierzeilen; K binäre Kalibrierungen, positive Punktwerte anschließend zeilenweise normiert. **Jeder** `va_type` außer exakt `one_vs_one` geht in diesen Zweig, dokumentiert u.a. `one_vs_rest`/Notebook `one_vs_all`. Optionale Liste aus K Matrizen `[n,2]`. | Nicht vorhanden; ausschließlich [binäre Exporte][r-exports]. | OvR-Kalibrierung, Normierung und Klassen-Diagnostik fehlen. | OvR separat von OvO abnehmen; erlaubte Optionswerte explizit prüfen, Tippfehler nicht übernehmen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L427-L459) |
| Trainiertes Multiclass IVAP/CVAP | **Nur OvO**. Erst `OneVsOneClassifier.fit`, anschließend je Klassenpaar `VennAbersCV.fit` mit binär umkodierten Paarlabels. Paarweise eigene Holdouts/Folds; kein gemeinsamer globaler Multiclass-Foldplan. Pairwise-Coupling wie oben. `loss`, `precision`, `cv_ensemble` werden an die binären Teilkalibratoren weitergereicht. Diagnostik: Liste mit `K(K-1)/2` Matrizen `[n,2F]`. | Nicht vorhanden; binärer [Cross-Kern][r-cross] als Ausgangspunkt. | Multiclass-Komposition und Modell-/Fold-Verwaltung fehlen; getrennte Entscheidungen erforderlich. | Trainiertes OvR ist keine durch 1.5.4 belegte Kombination. Bei R-Resamples globalen vs. paarweisen Foldvertrag entscheiden. Ausgeführt: vier Kombinationen IVAP/CVAP × Ensemble/Vollmodell mit Brier, jeweils vier Klassen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L986-L1099) |
| Klassenvorhersage in der Fassade | `predict(...,one_hot=True)` standardmäßig `[n,K]` One-Hot, sonst ursprüngliche Labels. `argmax` löst Gleichstand zugunsten der ersten Klasse. `va_type` wird nicht weitergereicht; manuelle OvR-Wahrscheinlichkeiten haben deshalb keinen korrekt entsprechenden Fassaden-`predict`-Pfad. | [R-predict][r-predict] liefert Wahrscheinlichkeiten; keine Klassenentscheidung. | Klassenrückgabe, Tie-Regel und konsistentes Mapping sind offen, keine Pflicht zu One-Hot. | Erwartete native Klassenrückgabe und Tie-Regel entscheiden; `.predict` muss aus der ausgewählten Methode abgeleitet werden. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1393-L1409) |
| Raw-Regression `VennAbers(setting='regression')` | Akzeptiert eindimensionale Kalibrierungsscores und reelle Labels. `predict_proba` liefert ein bedeutungsloses Nullarray `[n,2]` und raw Grenzen `[n,2]`, anhand Min/Max der übergebenen Labels. Keine m-/epsilon-Moderation, kein sinnvoller Punktprädiktor. | Nicht vorhanden; [R-Validierung][r-core] akzeptiert nur binäre Truth. | Reeller Score-/Truth-Kern fehlt; Raw-Kern allein wäre noch keine moderierte IVAR. | Nicht mit dem vollständigen IVAR/CVAR-Verfahren gleichsetzen; eigener Score-Kern kann Bestandteil einer R-Regression sein. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L136-L278) |
| Regression `VennAbersRegressor` IVAR | Modelltraining plus Holdout. `fit(...,m=1,epsilon=None)`; m/epsilon moderieren obere und untere Kalibrierlabels asymmetrisch; zwei Raw-Kalibratoren bilden Intervall. Punktwert ist gewichteter Merger, **kein arithmetischer Intervallmittelpunkt**, obwohl Variable `mid` heißt. `predict` liefert `(point[n],interval[n,2])`, optional `return_folds=True` drittes Element `{'mid': [...], 'range': [...]}`. | Nicht vorhanden; [Exports][r-exports]. | Moderation, Regressionsgrenzen, Punktmerger und Trainingsablauf fehlen. | Moderation, Endpunkte, gewichtete Punkte und Fold-Diagnostik separat mit Originalverfahren/kleinen Fixtures testen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L706-L738), [Merger](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L856-L887) |
| Regression `VennAbersRegressor` CVAR | `inductive=False,n_splits=F`; `KFold` **ohne** Stratifikation; m bzw. epsilon für jeden Fold, jeweils separater Punktwert. Fassade mittelt Foldpunkte sowie untere/obere Endpunkte arithmetisch. `return_folds` erhält Originalwerte. | Nicht vorhanden; [Exports][r-exports]. | Regressionsfolds, foldweise Moderation und Mittelung fehlen. | Mittelwerte anhand offengelegter Foldresultate rekonstruieren. Unterschiedliche Foldgrößen bei epsilon berücksichtigen. Kein Schluss auf statistische Coverage des gemittelten Intervalls. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L740-L782), [Aggregation](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1549-L1575) |
| Regression Ensemble/Vollmodell | Öffentliche **untere Klasse** `VennAbersCV(setting='regression',cv_ensemble=...)` unterstützt beides; `.predict_interval` liefert zwei Listen je Fold. `VennAbersRegressor` besitzt dagegen keinen `cv_ensemble`-Konstruktorparameter und setzt unteren Standard True. `precision` wirkt im Regression-Kern nicht. | Keine Regression; binäres [Cross-predict][r-cross-predict] verlangt passende Fold-Modell-Spalten. | Welche Modellvariante für Regression übernommen wird, ist ein offener Verfahrens-/Integrationsvertrag. | Entscheiden, ob R den vollständigen unteren Funktionsumfang oder nur den Regressor-Fassadenumfang abdecken soll. Release-Test prüft tatsächlich unterschiedliche Foldpunkte beider Varianten. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/tests/test_venn_abers.py#L179-L202) |
| Angebliche manuelle Regression | Regressor-Docstring zählt einen manuellen Modus auf, aber `.fit` verlangt tatsächlich ein Estimatorobjekt und `.predict` die gefittete untere Klasse. Kein `p_cal/y_cal/p_test`-Pfad wie bei der Klassifikationsfassade. | Nicht vorhanden; [Exports][r-exports]. | Ein manueller R-Regressionsvertrag wäre eine eigene API-Entscheidung, keine direkte Wrapperkopie. | Manual-IVAR/CVAR wäre zusätzlicher API-Entwurf; nicht als bereits direkt unterstützten Python-Fassadenmodus ausgeben. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1412-L1575) |

## Optionen und tatsächliche Kombinationen

| Option | Wirksamer Bereich / genaue Semantik |
|---|---|
| `precision=None` | Klassifikationskernel und alle ihn aufrufenden manuellen/trainierten Wege. Rundet nur Kalibrierungsscores mit `np.round`; Test-Scores bleiben ungerundet. Im Regressionszweig ignoriert. [Quellcode](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L62-L69) |
| `loss='log'` / Brier | Unterer trainierter binärer IVAP/CVAP plus trainiertes Multiclass; auch F=1. Log `GM(p1)/(GM(1-p0)+GM(p1))`; Brier `mean(p1+0.5*p0²-0.5*p1²)`. Jeder andere String als `log` wird Brier. **Manuelle** Wege bleiben Log, selbst mit `loss='brier'`. [Quellcode](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L808-L837) |
| `p0_p1_output` | In der Fassade optional; raw `VennAbers` gibt immer beide Arrays zurück. Trainierter binärer Fassadenpfad gibt eine Liste mit einem Element zurück; direkter `VennAbersCV` gibt eine Matrix zurück. Spalten sind alle F p0-Werte, dann alle F p1-Werte; keine alternierende Anordnung. Multiclass-Diagnostik sind **binäre Paar-/OvR-Ergebnisse**, keine bewiesenen Multiclass-Konfidenzintervalle. |
| `cv_ensemble` | Auch bei **IVAP** wirksam: False verwendet Vollmodell für Test-Scores, obwohl Kalibrierungsscores weiterhin aus Proper-Train-Modell stammen. Bei CVAP analog. Keine Poolung der Kalibrierungsfolds zu einem einzigen Kalibrator. |
| `cal_size`, `train_proper_size` | Induktives `train_test_split`; float/int werden durch sklearn interpretiert. Fassade verlangt für ungefittetes Basismodell mindestens einen Wert. Vorab gefittetes Modell wird trotzdem geklont und neu trainiert; es ist kein Frozen-/Prefit-Modus. |
| `n_splits` | Tatsächlicher Konstruktorstandard `None`, nicht Docstring-5. Im induktiven unteren Fit wird er auf 1 gesetzt. Keine öffentliche Übergabe beliebiger Splitter-/Resampleobjekte; kein GroupKFold, RepeatedCV oder Zeitreihen-Split-Modus. |
| `shuffle`, `random_state` | Fassaden standardmäßig True; `VennAbersCV`/`VennAbersMultiClass` False. Untere CV-Klasse mit False plus nichtleerem random_state kann sklearn-Fehler auslösen. Für numerische Vergleiche gleiche Seeds allein nicht ausreichend: exakte Train-/Cal-Zeilen und Teilmodell-Scores fixieren. |
| `stratify` | Direkt binäres IVAP kann korrekt ausgerichteten Labelvektor nutzen. Multiclass-Fassade reicht den globalen Vektor unverändert an Paar-Teilmengen weiter: ausgeführter Fehler wegen ungleicher Länge. Regression-Fassade exponiert stratify nicht, CVAR nutzt KFold. |
| `m`, `epsilon` | Regressor-**Fit**-Keywords; unten Konstruktor `m_parameter`/`epsilon`. Falls epsilon truthy: `floor(epsilon*(k+1)/2)` je Kalibrierungsfold; sonst m. Epsilon 0 wird wie nicht gesetzt behandelt. Keine Domänenprüfung von m/epsilon. [Quellcode](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L706-L776) |
| `**kwargs` an `fit` | Untere Estimator-Fits bekommen übrige Keywords weitergereicht. Erste `OneVsOneClassifier.fit`-Phase bekommt sie **nicht**. Zeilenabhängige Vektoren wie sample_weight/eval_set werden nicht an Fold-/Paarindizes angepasst. Der Release-Test demonstriert nur unveränderte scalar/list-Weitergabe über ein permissives Dummy-Modell; kein allgemeiner Nachweis für gewichtetes Training oder externe Validation-Sets. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/tests/test_kwargs.py) |

Für die Optionszeilen ohne eigenen Inline-Link sind insbesondere die [unteren Konstruktor-/Fit-/Predict-Pfade](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L639-L887), die [Multiclass-Weitergabe](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L951-L1099) und die [Fassaden](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1210-L1575) maßgeblich. In R sind `precision`, Loss-Wahl, Modell-/Splitparameter und Regressionsparameter nicht verfügbar; IVAP-Endpunkte sind immer enthalten, Cross-Fold-Endpunkte nicht öffentlich. [R-Verträge][r-readme]

## Methodischer Regressionsbezug

Die passende Originalarbeit wurde gefunden: Petej/Vovk, *Inductive Venn–Abers and related regressors*, [arXiv:2605.06646v1](https://arxiv.org/html/2605.06646v1), 7. Mai 2026. Abschnitt 3.2 beschreibt dieselbe asymmetrische Moderation; zulässig ist `1 <= m <= floor((k-1)/2)`. Abschnitt 4 erklärt `epsilon=2m/(k+1)` und Abrunden auf erreichbare Werte. Python setzt die approximative gewichtete Formel 6 aus Abschnitt 6 um; die exakte Minimax-Formel 5 ist eine andere, nicht wählbare Variante. Abschnitt 7 bildet den Mittelwert der Fold-Punktwerte.

Die Intervalle dienen der Schätzung eines bedingten Erwartungswerts eines regularisierten Labels. Sie sind ausdrücklich keine gewöhnlichen Vorhersageintervalle für einzelne zukünftige Labels mit Coverage `1-epsilon`. Weder Umbenennung zu Konfidenzintervallen noch eine solche Coverage-Abnahme ist daraus gerechtfertigt. Die Arbeit formuliert das Selektor-/Autokalibrationsresultat für IVAR; die in Python zusätzlich gemittelten CVAR-Endpunkte brauchen eine eigene Interpretation.

## Dokumentation, Tests und Defekte auseinanderhalten

| Beobachtung | Evidenz / Einordnung | Geeignete spätere Abnahme |
|---|---|---|
| `predict(...,va_type='one_vs_rest')` liefert OvO-Klassen | Ausgeführt: synthetische 4-Klassen-Daten, 18 von 180 OvO/OvR-Argmax-Werten verschieden; `predict` stimmt komplett mit OvO überein. Methode liest Keyword nicht und reicht es nicht weiter. Auch das Notebook berechnet seine als OvR bezeichneten Klassen mit Standard-OvO. | Klassen aus tatsächlich zurückgegebenen Wahrscheinlichkeiten derselben Methode ableiten. |
| Manuelle Multiclass-Labels werden als Spaltenindizes verwendet | Ausgeführt: Strings -> IndexError; Labels 1..4 bei vier Spalten -> IndexError. Trainierter Pfad verwendet dagegen Paar-Boollabels und ursprüngliche Klassen für Ausgabe. | Klassen-/Spaltenmapping bei Faktoren, Strings, umgeordneten und fehlenden Klassen explizit testen; keine zufällige Python-Beschränkung übernehmen. |
| Paarspaltensumme 0 | Quellcode teilt unbewacht durch Paar-Summe. Ausgeführtes One-Hot-Beispiel lieferte trotzdem endliche Endergebnisse: NaN-Scores können durch `searchsorted` in Extrempositionen einsortiert werden. Endliche Ausgabe ist deshalb keine fachliche Definition dieses Falls. | Definierte Policy verlangen; nicht nur `isfinite` prüfen. |
| Direktes Multiclass-Objekt wiederholt fitten | Ausgeführt: bei vier Klassen wachsen Paar- und Kalibratorlisten von 6 auf 12; Vorhersagen ändern sich bei identischen Daten/Seed. Konstruktor initialisiert Listen, Fit leert sie nicht. Fassade erstellt bei jedem Fit neues Multiclass-Objekt und umgeht diesen Defekt. | Erneuter Fit desselben öffentlichen Objekts entspricht frischem Fit. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L971-L1037) |
| Konstante Regressionslabels | Ausgeführt innerhalb m=1-Domäne: Intervall endlich, Punktwert NaN durch Nullnenner im Merger. Numerischer Defekt im degenerierten zulässigen Fall, keine gewünschte Funktion. | Konstanten und zusammengefallene Grenzen liefern endlichen, im Intervall liegenden Punkt. |
| Sehr kleines epsilon | Ausgeführt epsilon=.0001 bei k=36: m=0 -> IndexError. Dieses epsilon liegt außerhalb der ursprünglichen zulässigen Domäne; Nachweis fehlender Eingabevalidierung, nicht einer Widerlegung des IVAR-Verfahrens. | Frühzeitige Fehlermeldung oder bewusst dokumentierte Grenzbehandlung. Auch m=0, negative/größere m, k<3 prüfen. |
| Regression mit nur einer Testzeile | Ausgeführt: Punktform `()` statt `(1,)` wegen `np.squeeze`; Intervall bleibt `(1,2)`. | Stabile Form für n=0,1,>1; Python-Squeeze nicht als notwendige Parität übernehmen. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1554-L1575) |
| Regressor behauptet kategorische Eingaben | Ausgeführt String-DataFrame: `could not convert string to float`; Regressor ruft keine Kategoriekodierung auf. Numeric-DataFrames sind ebenfalls kein umfassend validierter Pfad: untere Klasse nutzt NumPy-artige Zeilenindexierung. | Dokumentierte Eingabetypen tatsächlich unterstützen oder klar validieren; ökosystemspezifisch entscheiden. |
| „Full scikit-learn compatibility“ | README-Behauptung ist breiter als Evidenz. Release-`test_estimator_checks` ruft check_estimator nicht auf, prüft nur clone. Ausgeführt: standardmäßige `.score` und `cross_val_score(error_score='raise')` scheitern am One-Hot/Label-Mismatch; Regression-`predict` liefert Tuple statt Standardvektor. Pipeline fit/predict_proba kann dennoch funktionieren. | Native Pipeline/Resampling/Scoring explizit testen, nicht Python-Vererbungsstruktur imitieren. [Test](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/tests/test_estimator_checks.py#L7-L18) |
| Unterer `VennAbersCV.fit` gibt None zurück | Quellcode endet ohne `return self`; trotz BaseEstimator kein kettenfähiges fit. CV/MultiClass definieren auch keine eigene `predict`-Methode. | Native sinnvolle Rückgaben statt diesem API-Defekt folgen. |
| NumPy globale Fehlerbehandlung | Import setzt divide/invalid auf ignore; kann Fehler außerhalb des Pakets verbergen. | Keine globale Nebenwirkung als Paritätsanforderung. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L11) |
| Log-CV numerisch instabil | `geo_mean` bildet erst Produkt, dann F-te Wurzel, ohne Lograum. Vorhandene R-Referenzforschung behandelt Unterlauf separat. | Stabile Formel/Referenz-Defektprotokoll getrennt von toleranzbasierter Python-Gleichheit. [Quelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L281-L294) |

Die Release-Tests prüfen überwiegend Shapes/Zeilensummen sowie Regression-Endpunktordnung. Daneben bestehen ein binärer numerischer Baseline-Test, ein Regressions-Integritätstest, Modellclone-Identität, Unterschied Ensemble/Vollmodell und epsilon-Effekt sowie obere Extrapolation. Sie beweisen weder vollständige Optionskombinationen noch statistische Garantien. [Gesamte Tests](https://github.com/ip200/venn-abers/tree/0e7b4bc575ce230134576ba1c76688d46bf99ac7/tests)

Die vier Änderungen des Release-Fixcommits — unabhängige Foldklone, Beachtung cv_ensemble bei Regression, epsilon im Cross-Pfad und äußerer oberer Grenzwert — sind in 1.5.4 bereits enthalten und dürfen nicht als noch fehlende 1.5.4-Funktionen behandelt werden. [Fixcommit](https://github.com/ip200/venn-abers/commit/f3f63e7)

## R-Ausgangsstand und belastbare vorhandene Abnahme

Untersucht wurde R `vennabers` **0.2.0**, Commit `cd59c414fc27e8ca577bf4474f7e494ef079068f`. Der Branch heißt bereits `v0.3`; maßgeblich für den Iststand sind jedoch DESCRIPTION und dieser Commit. Die fünf Exporte sind `venn_abers`, `cross_venn_abers`, `brier_score`, `log_loss`, `calibration_plot`; zusätzlich existieren S3-Methoden für `predict` und `print`. Keine Modelltrainings-, Multiclass-, Regressions- oder tidymodels-Schnittstelle ist exportiert. [Paketmetadaten][r-description], [Exports][r-exports]

| R-Fähigkeit | Tatsächlicher Vertrag und Grenze | Evidenz |
| --- | --- | --- |
| Binärer Inductive-Kern | `venn_abers(truth, probability)`: nichtleere, positionsgleiche Vektoren; Truth logisch oder numerisch 0/1, Event TRUE/1. Endliche Wahrscheinlichkeiten in [0,1]. Exakte Bindungen werden zusammengefasst. Kein Runden, keine Gewichte, keine Loss-Option. | [Fit und Validierung][r-core] |
| Inductive-Vorhersage | Numerischer Vektor; Ausgabe Dataframe mit genau `lower`, `upper`, `probability`, alle double. Punkt = `upper/(1-lower+upper)`. Ein-Klassen-Kalibrierung und Singleton erlaubt; leere Vorhersage behält das Schema. Nichtleeres `...` wird abgewiesen. | [Vorhersage][r-predict], [Vertragstests][r-tests] |
| Binärer Cross-Kern | Eine Partition mit mindestens zwei nichtleeren Folds; je Fold ein bestehender IVAP. Aufrufer liefert OOF-Wahrscheinlichkeiten und Truth; Fold-IDs sind Zeichenketten oder positive ganze Zahlen. Ungleiche, Singleton- und Ein-Klassen-Folds sind erlaubt. | [Cross-Kern][r-cross] |
| Cross-Vorhersage | Benannte numerische Matrix: gleiche neue Zeilen in allen Spalten, je Spalte das zum Fold passende Modell. Spaltennamen müssen vollständig und eindeutig passen; Umordnung wird aufgelöst. Ausgabe genau eine double-Spalte `probability`. Kein öffentliches Fold-Diagnostik- oder aggregiertes Intervall. | [Cross-Vorhersage][r-cross-predict], [Cross-Vertragstests][r-cross-tests] |
| Cross-Aggregation | Gleichgewichtete Log-Loss-Aggregation über Fold-Endpunkte, stabil im Log-Raum: `plogis(rowMeans(log(upper))-rowMeans(log1p(-lower)))`. Keine Mittelung der Fold-Punktwerte oder Gewichtung nach Fold-Größe. | [Merger][r-merger], [numerische Provenienz][r-provenance] |
| Scores und Plot | Binärer Brier Score, unclipped Log Loss (falsch sichere Vorhersage ergibt Inf), Base-R-Reliability-Plot mit gleichen Intervallbreiten und unsichtbar zurückgegebenen Gruppenstatistiken. Das Vorhandensein des **Brier Scores** bedeutet keine Brier-Regularisierung des Kalibrators. | [Verbraucher][r-consumers], [Vertragstests][r-tests] |
| Vollständiger Ablauf als Beispiel | Drei GLMs, Aufteilung, OOF-Zuordnung und Vorhersagen der behaltenen Fold-Modelle im ausführbaren Beispiel; Training und Resampling sind Code des Aufrufers, keine Paketfunktion. Gelerntes Preprocessing/Tuning muss vollständig außerhalb des gehaltenen Folds bleiben. | [Kanonisches Beispiel][r-example], [README][r-readme] |

Python exportiert keine eigenständigen Brier-/Log-Loss- oder Reliability-Plot-Funktionen; solche Notebook-Auswertungen sind keine zusätzlichen Paketexporte. Die vorhandenen R-Verbraucher sind eigene Fähigkeiten, deren Multiclass-/Regressionsausbau separat entschieden werden muss. [Python-Exports](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/__init__.py), [R-Exports][r-exports]

Der Python-Kern validiert die binären Wahrscheinlichkeitsmatrizen nicht systematisch; er liest die zweite Spalte und lässt etliche Fehlrepräsentationen bis zu NumPy durch. R prüft dagegen am Eingang und verwirft weder Zeilen noch clippt oder rundet es Werte. Dieses strengere Verhalten ist von numerischer Parität auf gültigen Eingaben zu unterscheiden. Kalibrierungsgewichte, Online-Updates und ein allgemeiner Gruppen-/Zeitreihen-Resampler sind durch die untersuchten öffentlichen Signaturen nicht belegt. [Python-Kern](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L14-L278), [R-Validierung][r-core]

### Was die gespeicherten Vergleichsfixtures tatsächlich abdecken

- **IVAP:** neun deterministische Fälle mit zusammen 33 Vorhersagezeilen; dazu 100 gespeicherte randomisierte Fälle mit je 25 Vorhersagen, Kalibrierungsgrößen 1–200, Bindungen, ein-/zweiklassiger Truth, Endpunkten und beiden äußeren Bereichen. Numerischer Vergleich für `lower`, `upper` und `probability`, maximaler absoluter Fehler `<= 1e-10`, ohne relativen Anteil. Schema, Wertebereich und Reihenfolge werden separat geprüft. [Deterministische Tests][r-tests], [randomisierte Tests][r-random-tests]
- **Cross:** fünf deterministische und 100 randomisierte Fälle, 2–10 Folds, Fold-Größen über alle Werte 1–200, 25 neue Zeilen je randomisiertem Fall. Vergleich derselben Fold-IVAP-Endpunkte und des gemeinsamen Punktwerts; ebenfalls `<= 1e-10`. Namenszuordnung und Zeilenreihenfolge werden geprüft. Der ungleiche Fall unterscheidet die Referenz von Mittelung der Punkte, Größenwichtung und Pooling. [Cross-Vergleich][r-cross-parity]
- **Referenzweg:** Python `VennAbersCV.predict_proba`, `setting='classification'`, `precision=None`, `loss='log'`, `cv_ensemble=True`. Der Generator injiziert feste Kalibrierungsarrays und Tabellenprädiktoren in den gepinnten Python-Zustand. Damit wird dessen Aggregationscode ausgeführt, aber **kein Training und keine Split-Erzeugung** geprüft. Das ist kein öffentliches Python-API-Vorbild. [Generator][r-generator], [Provenienz und Hashes][r-provenance]
- **Stabilität separat:** Identische Fold-Paare `(0.9,0.91)` bei 1024 Folds, `(0.4,0.7)` bei 4096 und `(0.1,0.2)` bei 2048 haben die exakten Punkte `91/101`, `7/13`, `2/11`. Der Python-Produktmerger liefert 1, 0.5 beziehungsweise 0. R prüft die eigene Produktionsfunktion gegen die Algebra, nicht gegen diese fehlerhaften Python-Werte. [Stabilitätstests][r-cross-tests], [Referenzbefunde][r-provenance]
- **Keine Evidenz durch Extrapolation:** Diese Fixtures belegen weder Multiclass-Kopplung noch Brier-Merging, Regression, Rundungsoptionen, Modellklonen, Klassennamen, Trainingsparameter oder Resampling. Dafür müssen die jeweiligen Entscheidungen eigene gezielte Abnahmedaten benennen. [Ausgeführte Testpfade][r-tests], [Cross-Vergleich][r-cross-parity]

### In dieser Recherche erneut ausgeführt

`/opt/homebrew/opt/r/bin/Rscript tools/acceptance.R` lief am 2026-09-06 gegen den obigen unveränderten Quellstand unter R 4.6.1 auf macOS arm64 erfolgreich: `R CMD check --no-manual` mit Status OK, alle vier Testskripte, Installation des gebauten Artefakts, beide README-Beispiele, kanonischer Drei-Fold-GLM-Ablauf und IVAP-Performance-Gate. Der Median für Fit/Predict mit je 100.000 Beobachtungen betrug 0,433 Sekunden. Der Start über unqualifiziertes `Rscript` scheiterte zunächst am PATH; der Lauf mit dem installierten absoluten Pfad bestand. [Abnahmeskript][r-acceptance]

Der erneute Lauf ist **kein** neuer R-4.1-, Netzwerk-Sandbox-, CI- oder CRAN-Nachweis. Die schon vorhandene dokumentierte Doppelversionsabnahme bleibt als historische Evidenz verlinkt. Produktionscode und Tests wurden für diese Recherche nicht geändert. [Vorhandene v0.2-Abnahme][r-gate-record]

[r-description]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/DESCRIPTION
[r-exports]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/NAMESPACE
[r-core]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/venn_abers.R#L1-L132
[r-predict]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/venn_abers.R#L134-L149
[r-cross]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/cross_venn_abers.R#L1-L30
[r-cross-predict]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/cross_venn_abers.R#L36-L55
[r-merger]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/cross_venn_abers.R#L32-L34
[r-consumers]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/R/venn_abers.R#L64-L106
[r-tests]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tests/venn-abers.R
[r-cross-tests]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tests/cross-venn-abers.R
[r-random-tests]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tests/randomized-parity.R
[r-cross-parity]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tests/cross-parity.R
[r-generator]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tools/generate-cross-fixtures.py
[r-provenance]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/inst/extdata/cross-reference.md
[r-acceptance]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tools/acceptance.R
[r-gate-record]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/tools/acceptance-v02.md
[r-example]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/examples/cross-venn-abers.R
[r-readme]: https://github.com/RMKruse/venn-abers/blob/cd59c414fc27e8ca577bf4474f7e494ef079068f/README.md

## Offene Entscheidungen und nächste Zuständigkeiten

Diese Recherche legt weder Releases noch gewünschte API-Erweiterungen fest. Die folgenden Fragen sind jetzt konkret genug und gehören auf die vorhandene beziehungsweise ergänzte Entscheidungsfrontier:

- [Multiclass-Umfang und Abnahme für v0.3 festlegen](https://github.com/RMKruse/venn-abers/issues/4): manuelles OvO/OvR gegenüber trainiertem OvO, Klassenordnung, fehlende Klassen und paarweise Nullsummen, Kopplung, Endpunktausgabe, Klassenentscheidung und Auswirkung auf Scores/Plots. Eine trainierte OvR-Variante wäre eine bewusste Erweiterung über die nachgewiesene Referenz hinaus.
- [Regressionsumfang und Abnahme für v0.4 festlegen](https://github.com/RMKruse/venn-abers/issues/5): moderierte IVAR/CVAR-Verfahren, Bedeutung von `m`/`epsilon`, zulässige Fold-Größen, Punktmerger, Intervallsemantik, Konstantfälle und konsistente Ausgabeformen. Manuelle Regression nicht allein aufgrund des Wrapper-Docstrings als Python-Parität einplanen; sie kann als eigenständiger R-Vertrag bewusst gewählt werden.
- [Zusätzliche binäre Kalibrierungsoptionen und Paritätsgrenzen festlegen](https://github.com/RMKruse/venn-abers/issues/8): Brier-Merging, optionale Rundung, Fold-Endpunkte und Klassenentscheidung gegenüber dem festen v0.2-Kern. Die erste Fog-Notiz der Map wird damit in eine konkrete Frage überführt; über Aufnahme oder Ausschluss entscheidet erst das HITL-Gespräch.
- [Vollständige tidymodels-Abläufe für v1.0 abgrenzen](https://github.com/RMKruse/venn-abers/issues/6): richtige Trainings-/Kalibrierungsgrenzen einschließlich Preprocessing und Tuning, Prefit-Verantwortung, Ensemble versus All-data-Refit, Resampling, Fold-Modell-Aufbewahrung und klassensichere Ausgabe-/Scoring-Integration. Gegen fest vorgegebene Splits und Basismodell-Ausgaben testen; gleiche Zufallsseeds in unterschiedlichen Ökosystemen bedeuten nicht dieselben Splits oder Fits.
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen](https://github.com/RMKruse/venn-abers/issues/7): jeder Matrixzeile eine bewusste Zusage oder begründete Ausnahme zuordnen, einschließlich Fehlerkorrekturen gegenüber Python und zusätzlicher R-Verbraucher; gewöhnliche numerische Referenzfälle, algebraische Sonderfälle und Integrationsprüfungen getrennt abnehmen. Für Regression wird die tolerierbare Abweichung in den Einheiten der Zielgröße festgelegt; die binäre absolute Wahrscheinlichkeitstoleranz ist keine ungeprüfte Vorgabe für beliebige Zielskalen.


## Reproduzierbarer Zusatzcheck

Die folgende Datei `python_capability_probe.py` benötigt `venn-abers==1.5.4`, numpy, pandas und scikit-learn in einer isolierten Umgebung. Sie überprüft Fähigkeitskombinationen und ausgewählte **beobachtete Referenzdefekte**, nicht gewünschtes Verhalten der R-Portierung. Die vollständige Recherche führte darüber hinaus die oben beschriebenen Varianten/Fehlerprobes aus. Der Check ist absichtlich gegen 1.5.4 gepinnt; bei gefixter Referenz können Defektassertionen fehlschlagen.

```python
import hashlib
import inspect
from pathlib import Path
import numpy as np
from sklearn.datasets import make_classification, make_regression
from sklearn.naive_bayes import GaussianNB
from sklearn.linear_model import LinearRegression
from venn_abers import VennAbers, VennAbersCalibrator, VennAbersRegressor

source = Path(inspect.getfile(VennAbers))
assert hashlib.sha256(source.read_bytes()).hexdigest() == (
    'ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5')
X, y = make_classification(n_samples=180, n_classes=4,
                           n_informative=6, random_state=42)
clf = GaussianNB().fit(X[:100], y[:100])
pc, pt = clf.predict_proba(X[100:]), clf.predict_proba(X)
manual = {}
for typ, count in [('one_vs_one', 6), ('one_vs_rest', 4)]:
    va = VennAbersCalibrator()
    p, d = va.predict_proba(p_cal=pc, y_cal=y[100:], p_test=pt,
                            va_type=typ, p0_p1_output=True)
    assert p.shape == (180, 4) and len(d) == count
    assert all(a.shape == (180, 2) for a in d)
    assert np.allclose(p.sum(axis=1), 1)
    manual[typ] = p
assert np.any(manual['one_vs_one'].argmax(1) != manual['one_vs_rest'].argmax(1))
labels = va.predict(p_cal=pc, y_cal=y[100:], p_test=pt,
                    va_type='one_vs_rest', one_hot=False)
assert np.array_equal(labels, manual['one_vs_one'].argmax(1))  # reference defect

for inductive in [True, False]:
    for ensemble in [True, False]:
        va = VennAbersCalibrator(GaussianNB(), inductive=inductive,
             cal_size=.3, n_splits=3, random_state=42, cv_ensemble=ensemble)
        va.fit(X, y)
        p, d = va.predict_proba(X[:9], loss='brier', p0_p1_output=True)
        assert p.shape == (9, 4) and len(d) == 6
        assert all(a.shape == (9, 2 if inductive else 6) for a in d)
        assert np.allclose(p.sum(axis=1), 1)
        assert np.allclose(va.predict_proba(X[:9], va_type='one_vs_rest'),
                           va.predict_proba(X[:9]))  # trained path is only OvO

Xr, yr = make_regression(n_samples=120, n_features=3, noise=5, random_state=42)
for inductive in [True, False]:
    vr = VennAbersRegressor(LinearRegression(), inductive=inductive,
                            cal_size=.3, n_splits=3, random_state=42)
    vr.fit(Xr, yr, m=1)
    point, interval, folds = vr.predict(Xr[:9], return_folds=True)
    assert point.shape == (9,) and interval.shape == (9, 2)
    assert len(folds['mid']) == (1 if inductive else 3)
    assert np.allclose(point, np.mean(folds['mid'], axis=0))
    assert np.allclose(interval, np.mean(folds['range'], axis=0))
    assert np.shape(vr.predict(Xr[:1])[0]) == ()  # reference shape defect
vr = VennAbersRegressor(LinearRegression(), cal_size=.3, random_state=42)
vr.fit(Xr, np.ones(len(Xr)))
point, interval = vr.predict(Xr[:9])
assert not np.isfinite(point).all() and np.isfinite(interval).all()
raw = VennAbers(setting='regression').fit(np.array([1., 2., 3.]),
                                         np.array([10., 20., 15.]))
unused, bounds = raw.predict_proba(np.array([0., 2., 4.]))
assert np.all(unused == 0) and bounds[-1, 1] == 20
print('Python 1.5.4 capability and observed-defect checks passed')
```
