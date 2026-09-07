# Belegte Anwendungsfälle und Gruppen-/Zeitbezug

Recherche vom 2026-09-07 für [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen](https://github.com/RMKruse/venn-abers/issues/13). Maßstab des Nutzers: vollständige funktionale Parität mit den bestehenden Python-Implementierungen und Orientierung an den Papern. Dieses Dokument sammelt Evidenz; es führt keine neue Produktentscheidung ein.

## Python 1.5.4

Geprüfter Referenzstand: `0e7b4bc575ce230134576ba1c76688d46bf99ac7`. Die Notebook- und Quellcodebefunde wurden in dieser Sitzung gegen diesen Stand gelesen; keine neuen numerischen Experimente durchgeführt.

| Beispiel | Konkrete Aufgabe | Belegter Ablauf |
|---|---|---|
| [Binäre Klassifikation](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/simple_classification.ipynb) | Künstliche binäre Daten, 100.000 Zeilen, Gaussian Naive Bayes | IVAP, CVAP und manuelle Kalibrierung. `shuffle=False` kommt vor; die Daten sind keine Zeitreihe. |
| [Mehrklassenklassifikation](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/multiclass_classification.ipynb) | Satellite Image sowie künstliche Daten mit fünf Klassen und Random Forest | Trainierter Mehrklassenablauf sowie manuelles OvO/OvR. |
| [Regression](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/ivar_example.ipynb) | Synthetische Friedman-1/2/3-Regressionsaufgaben mit sieben Basismodellen | Der ausgeführte Benchmark verwendet CVAR; `m` steuert die Moderation. Keine zeitlichen Prognosehorizonte. |
| [sklearn-Integration](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/examples/scikit_learn_integration.ipynb) | Künstliche Klassifikation und Regression | Modell- und Pipeline-Integration. |

Der Trainingspfad erzeugt Holdouts mit `train_test_split`; Cross verwendet intern `StratifiedKFold` für Klassifikation beziehungsweise `KFold` für Regression. `shuffle` ist konfigurierbar. Eine öffentliche Übergabe von Gruppen-IDs oder eines beliebigen Gruppen-/Zeit-Splitters ist hier nicht vorhanden. Das ist eine Quellcodefeststellung, keine aus Datensatznamen abgeleitete Einschränkung. [Split-Erzeugung](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L669-L782)

Manuell übergebene Kalibrierungs- und Test-Scores ermöglichen die Anwendung nach extern vorbereiteten Aufteilungen. Dadurch entsteht weder automatisch eine Prüfung von Personen-/Maschinenüberschneidungen noch eine zeitliche Gültigkeitsgarantie. [Manueller Kern](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L501-L565)

## Primärliteratur

| Quelle | Konkrete Aufgaben | Tatsächlicher Versuchs-/Verfahrensaufbau |
|---|---|---|
| [Vovk & Petej: Venn–Abers Predictors, 2014, §5](https://arxiv.org/pdf/1211.0025) | Australian Credit, Breast Cancer, Diabetes, Echocardiogram, Hepatitis, Ionosphere, Labor Relations, Liver Disorders und Congressional Voting | Binäre Benchmark-Klassifikation. Zufällige Permutation, zwei Drittel Training und ein Drittel Test. Medizinische Datensätze belegen hier keinen longitudinalen Patientenablauf. |
| [Vovk, Petej & Fedorova: Large-scale probabilistic predictors with and without guarantees of validity, 2015, §6](https://proceedings.neurips.cc/paper/2015/file/a9a1d5317a33ae8cef33961c34144f84-Paper.pdf) | Adult-Klassifikation | Originaler Train/Test-Split; innerhalb des Trainings zusammenhängende Fold-Blöcke beziehungsweise erster Block als Modelltraining und Rest als Kalibrierung. „Zusammenhängend“ bezeichnet Zeilenpositionen; ein zeitlicher Forecast-Horizont wird damit nicht definiert. |
| [Manokhin: Multi-class probabilistic classification using inductive and cross Venn–Abers predictors, 2017, §4](https://proceedings.mlr.press/v60/manokhin17a/manokhin17a.pdf) | Bodenarten aus Satellitenbildern, Fahrzeugtypen aus Silhouetten, handgeschriebene Ziffern (MNIST), künstliche Wellenformen | Paarweise binäre Kalibrierung und Kopplung zu Mehrklassenwahrscheinlichkeiten. Train/Test- und zusätzliche Trainings-/Kalibrierungsaufteilungen; keine personen-, fahrzeug- oder zeitbasierte Resampling-Methode spezifiziert. Wellenformklassifikation ist hier keine Vorhersage zukünftiger Zeitpunkte. |
| [Johansson, Löfström & Sönströd: Well-Calibrated Probabilistic Predictive Maintenance using Venn-Abers, 2023, §3](https://arxiv.org/pdf/2306.06642) | Maschinenfehler erkennen: Temperatur, Drehzahl, Drehmoment, Werkzeugverschleiß und Qualitätsstufe; 10.000 Zeilen, 339 Fehler | Binär „Fehler/kein Fehler“; Entscheidungsbaum, Random Forest und XGBoost, mit logistischer Regression als Vergleich. Auswertung über gewöhnliche zehnmal zehnfache Kreuzvalidierung. Kein ausgewerteter Forecast „Ausfall in den nächsten N Stunden“ und kein beschriebener Leave-one-machine-out-Ablauf. |
| [Inductive Venn–Abers and related regressors, 2026, §§7–8 und Anhang B](https://arxiv.org/html/2605.06646v1) | Friedman-Aufgaben, lineare/nichtlineare Regression, heteroskedastisches und schwer-tailliges Rauschen, Ausreißer, Covariate Shift; außerdem Temperaturprognosekorrektur, Weinqualität, Tragflächenlärm und Schülerleistung | CVAR mit zehn Folds: jeweiliger Fold zur Kalibrierung, alle anderen zum Basismodelltraining. Synthetische Benchmarks grundsätzlich unabhängig gezogen, explizite Ausnahme der gleichen Verteilung beim Covariate-Shift-Szenario; zufällige 80/20-Splits beschrieben. Die reale Temperaturprognose-Aufgabe belegt fachlichen Zeitbezug, aber keine spezielle Rolling-origin-/Gruppenmethode. |

Die zusätzlich vom Python-README verlinkte Arbeit [Generalized Venn and Venn-Abers Calibration with Applications in Conformal Prediction, §§2.1, 3.3, 4.2 und 5](https://arxiv.org/html/2502.05676v3) behandelt tatsächlich Subpopulationen: Venn-Multikalibrierung sowie Quantil-/Conformal-Verfahren. Ihre Experimente verwenden unter anderem MEPS, Concrete, Community, STAR, Bike und Bio mit zufälligen 50/30/20-Aufteilungen. Das ist eine andere Bedeutung von „Gruppen“ als Resampling nach Personen- oder Maschinen-ID. Diese Literaturerweiterung ist nicht dadurch als Funktion des gepinnten `ip200/venn-abers` belegt, dass das README sie verlinkt; die Arbeit verwendet IID-Kalibrierungsdaten unabhängig vom Modelltraining.

## Reichweite der Garantien

Das Grundlagenpaper formuliert die Kalibrierungsaussage unter IID-Beobachtungen; im Beweis wird die Permutationssymmetrie der Beobachtungen verwendet. Sie betrifft einen geeigneten Selektor aus den beiden Venn-Wahrscheinlichkeiten. Sie ist keine pauschale Garantie für beliebige zeitabhängige oder geclusterte Zeilen und auch keine individuelle Konfidenzintervall-Aussage. [2014, Theorem 1](https://arxiv.org/pdf/1211.0025)

Das IVAP-Paper macht die IID-Bedingung in Proposition 1 ausdrücklich. Die Übertragung auf CVAP wird empirisch diskutiert; das Zusammenführen zu einer einzelnen Wahrscheinlichkeit verliert die theoretische perfekte Kalibrierung. [2015, Abstract, §1 und Proposition 1](https://proceedings.neurips.cc/paper/2015/file/a9a1d5317a33ae8cef33961c34144f84-Paper.pdf)

Das Regressionspaper setzt ebenfalls IID voraus. Die IVAR-Aussage betrifft Regressionserwartungen moderierter Labels; sie ist kein gewöhnliches Vorhersageintervall mit garantierter Coverage für den nächsten Messwert. Für die untersuchten CVAR-Punktprädiktoren wird ausdrücklich keine formale Gültigkeitsgarantie beansprucht. [2026, §§2, 4 und 8](https://arxiv.org/html/2605.06646v1)

## Folgerung für die Abgrenzung

Die Quellen belegen viele fachliche Aufgaben, einschließlich Wartung und Temperaturprognosekorrektur. Der gemeinsame Funktionsumfang ist Kalibrierung vorhandener Modellvorhersagen für binäre Klassifikation, Mehrklassenklassifikation und Regression samt Holdout-/Cross-Abläufen. Eine Gruppen- oder Zeitabhängigkeit im Anwendungsgebiet macht daraus noch keinen spezialisierten Gruppen-/Zeitreihenalgorithmus.

Für die Paritätsprüfung sind damit bestehende Optionen, externe Score-Eingaben und identische vorgegebene Splits maßgeblich. Eigene Rolling-origin-, Horizon-, Gap-, GroupKFold- oder Online-Update-Verfahren wären eine gesonderte Erweiterung, soweit sie über die belegten Referenzpfade hinausgehen. Diese Recherche behauptet keine Vollständigkeit über die gesamte Venn-/Conformal-Literatur; geprüft wurden die oben benannten Grundlagen, das Regressionspaper und das unmittelbar einschlägige Wartungsbeispiel.
