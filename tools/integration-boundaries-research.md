# Integrationsgrenzen und vollständige Python-Parität

Recherche vom 2026-09-07 für [Vorläufige Integrationsgrenzen gegen die vollständige Python-Parität prüfen](https://github.com/RMKruse/venn-abers/issues/16), Teil von [Wayfinder: Release-Roadmap bis v1.0 mit Python-Parität und tidymodels](https://github.com/RMKruse/venn-abers/issues/2).

**Ergebnis:** Die drei vorläufigen Grenzen sind nicht gleich einzuordnen. Die trainierte Python-Referenz verarbeitet die untersuchten besonderen Klassennamen; ein pauschaler Ausschluss bis v1.0 würde diesen Fähigkeitsumfang beschneiden. Zusätzlich gelerntes Postprocessing ist mit konkreten zusammengesetzten Basisschätzern tatsächlich lauffähig und verlangt einen erweiterten R-Datenvertrag. Dagegen bietet die Python-Referenz keine allgemeine native Übergabe beliebiger, pro äußerem Vorkommen vorbereiteter VA-Pläne. Explizite externe Orchestrierung ist in beiden Ökosystemen möglich. Aus ihr folgt nicht automatisch die Pflicht zu einer neuen vorkommensbewussten nativen Produkt-API.

Die [vorläufigen Anfangsgrenzen](https://github.com/RMKruse/venn-abers/issues/15#issuecomment-5570134201) gelten bis zu einer folgenden menschlichen Entscheidung weiter. Dieses AFK-Research entscheidet weder das künftige sichtbare Namensschema noch neue Split-Defaults, unterstützte Postprocessor-Verfahren oder Release-Zuordnungen. Die bereits beschlossene [eingefrorene Workflow-Übernahme einschließlich Postprocessing](https://github.com/RMKruse/venn-abers/issues/12#issuecomment-5569800958) und der eigene [Vollmodell-/Paarvertrag](https://github.com/RMKruse/venn-abers/issues/11#issuecomment-5569044325) bleiben bestehen.

## Evidenzmatrix und Folgerung

| Sonderfall | Ausgeführte Python-Evidenz | Ausgeführte R-Evidenz | Bedeutung / nötige Folge |
|---|---|---|---|
| `class`, `.pred_…`, Leerzeichen, nichtsyntaktische und `make.names()`-kollidierende Klassen | Trainierte Inductive/Cross- und passende/Vollmodell-Wege bewahren die ursprüngliche Identität in sortierter Python-Klassenordnung; manuelle Arrays brauchen explizite numerische Klassenzuordnung | Rohe Problemnamen scheitern teils erst bei äußerer Vorhersage/Metrik; reversible Kodierung vor dem nativen Daten-/Resampling-Eingang trägt Fit, Predict, wiederholtes äußeres Resampling, Metriken, gespeicherte Ergebnisse und Diagnostik | Algorithmische Namenfähigkeit bis v1.0 erhalten; das native Ausgabeschema und den ausdrücklichen Kodierungszugang mit dem Menschen festlegen. Keine pauschale syntaktische R-Namenspflicht ableiten. |
| Kollidierende R-Ziel-/Verwaltungsspalten | Kein gleichartiger tidymodels-Tabellennamensraum in Python-Arrays | Rohe Ziele können kollidieren, repariert oder überschrieben werden; durchgängige Daten-/Zielkodierung behebt die geprüften Fälle | R-spezifischer Schema-/Identitätsvertrag, keine Python-Tabellenparität. Wahrheit und Wahrscheinlichkeit dürfen beim Dekodieren nicht wieder kollidieren. |
| Beliebige feste innere VA-Pläne je äußerem Vorkommen bei gleichen Daten | Keine allgemeine native `cv`-/Splitlisten-Übergabe; sklearn-`PredefinedSplit` trägt explizite externe Modell-/VA-Orchestrierung. Eingeschränkte geordnete Holdouts lassen sich über native Größenoptionen ausdrücken | Jobgebundener Kontext plus separater nativer äußerer Fit pro Vorkommen besteht Wiederholung, Reihenfolgewechsel, RDS und zwei frische PSOCK-Worker | Die native Grenze ist keine belegte Lücke gegenüber einer gleichartigen Python-API. Ein zusätzlicher komfortabler R-Dispatcher wäre eine ausdrückliche Erweiterung; manuelle Orchestrierbarkeit und Paketautomatik getrennt dokumentieren. |
| Neu gelerntes Klassifikations-Postprocessing | `CalibratedClassifierCV` als Basisschätzer besteht binäre und paarweise Multiclass-Inductive/Cross-Wege, jeweils passend/Vollmodell; getrennte Lern-/VA-/Bewertungsrollen instrumentiert | Öffentliche `fit(..., data_calibration=...)`-Schnittstelle mit Tailor trägt getrenntes Lernen innerhalb jedes erlaubten Quellmodellbereichs | Der dauerhafte pauschale Ausschluss würde nachgewiesene Kompositionsfähigkeit beschneiden. Konkrete Postprocessor-Verfahren, Zuständigkeit für zusätzliche Splits und vollständigen gespeicherten Pfad entscheiden. Einzelner R-Holdout ist kein Beleg für Gleichheit mit einem sklearn-Kalibrierungsensemble. |
| Numerisches zusätzliches Lernen | Geeigneter numerischer Ridge-/Isotonic-Verbund unter Regression sowie gesonderte Stacking-Aufrufe | Numerische lineare Tailor-Kalibrierung nach `lm`, getrennt vom Modelllernen | Keine Klassifikationsprobe als Regressionsnachweis; nur die konkret ausgeführten Kompositionen beanspruchen. |
| Bereits eingefrorenes Postprocessing / problematische Altmodelle | Manuelle finale Wahrscheinlichkeiten bleiben möglich; keine neu behauptete native Frozen-Wrapper-Übernahme | Vollständige gespeicherte Tailor-Pfade bleiben unverändert vorhersagefähig. Ein spezieller roher GLM-Workflow-Pfad hilft bei reservierter Klasse nur ohne Tailor | Eingefrorene Unterstützung bleibt beschlossen. Allgemeine Namensreparatur eines beliebigen bereits gefitteten Workflows ist dadurch nicht bewiesen; kein Refit und kein Umgehen seines Postprocessors. |

Die nachfolgenden Detailabschnitte unterscheiden erfolgreiche Aufrufe, instrumentierte Datenrollen und offene Kombinationen. Die R-Proben implementieren **keine Venn-Abers-Produktfeatures**; sie belegen öffentliche Integrationsstellen. Die Python-Probe führt den unveränderten Referenzalgorithmus aus. Weder gleiche Seeds noch passende Tabellenformen beweisen numerische Verfahrensparität oder statistische Garantien.

## Reproduktion und Artefakte

Alle Pfade in diesem Bericht beziehen sich auf denselben versionierten Artefaktstand. Die ausführbaren Assertions und ihre erfassten Ausgaben sind:

- [Python-Probe](integration-boundaries-python.py) und [Ausgabe](integration-boundaries-python-output.txt).
- [R-Namensprobe](integration-boundaries-names.R) und [Ausgabe](integration-boundaries-names-output.txt).
- [R-Vorkommens-/Planprobe](integration-boundaries-plans.R) und [Ausgabe](integration-boundaries-plans-output.txt).
- [R-Postprocessing-Probe](integration-boundaries-postprocessing.R) und [Ausgabe](integration-boundaries-postprocessing.txt).

Ausführen aus dem Repository mit den unten dokumentierten Paketversionen:

```sh
python tools/integration-boundaries-python.py
Rscript tools/integration-boundaries-names.R
Rscript tools/integration-boundaries-plans.R
Rscript tools/integration-boundaries-postprocessing.R
```

Optional nimmt die Python-Probe als erstes Argument das `src`-Verzeichnis des Referenzcheckouts entgegen. Ihr Provenienzcheck braucht Netz für PyPI/GitHub und ein angemeldetes `gh` mit Lesezugriff auf das private frühere Rechercheasset. R kann über `VENN_RESEARCH_LIB` eine separate Bibliothek verwenden. Im dokumentierten Lauf waren das `/tmp/venn-abers-probe-env/bin/python`, `/opt/homebrew/opt/r/bin/Rscript` und `/tmp/venn-tidymodels-lib`. Es wurden keine Abhängigkeiten des Produktpackages verändert. Frische R-Unterprozesse/Worker benötigen dieselben installierten Pakete; die Forschungsregistrierung wird ausdrücklich geladen.

Erneute Fehler bei inzwischen verändertem Verhalten sind keine Aufforderung, die Assertions zu lockern: Quellen-/Versionsunterschiede zuerst untersuchen. Die bewusst geprüften Referenzfehler sind keine gewünschte R-Semantik.


## Python-Evidenz zu den drei Integrationsgrenzen

Ausgeführt am 2026-09-07: Python 3.14.6, NumPy 2.5.3, pandas 3.0.5, scikit-learn 1.9.0. Referenz ist `venn-abers` 1.5.4, Git-Commit `0e7b4bc575ce230134576ba1c76688d46bf99ac7`. Die Probe lädt die PyPI-Sdist erneut, prüft deren SHA-256 `a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69` und die Bytegleichheit von ausgeführtem Modul, Sdist und Git-Quelle; Modul-SHA-256: `ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`. Beide Hashes wurden außerdem gegen das veröffentlichte Asset von [Python-Funktionsumfang und Paritätslücken erfassen](https://github.com/RMKruse/venn-abers/blob/d7b87f1b093e6d1cd9b96a0116ced8ee19b973b2/tools/python-parity-research.md) geprüft. [PyPI-Metadaten](https://pypi.org/pypi/venn-abers/1.5.4/json), [Referenzquelle](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py).

Der ausführbare Nachweis ist `tools/integration-boundaries-python.py`. Die folgenden Aussagen über unterstützte Kombinationen stammen aus seinen tatsächlich ausgeführten Assertions; Quellverweise erklären den beobachteten Weg. Keine pauschale Zusage für beliebige sklearn-Schätzer.

### Klassenidentität ist von Tabellennamen zu trennen

| Ausgeführter Fall | Ergebnis und Datenvertrag | Konsequenz für R-Parität |
|---|---|---|
| `VennAbersCalibrator(LogisticRegression(), ...)`, Klassen `('class','other')`, `('.pred_class','.pred_yes')`, `('a b','a-b')`, `('1yes','a/b')`, `('a b','a.b','a-b')`; jeweils IVAP/CVAP × Ensemble/Vollmodell | Alle 20 Fälle bestanden. `classes_` enthält die unveränderten Strings in `np.unique`-Sortierung; jede Wahrscheinlichkeitsspalte entspricht dieser Position. Wahrscheinlichkeiten sind gleich dem passenden ganzzahlig kodierten Kontrollfit. `predict(one_hot=False)` dekodiert korrekt; Standard-`predict` liefert One-Hot. | Ein dauerhafter Ausschluss dieser Klassen wäre eine algorithmische Paritätslücke. Python erzeugt keine `.pred_*`-Tabellenspalten; aus diesem Erfolg folgt keine Aussage über tune-Tabellen. |
| Manueller binärer Wrapper mit unveränderten Stringlabels | Vier Negativproben scheitern mit `TypeError` im numerischen Kern. Der Wrapper kodiert die Labels hier nicht. | Keine Forderung, diesen Defekt zu übernehmen. R braucht ein explizites Klassenwörterbuch. |
| Manueller Multiclass-Wrapper, dieselben drei kollidierenden Namen, OvO und OvR | Beide direkten Aufrufe scheitern mit `IndexError`: Klassenwerte werden als Array-Spaltenindices verwendet. | Numerische Positionen und originale Identität müssen getrennt sein. |
| Manuell nach Kodierung `0..K-1`, passend ausgerichteten Score-Spalten, anschließender Dekodierung | Alle genannten Fälle bestanden. Gemeinsame Permutation von Spalten, Codes und Wörterbuch ergibt nach Rückordnung dieselben Wahrscheinlichkeiten. | Reversibles Mapping reicht algorithmisch; derselbe Vertrag muss native, manuelle und eingefrorene Zugänge verbinden. Ob native Resamples/Metriken/Diagnostik funktionieren, benötigt eigene R-Gegenproben. |

Die trainierte OvO-Schicht kodiert pro Paar auf boolesche Labels; das manuelle Multiclass verwendet dagegen Originalwerte als Spaltenindices. Die Probe dekodiert manuelle OvR-Entscheidungen aus `predict_proba(..., va_type='one_vs_rest').argmax(...)`: Der bekannte 1.5.4-Wrapperfehler, dass `predict()` `va_type` nicht weiterreicht, ist kein gewünschter Namensvertrag. [Trainierter Fit](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L986-L1037), [manuelle Pfade](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L357-L459), [Wrapper-Vorhersage](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1280-L1409).

### Vorab zugeordnete Pläne: drei verschiedene Fähigkeiten

| Ebene | Positiv-/Negativnachweis | Bedeutung |
|---|---|---|
| Native VA-Parameter | Auf exakt denselben 180 Zeilen: zwei vorab benannte IVAP-Konfigurationen mit `shuffle=False`, `cal_size=36` beziehungsweise `54` trainieren nachweislich auf dem jeweiligen Präfix und kalibrieren auf dem Suffix. Kein zufälliger Unterschied. | Bestimmte vorgegebene Pläne sind bereits durch öffentliche Parameter ausdrückbar. „Python kann keine unterschiedlichen vorgegebenen Pläne“ wäre falsch. |
| Native freie Split-Liste | `cv=PredefinedSplit(...)` im Konstruktor: `TypeError`; als `n_splits`: `ValueError`; als Fit-Argument: an den Basisschätzer weitergereicht und dort `TypeError`. Die Quelle konstruiert intern `train_test_split` beziehungsweise `StratifiedKFold`/`KFold`. | Kein belegter öffentlicher Vertrag für beliebige occurrence-gebundene VA-Splitlisten. Ein neuer automatischer Dispatcher ist keine durch Python erzwungene Paritätsforderung. |
| sklearn-Komposition | `CalibratedClassifierCV(..., cv=PredefinedSplit(plan), ensemble=True)` respektiert beide vorgegebenen Pläne. Die instrumentierten Postprocessor-Zeilen stimmen exakt. Derselbe globale Positionsplan innerhalb des schrumpfenden VA-Fits scheitert mit `IndexError`. | CCC steuert seine zusätzliche Modell-/Postprocessor-Aufteilung, nicht die umgebende VA-Aufteilung. Positionsindices beziehen sich auf die jeweilige lokale Fit-Domäne. |
| sklearn plus manuelle VA-Orchestrierung | `cross_validate(..., cv=PredefinedSplit(plan), return_estimator=True, return_indices=True)` → je Fold `VennAbers.fit(p_cal,y_cal)` → Vorhersage → expliziter NumPy-Log-Merger. Zwei gleich große, vorab gebaute Drei-Fold-Pläne auf bytegleichen lokalen Daten erzeugen nachweislich andere Mitgliedschaften. | Freie Pläne sind als externe Orchestrierung ausführbar; das ist keine native `VennAbersCalibrator.fit`-Fähigkeit. |

Die beiden freien Pläne verwenden fest `(row_id//2)%3` bzw. `(row_id//4)%3`, jeweils 60 Kalibrierungszeilen pro Fold. Ein serialisiertes Bundle trägt **Vorkommens-ID, Daten und Plan zusammen**. Wiederholung, umgekehrte Aufrufreihenfolge und zwei gleichzeitige Thread-Worker reproduzieren Mitgliedschaften und Wahrscheinlichkeiten pro ID. Weder globale Aufrufzähler noch Dateninhalt oder Zeilenzahl wählen einen Plan aus. Das ist kein Python-Prozessparallelitätsnachweis; die R-Gegenprobe muss ihre eigene Parallelisierungsform prüfen. [Native Splitbildung](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L669-L782), [PredefinedSplit](https://scikit-learn.org/1.9/modules/generated/sklearn.model_selection.PredefinedSplit.html), [cross_validate](https://scikit-learn.org/1.9/modules/generated/sklearn.model_selection.cross_validate.html).

Technische Folgerung: Eine überprüfte R-Orchestrierung mit expliziter Vorkommensidentität kann diese Fähigkeit abdecken. Ein komfortabler einzelner nativer Aufruf, der selbst alle Vorkommen unterscheidet, wäre eine zusätzliche Produktentscheidung; dieser Python-Nachweis verlangt sie nicht.

### Zusätzlich gelerntes Postprocessing funktioniert in konkreten Verschachtelungen

| Tatsächlich ausgeführte Kombination | Aufruferfolg | Separater Nachweis der Datentrennung |
|---|---|---|
| `VennAbersCalibrator(CalibratedClassifierCV(LogisticRegression, cv=3, ensemble=True, method='sigmoid'))`; binär und drei Klassen; IVAP/CVAP × VA-Ensemble/Vollmodell | Acht Kombinationen, 16 Paar-Domänen; endliche normierte Wahrscheinlichkeiten; gespeicherter Gesamtpfad nach Pickle-Roundtrip identisch. | Zeilen-IDs verfolgen jeden numerischen Modellfit, CCC-Postprocessor-Holdout, VA-Kalibrierung und äußere Bewertung. Assertions prüfen auch die zusätzlichen vorläufigen OvO-Fits. |
| `VennAbersCV(NumericPostprocessor(), setting='regression')`; IVAR/CVAR × Ensemble/Vollmodell | Vier Kombinationen, endliche Punkte/Intervalle; Pickle-Roundtrip identisch. `NumericPostprocessor` ist ein ausdrücklich gebauter sklearn-kompatibler **numerischer** Verbund: Ridge auf lokalem Trainingsanteil, gelernte IsotonicRegression auf separatem lokalem Anteil. | Eigene aufgezeichnete Modell-/Postprocessor-IDs, VA-Holdout-IDs und äußere Bewertungs-IDs; gleiche Trennungsassertions. Es ist ein Testschätzer, kein vorgeblich eingebauter sklearn-Holdout-Regressor. |
| Öffentlicher `VennAbersRegressor(NumericPostprocessor())`, IVAR/CVAR | Beide Aufrufe bestanden. | Detaillierter Modellaudit oben im zugrunde liegenden `VennAbersCV`; diese zusätzliche Fassade prüft Aufruferfolg. |
| `VennAbersRegressor(StackingRegressor([('ridge', Ridge())], final_estimator=Ridge(), cv=3))`, IVAR/CVAR | Beide Aufrufe bestanden; tatsächlich vorhandener sklearn-Verbund mit gelerntem numerischem Endmodell. | **Kein** eigener Row-ID-Audit des Stackings. Nicht mit dem getrennt instrumentierten Holdout-Verbund gleichsetzen. |

Die ID-Spalte wird vor dem numerischen Modellfit entfernt. Im Klassifikationsverbund ist der erste `decision_function`-Aufruf jedes CCC-Teilmodells dessen gehaltene Postprocessor-Lernmenge; diese Zuordnung entspricht dem ausgeführten sklearn-Quellpfad. Modelllernen und Postprocessor-Lernen sind innerhalb jeder CCC-Foldinstanz disjunkt; zusammen liegen sie vollständig im lokalen VA-Trainingsanteil. Verschiedene CCC-Foldinstanzen dürfen dieselben Zeilen in verschiedenen Rollen verwenden. Der spätere `predict_proba`-Aufruf auf dem VA-Holdout liefert die separat aufgezeichneten VA-Scores. In der Klassifikation prüft eine Instrumentierung von `VennAbers.fit` zusätzlich, dass genau die gespeicherten Score-/Labelarrays in den Kalibrierungskern gelangen. Die äußeren zwölf IDs kommen in keiner Lernmenge vor; erst die fertigen Prognosen werden mittels Log-Loss beziehungsweise MSE gegen ihre separat gehaltenen Ziele bewertet. [CCC-1.9.0-Quellvertrag](https://github.com/scikit-learn/scikit-learn/blob/1.9.0/sklearn/calibration.py), [VA-Modellwahl und Kernelaufruf](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L784-L837), [StackingRegressor](https://scikit-learn.org/1.9/modules/generated/sklearn.ensemble.StackingRegressor.html).

Wichtige Einschränkung des Vollmodellnachweises: Python trainiert zusätzlich ein Modell einschließlich aller Zeilen der jeweiligen Paar-Domäne. Bei `cv_ensemble=False` wendet es foldweise VA-Kalibratoren auf Scores dieses Vollmodells an; die Kalibrierungsscores stammen weiterhin aus den getrennten Fold-Modellen. Der Audit behauptet deshalb **nicht**, dass das Vollmodell die VA-Holdout-Zeilen nie gesehen hätte. Bei Ensemble-Vorhersage wird dieses zusätzlich trainierte Modell nicht benutzt. Für R gilt der bereits separat beschlossene abweichende Vollmodellvertrag; dieses Python-Verhalten ist keine neue Entscheidung und darf nicht stillschweigend übertragen werden. Die Regressionsfassade stellt `cv_ensemble` nicht bereit; der Vollmodellversuch verwendet deshalb ausdrücklich `VennAbersCV`. [Fit und Modellrouting](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L669-L905).

Nicht neu geprüft: CCC-internes `ensemble=False`, isotone oder Temperature-Klassifikationskalibrierung, vortrainierte `FrozenEstimator`-Verschachtelung, andere Basisschätzer, fehlende Klassen in kleinen Folds, Sample-Weights/Metadata-Routing, trainiertes OvR, mehr als drei Klassen im verschachtelten Fall, Brier-Merging mit diesen Verbünden und Python-Prozessparallelität. Bereits beschlossenes eingefrorenes Postprocessing wird durch diese Testgrenze nicht erneut ausgeschlossen. Endliche Aufrufe beweisen weder Kalibrierungsgüte noch Verfahrensgarantien.


Im erfassten Lauf meldete der Referenzkern 161 Warnungen `All-NaN slice encountered` und 48 Warnungen `invalid value encountered in divide`. Die positiv geprüften Endausgaben waren endlich; die Warnungen sind im [vollständigen Laufprotokoll](integration-boundaries-python-output.txt) erhalten. Sie sind kein gewünschter R-Verfahrensvertrag.


## R: Klassenidentität, native Tabellen und eingefrorene Workflows

**Ergebnis:** Die Zeichenketten einer Klasse und die Spaltennamen einer nativen Vorhersagetabelle sind verschiedene Verträge. Eine reversible Kodierung trägt die geprüften schwierigen Namen durch den normalen tidymodels-Pfad, wenn sie **vor** dessen Fit und äußerem Resampling auf Daten und Ziellevels angewendet wird. Nur im inneren Engine-Fit umzubenennen genügt nicht: tune verarbeitet auch die äußere Wahrheit und führt native Vorhersagespalten zusammen. Die Probe liefert einen möglichen technischen Weg, keine bereits implementierte vennabers-Schnittstelle und keine stellvertretende Entscheidung über deren öffentliche Bedienung.

Ausführbare Evidenz: [Namensprobe](integration-boundaries-names.R), [vollständige Ausgabe](integration-boundaries-names-output.txt). Ausgeführt am 2026-09-07 unter R 4.6.1 auf macOS arm64; parsnip 1.6.0, workflows 1.3.0, hardhat 1.4.3, tune 2.1.0, yardstick 1.4.0, rsample 1.3.2, recipes 1.4.0, tibble 3.3.1, rlang 1.2.0. Der Forschungsprädiktor berechnet nur empirische Klassenhäufigkeiten. So prüft er Namen und den nativen Transport unabhängig von der noch nicht implementierten Venn-Abers-Orchestrierung.

### Unveränderte native Namen: tatsächliche Gegenproben

Alle Klassenfälle verwenden einen normalen Workflow und `fit_resamples()` mit drei Folds, zwei Wiederholungen und Accuracy, multinomialem Log Loss und Brier. Die Originallevels bleiben ausdrücklich geordnet; es wird kein `make.names()` aufgerufen.

| Originale Klassen | Alleinstehendes natives Predict | Äußeres Resampling und Collector |
|---|---|---|
| `class`, `other` | Wahrscheinlichkeitsvorhersage scheitert am reservierten Level | Sechs Predict-Fehler. Die unzusammengefassten Collector liefern hier lediglich `id`/`id2`-Hüllen ohne Vorhersagen beziehungsweise `.estimate`; ein erfolgreicher Funktionsreturn bedeutet keine erfolgreiche Bewertung. |
| `.pred_yes`, `other` | Liefert `.pred_yes` und das **unpräfigierte** `other` | Sechs Metrikfehler, weil `.pred_.pred_yes` fehlt; 120 gespeicherte Vorhersagezeilen, aber der Metric-Collector scheitert. |
| `a b`, `other` | Originalnamen in `.pred_a b`, `.pred_other` | 120 Vorhersagen, 18 endliche Einzelmetriken, keine Notes. |
| `1yes`, `other` | Originalnamen in `.pred_1yes`, `.pred_other` | Dieselbe vollständige erfolgreiche Bewertung. |
| `a b`, `a-b`, `a.b` | Drei verschiedene Wahrscheinlichkeitsspalten | Dieselbe vollständige erfolgreiche Bewertung; obwohl `make.names()` alle drei in `a.b` überführt. |

Die Negativfälle sind damit nicht pauschal „R erlaubt keine Leerzeichen“. parsnip 1.6.0 prüft ausdrücklich auf das Level `class`. Seine Präfixierung lässt bei bereits vorhandenen `.pred_`-Namen die beobachtete Mischung entstehen; tune erwartet für seine Wahrscheinlichkeitsmetriken weiterhin die aus den Levels abgeleiteten Spalten. `make.names(unique=TRUE)` wäre zwar eindeutig, aber allein noch keine gespeicherte, stabile Zuordnung; die unveränderte Standardvariante ist nicht injektiv. [Reservierte Klasse](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/predict_classprob.R), [parsnip-Präfixierung](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/predict.R), [tune-Vorhersage/Metrikpfad](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/loop_over_all_stages-helpers.R), [R-Namensreparatur](https://stat.ethz.ch/R-manual/R-devel/library/base/html/make.names.html).

Eine getrennte beobachtende Probe verwendet sichere Klassen `yes`/`no` und problematische **Zielspaltennamen**: `.pred_class` und `.pred_yes` brechen die Zusammenführung/Bewertung ab; `.row` wird zur ganzzahligen Zeilenkennung, worauf Accuracy sechs Fehler wegen nichtfaktorieller Wahrheit meldet; `id` wird beim Sammeln zu `id...1`/`id...3` repariert; `.config` erzeugt einen Fehler. Ein Ziel namens `a b` funktioniert. Diese Fälle stehen vollständig in der Ausgabe; ihre konkreten Fehlertexte sind versionsgebundene Beobachtungen, kein gewünschter Produktvertrag.

### Belegter reversibler Weg

Die Probe erzeugt einmalig ein Schema aus der **vorgegebenen Faktorlevel-Reihenfolge** und den eindeutigen Rohspaltennamen. Positionscodes `vaL0001`, … ersetzen nur die Levels der Zielvariablen; `vaV0001`, … ersetzen die Carrier-Spalten. Das gespeicherte Schema enthält beide Richtungen sowie den ursprünglichen Zielnamen. Ein Originallevel namens `vaL0001` und ein Originalprädiktor namens `vaV0001` werden ebenfalls geprüft: Die vollständige positionsbasierte Zuordnung kollidiert nicht mit ihnen. Unbekannte Spalten, andere Faktorlevel-Reihenfolge und fehlende Zielwerte werden in der Forschungsgrenze abgewiesen. Die Probe ist kein vollständiger produktiver Schemavalidator.

Der nachgewiesene Ablauf ist:

```text
Originaldaten + explizites Schema
  → kodierte Daten / kodierte äußere Resamples
  → gewöhnlicher Workflow fit() / predict() / fit_resamples()
  → kodierte native .pred_*-, .pred_class- und Wahrheitsspalten
  → collect_predictions(summarize=FALSE), collect_metrics(), collect_extracts()
  → explizite Dekodierung mit gespeichertem Schema
```

Geprüft sind binär `class`/`.pred_yes` und acht Klassen in der Reihenfolge `a.b`, `class`, `.pred_yes`, `a b`, `1yes`, `a-b`, `ümlaut`, `vaL0001`. Jeder Fall läuft mit sieben ursprünglichen Zielnamen: `truth`, `.pred_class`, `.pred_vaL0001`, `.row`, `id`, `.config`, `a b`. Die Klassenhäufigkeiten sind absichtlich unterschiedlich, sodass ein vertauschtes Wahrscheinlichkeitsmapping nicht durch gleiche Zahlen verborgen wird.

Pro binärem Fall: 52 Vorhersagezeilen; pro Acht-Klassen-Fall: 304 Vorhersagezeilen; jeweils 18 endliche Einzelmetriken, sechs extrahierte Enginezustände und keine Notes. Assertions vergleichen Originalwahrheit über `.row`, die exakte Level-Reihenfolge, jede Wahrscheinlichkeitszuordnung mit dem extrahierten Resamplemodell und alle drei nativen Metriken mit erneuter yardstick-Berechnung auf den dekodierten Originalidentitäten. Binär wird zusätzlich die Gleichheit der Brier-Werte mit erster Ereignisspalte beziehungsweise komplementärer zweiter Ereignisspalte und `event_level='second'` geprüft. Ein frischer R-Prozess liest den RDS-Zustand, wiederholt das native Predict und bestätigt Collector-Ergebnis, Mapping und Diagnose identisch. Der frische Prozess registriert dieselbe Forschungsengine; dies ersetzt keine installierte Paket-/Worker-Abnahme.

Die Ausgabe enthält zusätzlich **14 vollständig ausgeschriebene rsample-Warnungen bei der Planerzeugung**, zwei Wiederholungen × sieben Acht-Klassen-Datensätze: `Stratifying groups that make up 0% of the data may be statistically risky.` Auslöser sind das bewusst gesetzte `pool=0` und mindestens eine Klasse unter 10% Anteil (kleinste Klasse: 12/152 ≈ 7,9%). Die gedruckten 0% stammen vom Poolparameter, nicht von einer leeren Klasse. Der Test behält die Originalstrata; sämtliche sechs Modelle und Vorhersagemengen sind vollständig, und die nachfolgende tune-Auswertung enthält keine Notes. Es sind keine unbekannten Warnungen aus erfolgreich behaupteten Modellfits. [Exakte rsample-Warnbedingung](https://github.com/tidymodels/rsample/blob/658545caf9855dd74ec13c2ac63163889e632a7b/R/make_strata.R).

Die Diagnostik hält `truth`, `class`, eine Wahrscheinlichkeit **als Matrix mit originalen Klassennamen**, `outcome` als einzelnen ursprünglichen Namen und äußere Identität in getrennten Listenelementen. Sie benennt nicht einfach alle Spalten einer einzigen nativen Tabelle zurück: Originalklasse `class` und originales Ziel `.pred_class` könnten dort erneut kollidieren. Die öffentliche Extraktion ist belegt; `save_pred=TRUE` und eine explizite `extract`-Funktion erhalten die benötigten Ergebnisse. [Collector-Vertrag](https://tune.tidymodels.org/reference/collect_predictions.html), [Workflow-Extraktoren](https://workflows.tidymodels.org/reference/extract-workflow.html).

**Reichweite:** Dies beweist eine explizite Kodierungsgrenze um den nativen Pfad. Es beweist keine transparente Reparatur eines unveränderten `fit_resamples(workflow, raw_resamples)` und keine automatische Umschreibung beliebiger bestehender Recipes. Ein zukünftiger trainierbarer Verbund muss vor dem Aufruf seines ursprünglichen Basis-Workflows dessen Rohspalten und Identitäten korrekt rekonstruieren oder einen ausdrücklich kodiert konstruierten Basis-Workflow erhalten. Namen, die ein Recipe in Ausdrücken oder ein Modell in seinem Zustand speichert, dürfen nicht blind ersetzt werden. Die numerische VA-Parität, alle Enginevarianten, fehlende Klassen in lokalen Folds, Parallelität dieser Namensprobe und die allgemeine Unterstützung zusätzlicher Postprozessoren sind nicht nachgewiesen.

### Gemeinsamer Vertrag für eingefrorene Modelle

Ein eingefrorener Workflow bleibt unverändert: Sein trainiertes Recipe, seine Modellparameter und sein Postprocessing dürfen nicht nachträglich auf andere Klassen- oder Spaltennamen umgeschrieben werden. Eine äußere Kodierung allein repariert deshalb kein bereits gespeichertes Modell, dessen eigener nativer Wahrscheinlichkeitspfad `class` zurückweist.

Die Probe zeigt einen **begrenzten öffentlichen Ausweg**: Ein eingefrorener binärer `glm`-Workflow mit gelerntem Normalisierungsrecipe und Levels `class`/`other` scheitert bei `predict(type='prob')`, funktioniert aber mit `predict(frozen, new_data, type='raw', opts=list(type='response'))`. Der Aufruf läuft durch das gespeicherte Workflow-Preprocessing; eine Kontrollrechnung verwendet ausdrücklich `hardhat::forge()` vor dem extrahierten GLM. Für binomiales GLM ist die Response-Wahrscheinlichkeit dem zweiten Faktorlevel zugeordnet; die Matrix `cbind(1-p,p)` erhält daher die beiden Originallevels in der gespeicherten Reihenfolge. Alle Werte sind endlich und in [0,1], und der serialisierte Workflowzustand ist vor/nach beiden Vorhersagen bytegleich. [Öffentliches raw/opts](https://parsnip.tidymodels.org/reference/predict.model_fit.html), [binomiales GLM](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/glm.html).

Das ist ein engineabhängiger Wahrscheinlichkeitszugriff, kein universelles `raw`-Versprechen. Bei einem Workflow mit Postprocessor verwendet workflows 1.3.0 zuerst `augment()` des Modells und danach den gespeicherten Postprocessor; erlaubt sind dort `numeric`, `class` und `prob`, während `raw` ausdrücklich zurückgewiesen wird. Die [Postprocessing-Probe](integration-boundaries-postprocessing.R) bestätigt dies an einem bereits gefitteten binären GLM mit gelerntem logistischem Tailor: `Unsupported prediction type "raw" for a workflow with a postprocessor.` Ein direktes `predict()` des extrahierten Modells würde den vollständigen gelernten Pfad umgehen und ist keine allgemeine Lösung. [Versionierter Workflow-Predictpfad](https://github.com/tidymodels/workflows/blob/92e604424f8ee1d99f754c8c7e2b906d2cf7689d/R/predict.R), [Warnung zum Extrahieren für Predict](https://workflows.tidymodels.org/reference/extract-workflow.html).

**Offene menschliche Entscheidung:** Wie wird die notwendige Kodierungsgrenze öffentlich sichtbar: explizites Daten-/Resampling-Bundle mit nativen Codeausgaben plus separater dekodierter Diagnose oder eine eigene äußere Bedienoberfläche, die diese Schritte ausführt? Für eingefrorene Workflows muss derselbe Originalidentitätsvertrag zusätzlich einen überprüfbaren vollständigen Wahrscheinlichkeitspfad festlegen: bereits namenskompatibler nativer Workflow oder expliziter, validierter Zugriff für den konkreten gespeicherten Modell-/Postprozessorverbund. Die bereits beschlossene Unterstützung eingefrorener Modelle und eingefrorenen Postprocessings wird dadurch nicht erneut ausgeschlossen; die Frage präzisiert deren tragfähigen Eingabevertrag. Keine allgemeine Zusage beliebiger eingefrorener tidymodels-Objekte aus dem einzelnen GLM-Erfolg ableiten.

Ausführbare Folgeabnahme nach einer Produktimplementierung: Die hier aufgeführten Originalnamen und Outcome-Kollisionen mit binär/OvO/OvR, allen zugesagten trainierbaren und eingefrorenen Basiswegen sowie zusätzlichem gespeichertem Postprocessing ausführen; komplette Wahrscheinlichkeitsmatrizen und Originalidentitäten durch alle Collector/Diagnosewege vergleichen; absichtlich fehlende, doppelte, vertauschte oder unbekannte Zuordnungen ablehnen; gespeicherte Modelle unverändert lassen. Roh-Nativeinschränkungen dürfen dabei nicht durch einen nur alleinstehend erfolgreichen Predict verdeckt werden.


## R: identische lokale Daten mit verschiedenen festen Plänen

**Ausgeführtes Ergebnis:** Explizite äußere Orchestrierung funktioniert mit öffentlichen R-Schnittstellen. Ein Job enthält eine feste Vorkommenskennung, einen Seed, den exakten lokalen Datenbestand und den zugehörigen inneren Plan. Vor seinem äußeren Fit wird dieser Kontext als Engine-Argument gebunden. Anschließend läuft ein gewöhnliches `tune::fit_resamples()` für genau dieses äußere Vorkommen. Die Zuordnung kommt aus dem Jobwert, niemals aus Datenlänge, Ausführungsposition oder einem Aufrufzähler. `set_engine()` unterstützt zusätzliche Engine-Argumente; `manual_rset()` erhält explizite Resample-IDs. [parsnip](https://parsnip.tidymodels.org/reference/set_engine.html), [rsample](https://rsample.tidymodels.org/reference/manual_rset.html), [tune](https://tune.tidymodels.org/reference/fit_resamples.html).

Die Probe [integration-boundaries-plans.R](integration-boundaries-plans.R) registriert eine kleine Forschungsengine. Sie trainiert echte logistische Basis-Workflows je innerem Trainingsanteil und speichert ihre gehaltenen Kalibrierungsvorhersagen. Ihre Endvorhersage ist lediglich der Mittelwert der Fold-Wahrscheinlichkeiten, **keine Venn-Abers-Kalibrierung**. Sie prüft die Identitäts-/Transportstelle der geplanten Integration, keine numerische Produktfähigkeit. Das [Laufprotokoll](integration-boundaries-plans-output.txt) dokumentiert:

- Zwei äußere Vorkommen `Repeat-A`/`Repeat-B`, exakt dieselben 72 lokalen Beobachtungen, je drei vorab festgelegte, aber unterschiedliche innere Folds. Beide bewerten ausschließlich die übrigen 24 Beobachtungen. Die Planwahl erfolgt vor jeglichem Fit.
- Pro Vorkommen stimmen gespeicherte Planindizes und tatsächlich im GLM verwendete Trainingswerte exakt überein. Die gehaltenen Wahrscheinlichkeiten entsprechen den Vorhersagen des richtigen gespeicherten Fold-Workflows. Die unterschiedlichen Pläne erzeugen hier unterschiedliche Endvorhersagen.
- Vollständige Vorhersagen, Metriken und Kontext sind bei erneutem Durchlauf in umgekehrter Reihenfolge, nach RDS-Roundtrip der Jobs und auf zwei frischen PSOCK-Workern identisch. Die Worker laden Registrierung/Funktionen ausdrücklich; es gibt keinen versteckten gemeinsamen Auswahlzustand. Das gespeicherte Modellobjekt behält nach eigenem RDS-Roundtrip denselben Vorhersagepfad. Parallelisierung nutzt R-`parallel`, keine neue Produktabhängigkeit. [R-Cluster-Schnittstelle](https://stat.ethz.ch/R-manual/R-devel/library/parallel/html/clusterApply.html).
- Ein absichtlich veränderter lokaler Daten-Snapshot wird vor Basisfits mit `Plan does not match local data` abgewiesen. Die gewöhnliche lokale Daten-/Planprüfung bleibt also zusätzlich zur Identität nötig.

**Grenze:** Diese Probe beweist kein automatisches Umschalten zwischen verschiedenen Plänen innerhalb **eines** unveränderten `fit_resamples(workflow, alle_resamples)`-Aufrufs. Die öffentliche Workflow-Fit-Signatur trägt Daten, Postprocessing-Daten und Kontrolloptionen, aber keine äußere Resample-ID. tune finalisiert die Modellspezifikation und ruft den Workflow-Modellfit auf; die äußeren IDs verbleiben in seiner Orchestrierung. Ein Engine-Callback `function(data)` kann identische Daten nicht in zwei Vorkommen unterscheiden. [Workflow-Fit](https://workflows.tidymodels.org/reference/fit-workflow.html), [tune 2.1.0, finalize_fit_model](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/loop_over_all_stages-helpers.R#L343-L358), [bestehender Vertrag](https://github.com/RMKruse/venn-abers/issues/15#issuecomment-5570134201).

Ein mögliches Produktangebot wäre ein ausdrücklich gewählter Orchestrierungszugang, der Jobs nach gespeicherter Kennung dispatcht und Ergebnisse mit dieser Kennung sammelt. Das ist eine Bedienentscheidung; die vorliegende externe Forschungsschleife ist keine neue zugesagte API. Für die gewöhnliche native Nutzung bleibt die bisherige eindeutige Daten-zu-Plan-Funktion ausreichend. Die Python-Untersuchung im selben Bericht bestimmt, ob die zusätzliche Bedienung Parität oder darüber hinausgehender Komfort wäre.

**Noch nicht ausgeführt:** gemeinsame/zweistufige Modellwahl, Bayes-Suche, kombinierter `tune_results`-Collector über getrennte Aufrufe, anderes Betriebssystem, andere Parallel-Backends, installierte vennabers-Engine sowie numerische Venn-Abers-Aggregation in diesen Jobs. Ein produktiver Dispatcher muss zusätzlich doppelte/fehlende Vorkommenskennungen, falsche Job-/Resample-Bindung und vollständige äußere Bewertung prüfen. Diese ausstehende Implementierungsabnahme begründet keine Behauptung, die vorhandene Ein-Workflow-API könne bereits alles davon.


## R-Nachweis: zusätzlich gelerntes Postprocessing im VA-Quellmodell

Teilrecherche vom 2026-09-07 zu [Vorläufige Integrationsgrenzen gegen die vollständige Python-Parität prüfen](https://github.com/RMKruse/venn-abers/issues/16), ausschließlich Punkt „Zusätzliches gelerntes Postprocessing“. Dies ist eine API-/Datenflussprobe, keine Venn-Abers-Implementierung, keine numerische VA-Paritätsabnahme und keine neue Scope-Entscheidung.

**Ergebnis:** Öffentliche R-APIs tragen einen vollständigen Basis-Workflow mit neu gelerntem Recipe, Modell und zusätzlichem Tailor. Der Aufrufer muss innerhalb jedes VA-Quelltrainingsbestands einen weiteren Trainings-/Postprocessing-Holdout bereitstellen. Erfolgreich geprüft wurden binäre, gemeinsame Multiclass- und echte numerische Regressionsmodelle, jeweils ein Inductive-Quellmodell und drei Cross-Quellmodelle. Das beweist einen getrennten Holdout-Postprocessor, **keine Gleichheit mit dem inneren Cross-Kalibrierungsensemble von sklearn `CalibratedClassifierCV`**. Dessen Referenznachweise stehen im Python-Abschnitt dieses Berichts.

### Öffentlicher Daten- und Aufrufpfad

Die Rollen pro Quellmodell sind:

1. **B:** Recipe- und Basismodelllernen.
2. **P:** Lernen des zusätzlichen Postprocessors aus endgültigen Basismodellvorhersagen auf gehaltenen Daten.
3. **C:** spätere Venn-Abers-Kalibrierung aus Vorhersagen des vollständigen B/P-Workflows.
4. **A:** unabhängige äußere Bewertung.

B und P bilden zusammen den jeweiligen Quelltrainingsbestand S; C und A gehören nicht zu S. Im Cross-Fall gilt das pro Fold, nicht global: Eine Beobachtung darf in einem anderen Fold eine andere Rolle haben. Im paarweisen Weg muss bereits S auf das betreffende Klassenpaar eingeschränkt sein; dieser R-Paarweg wurde hier nicht ausgeführt.

```r
# va_split ist der ursprüngliche Split mit analysis=S und assessment=C.
inner <- rsample::internal_calibration_split(
  va_split, split_args = list(prop = .75)
)
source <- generics::fit(
  base_workflow_with_tailor,
  data = rsample::analysis(inner),             # B
  data_calibration = rsample::calibration(inner) # P
)
va_input <- predict(source, rsample::assessment(va_split), type = "prob")
new_input <- predict(source, new_data, type = "prob")
# Für Regression beide Male type = "numeric".
```

`fit.workflow(data=..., data_calibration=...)` ist eine öffentliche Schnittstelle; `data` lernt Preprocessing und Modell, `data_calibration` den Tailor. [Fit-Dokumentation](https://workflows.tidymodels.org/reference/fit-workflow.html). `add_tailor()` erwartet einen ungefitten Tailor. Es beschreibt ausdrücklich getrennte Datenrollen und die Gefahr duplizierter Beobachtungen bei naiven Bootstrap-Aufteilungen. [Postprocessor-Dokumentation](https://workflows.tidymodels.org/reference/add_tailor.html).

`internal_calibration_split()` teilt ausschließlich analysis des übergebenen Originalsplits; die Probe behält den Originalsplit für C. Der innere Split besitzt absichtlich keine nutzbare `assessment()`-Methode. Der explizite Anteil `.75` ist eine Versuchseinstellung, kein beschlossener Produktdefault. Die API kann weitere Resampling-Klassen behandeln; daraus folgt hier keine Abnahme für Gruppen, Zeitreihen oder Bootstrap. [rsample-API](https://rsample.tidymodels.org/reference/internal_calibration_split.html).

Der gespeicherte **vollständige Workflow** verarbeitet neue Rohdaten einschließlich Recipe, Modell und Tailor. Weder nur `extract_fit_engine()` vorhersagen noch Tailor ein zweites Mal anwenden. Die unabhängige Rekonstruktion in der Probe dient dem Nachweis, nicht als Produktvorhersagepfad. [Versionierter Workflow-Predict](https://github.com/tidymodels/workflows/blob/92e604424f8ee1d99f754c8c7e2b906d2cf7689d/R/predict.R), [öffentlicher Predict-Vertrag](https://workflows.tidymodels.org/reference/predict-workflow.html).

### Ausgeführte Evidenz

[Ausführbare Probe](integration-boundaries-postprocessing.R) und [vollständige Ausgabe](integration-boundaries-postprocessing.txt):

```sh
VENN_RESEARCH_LIB=/tmp/venn-tidymodels-lib \
  /opt/homebrew/opt/r/bin/Rscript --vanilla \
  tools/integration-boundaries-postprocessing.R
```

`VENN_RESEARCH_LIB` ist optional; ansonsten werden regulär verfügbare Pakete verwendet. Die Forschung installierte `probably` mit seinen fehlenden Abhängigkeiten nur in die temporäre Bibliothek, nicht als neue vennabers-Paketabhängigkeit.

| Geprüfter Quellworkflow | Postprocessing | Geprüfte Partitionen | Ergebnis |
|---|---|---|---|
| Binär: normalisierendes Recipe + glm | `adjust_probability_calibration(method="logistic", smooth=FALSE)` | Inductive + drei Cross-Folds | bestanden |
| Drei Klassen: normalisierendes Recipe + nnet multinom | `adjust_probability_calibration(method="multinomial", smooth=FALSE)` | Inductive + drei Cross-Folds | bestanden |
| Numerische Regression: normalisierendes Recipe + lm | `adjust_numeric_calibration(method="linear", smooth=FALSE)` | Inductive + drei Cross-Folds | bestanden |

Diese Tailor-Methoden delegieren an probably. `smooth=FALSE` wählt die parametrischen glm-/multinom-/lm-Wege; die Standardmethoden können sonst GAMs verwenden. Es wird kein Klassifikationswrapper als Regression ausgegeben. [Klassifikations-API](https://tailor.tidymodels.org/reference/adjust_probability_calibration.html), [numerische API](https://tailor.tidymodels.org/reference/adjust_numeric_calibration.html).

Pro Modus betrugen die Rollen B/P/C/A beim Inductive-Fall 562/188/250/200, bei Cross 499/167/334/200 beziehungsweise 500/167/333/200. Die IDs waren reine Prüfmetadaten, keine Prädiktoren. Alle zwölf Fälle prüfen:

- Alle sechs paarweisen Rollenüberschneidungen sind leer; B∪P=S und B∪P∪C ist exakt der lokale Entwicklungsbestand.
- Die Recipe-Mittelwerte entsprechen ausschließlich B. Die Modellkoeffizienten stimmen mit einem separat nur auf B trainierten Workflow ohne Tailor überein.
- Ein unabhängig mit öffentlichen Tailor-APIs auf Vorhersagen für P gefitteter Postprocessor rekonstruiert die gespeicherten Workflow-Vorhersagen bis Toleranz 1e-12. Postprocessing verändert die Rohvorhersagen in allen Fällen tatsächlich.
- Geänderte Zielwerte ausschließlich in P verändern die endgültigen Vorhersagen, lassen aber die Basismodellkoeffizienten unverändert.
- Extreme Prädiktorwerte und geänderte Ziele ausschließlich in C und A verändern den mit denselben B/P-Zeilen erneut trainierten Quellworkflow nicht. Das prüft die Ausschlussgrenze, nicht die statistische Austauschbarkeit von Daten.
- C und A erhalten vollständige endliche Vorhersagen ohne benötigte Zielspalte. Sämtliche zwölf vollständigen Workflows liefern nach `saveRDS()`/`readRDS()` in einem **frischen R-Prozess** dieselben Ergebnisse. Serialisierte Workflowzustände bleiben vor/nach Predict bytegleich.

Die A-Vorhersagen sind hier **Basisworkflow-Vorhersagen**. Es wurden weder ein VA-Kalibrator noch endgültige VA-Metriken, natives äußeres `fit_resamples()` der geplanten Integration oder die paarweisen/full-transfer VA-Verbünde implementiert.

### Beobachtete Negativfälle und Grenzen

- Ohne `data_calibration` scheitert ein lernender Tailor in allen drei Modi: `The workflow requires data_calibration to train but none was supplied.` Die tatsächliche Meldung mit Backticks steht im Ausgabelog.
- `assessment(inner)` scheitert: innere Kalibrierungssplits liefern nur analysis/calibration. C muss aus dem Originalsplit stammen.
- Explizit `method="logistic"` scheitert bei drei Klassen; die geprüfte Korrektur ist `"multinomial"`. Nicht bloß von gleichem Methodennamen auf Klassenunterstützung schließen.
- Bei einem gefitteten binären Workflow mit Tailor scheitert `predict(type="raw", opts=list(type="response"))`: `Unsupported prediction type "raw" for a workflow with a postprocessor.` Der im Namenstest mögliche Raw-Ausweg einer bloßen glm-Basis gilt somit nicht allgemein für bereits gelernte Tailor-Workflows; ein gemeinsamer Namensadapter darf den Postprocessor nicht umgehen. Die tatsächliche Meldung steht im Ausgabelog. [Versionierter Predict-Pfad](https://github.com/tidymodels/workflows/blob/92e604424f8ee1d99f754c8c7e2b906d2cf7689d/R/predict.R).
- **Überlappende Daten werden akzeptiert:** Der binäre Negativversuch `fit(spec, data=B, data_calibration=B)` liefert einen trainierten Workflow. Die API garantiert die Datenrollen nicht selbst; die spätere VA-Orchestrierung muss sie prüfen.
- Die Tailor-Quellen dokumentieren bei zu wenig Kalibrierungsdaten einen möglichen Wechsel der Methode auf `"none"`. Dieses Kleinstmengenszenario wurde hier nicht ausgeführt; die Abnahme muss eine gewünschte Fehler-/Fallback-Regel ausdrücklich prüfen. [Klassifikationsquelle](https://github.com/tidymodels/tailor/blob/45149043e3178771303cdeaad6344277a3280fb9/R/adjust-probability-calibration.R), [Regressionsquelle](https://github.com/tidymodels/tailor/blob/45149043e3178771303cdeaad6344277a3280fb9/R/adjust-numeric-calibration.R).

Dies ist keine Zusage beliebiger Tailor-Schrittfolgen, fremder Engines, wiederholter innerer Cross-Kalibrierung, Parallelreproduzierbarkeit, GPU-/Pointer-Serialisierung oder allgemeiner Python-Schätzerkompatibilität. Keine Güteverbesserung oder VA-Garantie folgt allein aus den erfolgreichen API-Aufrufen.

### Vollmodell und eingefrorene Workflows

**Vollmodell-Übertragung:** Der [beschlossene Vertrag](https://github.com/RMKruse/venn-abers/issues/11) erlaubt einen zusätzlichen Quellbestand, der auch die bisherigen VA-Kalibrierungsbeobachtungen umfasst; äußere Bewertung und separat zurückgehaltene Auswahlanteile bleiben ausgeschlossen. Gehaltene C-Vorhersagen müssen trotzdem unverändert aus den ursprünglichen, C ausschließenden Quellmodellen stammen.

Die hier bewiesene B/P-Holdout-Komposition lernt die eigentliche Engine auf B, **nicht auf B∪P**. Sie darf deshalb nicht ungeklärt als engineweites Training auf allen zulässigen Vollmodellbeobachtungen ausgegeben werden. Ein zusätzlicher OOF-Postprocessor plus auf ganz S refittete Engine oder ein inneres Kalibrierungsensemble wäre ein anderer, gesondert nachzuweisender Daten- und Objektvertrag. Diese Probe belegt weder die Nachrüstung eines schon trainierten Tailors in einen Workflow noch diese OOF-Komposition.

**Eingefrorener Zugang:** Der [bestehende Vertrag](https://github.com/RMKruse/venn-abers/issues/12) schließt bereits gelerntes Postprocessing ein. Dafür werden ausschließlich endgültige Vorhersagen des unveränderten Workflowzustands auf neuen separaten C-Daten erzeugt; B und P liegen in dessen Vergangenheit. Die hier geprüfte unveränderte Wiederverwendung und RDS-Speicherung unterstützen diesen Vorhersagepfad. Sie ersetzen weder die Herkunftserklärung des Nutzers noch die noch ausstehende Implementierungsabnahme des eingefrorenen VA-Zugangs. Dieser Support wird nicht erneut zur Entscheidung gestellt.

### Präzise offene HITL-Entscheidung

**Welche endliche Menge neu zu trainierender Basis-Kompositionen wird zugesagt, und welcher öffentliche lokale Trainingsplan gilt innerhalb jedes VA-Quellbestands beziehungsweise Klassenpaars?** Konkret entscheiden:

1. Reicht ein ausdrücklich benannter B/P-Holdout-Workflow zusätzlich zu den bisherigen Basen, oder verlangt der Paritätsanspruch auch ein eigenes inneres Cross-Kalibrierungsensemble entsprechend der bestätigten Python-Komposition? R-Holdout und Python-CCC-Ensemble sind keine austauschbaren numerischen Verfahren.
2. Wer erzeugt B/P beziehungsweise die zusätzlichen OOF-Pläne: expliziter Nutzerplan/lokaler Callback oder auch automatischer Default? Anteil/Foldzahl, seed, Stratifikation, Mindestdaten, Klassenbesetzung und Fehler statt stiller Fallbacks gehören in diesen Vertrag. Kein Rückgriff auf C oder A zum Erfüllen des zusätzlichen Datenbedarfs.
3. Welche vollständige Basis-Komposition meint „auf ganz S trainiertes Vollmodell“ bei gelerntem Postprocessing: Engine-Refit auf ganz S nach OOF-Postprocessing oder eine Komposition mit intern gehaltenem P? Dies präzisiert die Kombination mit der bestätigten Vollmodell-Übertragung und darf deren Datenvertrag nicht still verändern.

Anschließende Produktabnahme: alle bestätigten Klassifikations-/Regressionswege × Inductive/Cross × passend/Vollmodell, gegebenenfalls je Paar; tatsächliche endgültige VA-Kalibrierung und Kernvergleich; native äußere Bewertung mit vollständiger Ergebniskontrolle; getrennte Modell-/Postprocessor-/VA-/Assessment-Rollen samt Fit-Zählern; gespeicherte komplette Vorhersagepfade; fresh-process Speicherung; explizite Fehler bei ungültigen Plänen und insuffizienten Postprocessing-Daten. Ein einziger bestandener klassischer Holdout-Test deckt diesen Umfang nicht ab.

### Versionen

Ausgeführt: R 4.6.1 (`aarch64-apple-darwin25.4.0`), workflows 1.3.0, parsnip 1.6.0, recipes 1.4.0, rsample 1.3.2, tailor 0.1.0, probably 1.2.0 und nnet 7.3.20. Vollständiges Log oben. Die per offizieller GitHub-Tag-API aufgelösten Quellstände sind workflows `92e604424f8ee1d99f754c8c7e2b906d2cf7689d`, rsample `658545caf9855dd74ec13c2ac63163889e632a7b`, tailor `45149043e3178771303cdeaad6344277a3280fb9`, probably `4a2b767aa2c2f3bb1b0770db3ce8f7bf2873c80a`. Dies sind geprüfte Versionen, keine neu beschlossenen Mindestversionen.


## Abnahme und weitere Entscheidungen der Map

Die ausführbaren Forschungsprogramme liefern bereits konkrete Positiv-/Negativszenarien. Für die spätere Produktabnahme sind ihre künstlichen Transportprädiktoren durch die geplante vennabers-Integration zu ersetzen; die bereits bestätigten numerischen Kernvergleiche und Verfahrensverträge gelten zusätzlich. Als Mindestzuordnung aus dieser Untersuchung:

| Abnahmegruppe | Schon ausgeführt | Nach Implementierung zusätzlich erforderlich |
|---|---|---|
| Originalidentität | Python-Trainings-/Arraywege; R binär/acht Klassen, sieben Zielnamen, äußere Wiederholung und Metrikrekonstruktion | Kalibrierte binäre/OvO/OvR-Ausgaben, Paar-/Fold-Diagnostik, Null-/Einzeilenschema, eingefrorene vollständige Pfade und gültige/ungültige Namenszuordnungen |
| Feste Vorkommenspläne | Python manuell/sklearn; R explizite Jobbindung, wiederholt/vertauscht/serialisiert/PSOCK | Reale VA-Kerne mit denselben Plänen; vollständige Ergebnisprüfung und alle zusätzlich zugesagten Tuning-/Dispatcher-Wege. Keine ausstehende Prüfung als schon vorhandene Paketautomatik darstellen. |
| Zusätzliches Lernen | Python 12 instrumentierte Verbundkombinationen und separate Fassadenaufrufe; R 12 vollständige Quellworkflows mit frischem Speicher-Roundtrip | Gewählte endliche Kompositionsmatrix, echte VA-Kalibrierung, äußeres natives Resampling, Tuning, Paar-/Vollmodell-Kombinationen, frühe Split-/Kleinmengenfehler und gespeicherter vollständiger Predict-Pfad |

Zwei jetzt präzise menschliche Folgeentscheidungen sind nötig:

- **Reversible Namenskodierung für native und eingefrorene Workflows festlegen**: Sichtbarkeit/Bedienung der Kodierung und kollisionsfreier Originalidentitätsvertrag einschließlich unverändertem eingefrorenem Postprocessing.
- **Zusätzlich gelerntes Postprocessing und innere Datenverträge bis v1.0 festlegen**: endliche zugesagte Kompositionen, zusätzliche lokale Pläne, Vollmodellbedeutung, Aufwand, Fehler und vollständige Abnahme.

Die Resolution des Untersuchungstickets verlinkt diese neuen Kindtickets und schaltet sie nativ vor die Release-Synthese. Dieses Research löst sie nicht stellvertretend auf. Die endgültige Release-Zuordnung bleibt [Release-Reife und verbindliche Milestone-Zuschnitte festlegen](https://github.com/RMKruse/venn-abers/issues/7) vorbehalten.

Für Vorkommenspläne entsteht aus den geprüften Quellen keine zusätzliche ungeklärte Paritätspflicht: parameterdarstellbare native Pläne und explizite externe Orchestrierung sind getrennt belegt. Ein einziger neuer automatischer Vorkommens-Dispatcher wird hier weder zugesagt noch als dauerhafter Ausschluss festgelegt. Ein später ausdrücklich gewünschter solcher Komfort wäre als zusätzliche Produktfrage zu erfassen.

Die Untersuchung verändert keine Produktionsdateien, implementiert keine Features und schließt ausschließlich das Research-Ticket. R-Paket-, CI-, Plattform- und statistische Gesamtfreigaben sind damit nicht ausgeführt.
