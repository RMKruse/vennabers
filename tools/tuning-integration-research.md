# Tuning-Integration: geprüfte Erweiterungspunkte und verbleibende Entscheidungen

Recherche vom 2026-09-07 für [Tuning des vollständigen kalibrierten Verfahrens bis v1.0 festlegen](https://github.com/RMKruse/venn-abers/issues/10). Planung und Schnittstellenproben, keine Implementierung der Venn-Abers-Tuning-Features.

## Ergebnis

Die vereinbarte gemeinsame beziehungsweise zweistufige Optimierung bleibt das Ziel. Öffentliche parsnip-/tune-Schnittstellen tragen die Parameterdurchleitung und gewöhnliche Grid-/Bayes-Aufrufe. Die strenge Behandlung unvollständiger Kandidaten erfordert zusätzliche Steuerung: Bei Grid genügt eine Vollständigkeitsprüfung vor der Auswahl; bei kontinuierlichem nativem Bayes werden unvollständige Kandidaten bereits vor der nächsten Suchentscheidung berücksichtigt. Ein ungeprüftes `tune_bayes()` mit nachträglicher Filterung erfüllt deshalb den bestätigten Vertrag nicht.

Die ausführliche [Fehler- und Bayes-Recherche](tuning-error-research.md) enthält versionierte Quellbelege, getestete Gegenbeispiele und die Grenzen einer öffentlichen Fortsetzung in einzelnen Iterationen. Das ist eine offene Integrationsentscheidung, keine stillschweigende Reduktion des zugesagten Umfangs.

## Parameterdurchleitung: tatsächlich ausgeführte Probe

Die [Parameterprobe](tuning-parameter-probe.R) verwendet eine künstliche parsnip-Engine, die zwei foldweise gefittete rpart-Workflows mittelt. Sie berechnet **keine Venn-Abers-Kalibrierung**. Die künstliche Rundungsoption wird nur durchgereicht und gespeichert; sie verändert in dieser Probe keine Regressionsergebnisse.

Ausgeführt unter R 4.6.1, tune 2.1.0, parsnip 1.6.0, workflows 1.3.0, dials 1.4.4, recipes 1.4.0, rsample 1.3.2 und yardstick 1.4.0:

- Ein eingeschlossener untrainierter Basis-Workflow enthält `step_pca(num_comp = tune("pc"))` und `decision_tree(cost_complexity = tune("cp"))`.
- Der äußere Workflow transportiert Rohdaten mit `add_variables()`. Explizite Engine-Parameter vertreten die beiden inneren Parameter; ihre ursprünglichen IDs bleiben in der öffentlichen Kandidatentabelle erhalten. `param_info` liefert die dials-Parameterobjekte.
- Eine eigene Update-Methode der Forschungs-Modellspezifikation nimmt die durch tune eingesetzten Werte entgegen. Ohne diese normale Modellerweiterung schlug die erste Probe an `update.default()` fehl.
- Der Engine-Fit setzt die Werte mit öffentlichem `finalize_workflow()` in den Basis-Workflow ein. Erst anschließend wird dieser innerhalb jedes jeweiligen Modelltrainingsanteils gefittet.
- Vier Kandidaten auf drei äußeren Resamples erzeugten alle 240 erwarteten Vorhersagen und zwölf extrahierbare Kandidatenzustände ohne Fehler. Pro Zustand wurden zwei innere Modelle aufbewahrt. Parameterwerte und tatsächlich gelernte Skalierungsmitten stimmten mit den zugehörigen Trainingsdaten überein.
- Die kategoriale Option `"none"` beziehungsweise eine Ziffernzeichenfolge wurde korrekt zu `NULL` beziehungsweise einer ganzen Zahl zurückübersetzt.
- Native `finalize_workflow()`- und `fit()`-Aufrufe sowie eine zusätzliche native Bayes-Iteration mit diesen numerischen, ganzzahligen und kategorialen Parametern bestanden.

Reproduktion bei vorhandenen Forschungspaketen:

```sh
Rscript --vanilla tools/tuning-parameter-probe.R
```

In der hier vorhandenen temporären Bibliothek:

```sh
R_LIBS_USER=/tmp/venn-tidymodels-lib \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/tuning-parameter-probe.R
```

Der Beleg deckt keine generische automatische Erkennung aller verschachtelten Parameter, kollidierende IDs, geteilte Recipe-Parameter-IDs, installierte Paketregistrierung, Workerprozesse, sämtliche Basisengines oder numerische VA-Parität ab. Er belegt auch noch keinen vollständigen verschachtelten Tuning-Ablauf. Diese Prüfungen müssen Teil der späteren Integrationsabnahme sein.

### Warum eine explizite Parameterabbildung nötig ist

Native Modellparameter-Erkennung arbeitet mit den Argumenten der Modellspezifikation; die Extraktion verbindet deren Namen und IDs mit tunable-Metadaten. Ein als Argument gespeicherter Basis-Workflow ist dadurch nicht automatisch eine transparente zweite Workflow-Ebene. `finalize_model()` ordnet Parameter-IDs Argumentnamen zu und ruft die Update-Methode auf. Eine eigene Engine kann deshalb explizite Stellvertreterwerte empfangen und damit den inneren Workflow über dessen öffentliche Finalisierung aktualisieren. Das wurde oben für je einen Modell- und Recipe-Parameter geprüft.

Quellen: [parsnip tune_args v1.6.0](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/tune_args.R), [tunable-Metadaten](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/tunable.R), [Parameterextraktion](https://github.com/tidymodels/parsnip/blob/82c45c12d735143923449194fab9c462dec5fcf7/R/extract.R), [tune-Finalisierung](https://github.com/tidymodels/tune/blob/4c74638b2b0d486dc12b39d037bbeb26326ad35c/R/finalize.R), [öffentliche Modellerweiterung](https://www.tidymodels.org/learn/develop/models/).

Die endgültige API muss Parameter-IDs, Quellen, Optionen und gewählte Werte sichtbar halten; eine Recipe wird nicht in den äußeren Datentransport verschoben. Für die erste sichere Realisierung wird keine Submodell-Wiederverwendung des vollständigen kalibrierten Prädiktors vorausgesetzt. Eine solche Optimierung braucht eigene Kandidaten-/Kalibrator-Zuordnungsprüfungen.

## Darstellung der Kalibrierungsparameter

Technischer Entwurf innerhalb des bestätigten Umfangs, noch keine öffentliche API:

- `loss`: kategoriale Werte `log` und `brier`; unveränderte gemeinsame Loss-/Aggregationsregeln. Die Hauptmetrik wird separat festgelegt.
- Rundung: feste Werte behalten den Kernvertrag `NULL` oder endliche ganze Zahl. In einem endlichen Suchraum können keine Rundung und konkret vorgegebene ganze Zahlen als kategoriale Werte mit eindeutiger Rückabbildung dargestellt werden. Kein `NA` oder unendlicher Zahlenwert als vermeintlich normale Präzision. Negative Präzisionen dürfen nicht durch einen numerischen Sentinel belegt werden. Die Probe belegt die kategoriale Technik, nicht die endgültigen öffentlichen Namen.
- `m`: ganzzahliger Parameter. Für jeden tatsächlich benutzten Kalibrierungsfold der Größe k gilt `1 <= m <= floor((k-1)/2)`.
- `epsilon`: alternative reelle Parametrisierung. Für jeden Kalibrierungsfold muss `floor(epsilon*(k+1)/2)` zulässig sein. Ein allgemeines Intervall `(0,1)` allein reicht nicht. Angeforderte und wirksame Werte bleiben getrennt gespeichert.
- Domänen dürfen ausschließlich anhand der für den jeweiligen Suchlauf zulässigen lokalen Daten und Pläne bestimmt werden. Künftige äußere Bewertungsdaten und der abschließende Test sind keine Quelle für Datenabhängigkeiten. Die endgültigen Kalibrierungspläne müssen separat validiert werden; Werte werden nicht still gekappt oder ersetzt.
- Inductive/Cross, OvO/OvR, Kalibrierungsanteil und Foldzahl bleiben gemäß Nutzerentscheidung innerhalb eines Suchlaufs fest.

Dials stellt öffentliche quantitative und qualitative Konstruktoren sowie datenabhängige Finalisierung bereit. Ob ein konkreter Suchraum alle verschachtelten Kalibrierungsgrößen abdeckt, ist eine zusätzliche vennabers-Vertragsprüfung. [Offizielle dials-Anleitung](https://www.tidymodels.org/learn/develop/parameters/), [dials v1.4.4](https://github.com/tidymodels/dials/tree/472253aee3dd3434e80f844dfa460ca8c80ef341).

## Datenfluss: bestätigte Grenzen und offene Konkretisierung

Bestätigt sind zwei Wege: automatische gemeinsame Kalibrierungsoptionen werden auf einem separaten Entwicklungsanteil ausgewählt; bei vorgegebenen Optionen entfällt dieser zusätzliche Anteil allein für deren Auswahl. Die Zustimmung und ihre genaue Reichweite sind im [Entscheidungskommentar](https://github.com/RMKruse/venn-abers/issues/10#issuecomment-5568235503) festgehalten.

Der komplette Fit darf weder Ergebnisse noch gefittete Objekte aus der unabhängigen äußeren Bewertung übernehmen. Jeder äußere Bewertungsfold führt die gesamte Auswahl-/Fit-Prozedur auf seinem eigenen Trainingsanteil neu aus. Der abschließende Test wird erst nach Festlegung des Verfahrens verwendet. [Nested resampling](https://www.tidymodels.org/learn/work/nested-resampling/)

Die noch genau zu formulierende Kopplung zwischen gemeinsamer und lokaler Auswahl muss verhindern, dass ein auf dem Auswahlanteil bevorzugter **einzelner** Parametersatz bewertet, beim endgültigen Fit aber unbemerkt durch ein anders arbeitendes **Tuningverfahren** ersetzt wird. Kandidatenvergleich und finaler Fit müssen dieselbe vorher festgelegte Auswahlregel verwenden. Ein möglicher Entwurf ist, für jede gemeinsame Kalibrierungskonfiguration das vollständige Verfahren mit seiner lokalen Modell-/Recipe-Suche auszuwerten. Im gemeinsamen Weg bewertet die lokale Suche kalibrierte Vorhersagen; im zweistufigen Weg wählt sie das Basismodell zunächst anhand unkalibrierter Vorhersagen. Ob die genaue innere Bewertungsprozedur den jeweiligen Inductive-/Cross-Vertrag trägt, ist noch mit vollständiger Datenrollen-Probe zu prüfen.

Dies ist eine offene Präzisierung, keine zusätzliche bestätigte Nutzerentscheidung. Eine bloße Skizze `tune_grid(calibrated_workflow, ...)` beweist weder diese Verschachtelung noch die Übereinstimmung des ausgewählten und endgültig gefitteten Verfahrens.

## Grenzen dieser Sitzung

Belegt sind die Parameterweitergabe und konkrete native Fehlerszenarien. Ein vollständiger öffentlicher Aufrufvertrag, die Bayes-Fortsetzungssteuerung, abschließende Datenrollen-/Leakage-Abnahme und der Sonderfall einer reinen Loss-Auswahl bei bereits feststehenden Modellen sind noch offen. Die bestätigten beiden Tuning-Wege, Grid/Bayes, Parameterdomänen, Metriken, Budgets und Fehlerregeln werden nicht still reduziert. Das Planungsticket bleibt bis zur Klärung offen.
