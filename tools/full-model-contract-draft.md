# Vollmodell-Übertragung und paarweises Training — Vertragsentwurf

Stand: 2026-09-07. Für [Vollmodell-Alternative für vollständige Python-Parität festlegen](https://github.com/RMKruse/venn-abers/issues/11).

**Status:** Umfang, ausdrückliche Moduswahl, zusätzliche paarweise Trainingsfähigkeit und eigenständige Vollmodell-Parameterwahl sind im Live-Gespräch bestätigt. Dieser Entwurf konkretisiert außerdem Aufrufe, Aufteilungen, Aufbewahrung, Aggregation, Tuning und Abnahme. Diese Konkretisierungen stehen zur gemeinsamen Schlussentscheidung; das Ticket ist noch nicht aufgelöst. Keine Produktimplementierung.

## 1. Umfang und Begriffe

Bis v1.0 werden die folgenden fünf Wege jeweils **Inductive und Cross**, jeweils mit **passenden Modellen oder Vollmodell-Übertragung**, unterstützt: insgesamt 20 Verfahrenskombinationen.

| Modell-/Kalibrierungsweg | Vorhersagemodelle bei Vollmodell-Übertragung | Einordnung |
|---|---|---|
| Binäre Klassifikation | Ein Modell auf dem gesamten lokalen Fit-Bestand | Python-Fähigkeit |
| Gemeinsames Multiclass-Modell, OvO-Kalibrierung | Ein Modell für alle Klassen | Bewusster zusätzlicher R-Weg |
| Gemeinsames Multiclass-Modell, OvR-Kalibrierung | Ein Modell für alle Klassen | Bewusster zusätzlicher R-Weg |
| Paarweises binäres Modelltraining, OvO | Ein Modell je Klassenpaar auf dessen vollständigem lokalen Bestand | Trainierter Python-OvO-Weg |
| Moderierte Regression | Ein Regressionsmodell auf dem gesamten lokalen Fit-Bestand | In der unteren Python-Klasse verfügbar; über die dortige Regressionsfassade nicht wählbar |

„Voll“ bezieht sich ausschließlich auf den aktuellen zulässigen Fit-Bestand beziehungsweise dessen Klassenpaar. Es umfasst niemals äußere Assessment-/Testdaten oder einen nach dem Tuningvertrag separat gehaltenen Auswahlanteil. Im Inductive-Fall enthält dieser Bestand auch die für den Quellkalibrator gehaltenen Kalibrierungsbeobachtungen.

**Passende Modelle** bleiben Standard. **Vollmodell-Übertragung** ist die ausdrücklich gewählte Anwendung bestehender Kalibratoren auf Vorhersagen eines anders trainierten Modells. Sie ist weder gewöhnliche Inductive-Kalibrierung noch der passende Cross-Fold-Verbund. Ein nachträglicher Moduswechsel am gefitteten Objekt ist nicht vorgesehen.

Der bisherige gemeinsame Multiclass-Weg bleibt erhalten. Paarweises Training ist eine eigene Option, keine neue Bedeutung des bisherigen `classification="ovo"`. Es gibt keine Zusage eines zusätzlichen separat trainierten OvR-Modellverbunds.

## 2. Geplante Bedienung und Aufteilungen

Die bestehende geplante Integration wird um zwei feste Konstruktionsoptionen erweitert:

```r
# Geplante vennabers-API; noch nicht implementiert.
va <- calibrated_workflow(
  base, outcome = "truth", method = "cross", classification = "ovo",
  model_training = "pairwise", prediction_model = "full",
  v = 5, seed = 42, loss = "log"
)
fitted <- generics::fit(va, data = development)
predict(fitted, new_data, type = "prob")
venn_abers_details(fitted, new_data)
```

- `prediction_model`: exakt `"matched"` (Standard) oder `"full"`, in allen 20 Kombinationen. Dies ist eine Fit-Konfiguration, kein Predict-Schalter. Die gespeicherte Konfiguration gilt auch bei `fit_resamples()` und `last_fit()`.
- `model_training`: für Multiclass exakt `"shared"` (Standard) oder `"pairwise"`. `pairwise` verlangt `classification="ovo"` und einen geeigneten binären Basis-Workflow. Bei binären und Regressionsaufrufen wird diese Multiclass-Option nicht ausdrücklich gesetzt; irrelevante explizite Optionen werden wie bisher abgewiesen.
- `method`, `classification`, Loss/Rundung, Moderation und `tuning` folgen den bereits beschlossenen Verträgen. Inductive/Cross, gemeinsames/paarweises Training und passend/Vollmodell bleiben je Suchlauf fest. Ein Verfahrensvergleich verwendet vollständige Läufe und eine eigene unabhängige Bewertung.
- Es gibt keine automatische Wahl des Vollmodell-Modus nach Datenmenge, Speicher oder Modellfehlern. Ungültige Werte und widersprüchliche Optionen scheitern vor Modelltraining.

**Gemeinsamer Weg:** Bestehende automatische beziehungsweise explizite lokale Aufteilungen bleiben unverändert: Inductive ein disjunkter, vollständiger Trainings-/Kalibrierungssplit; Cross eine einfache Partition mit genau einem gehaltenen Fold je Beobachtung und Training auf dem jeweiligen Komplement.

**Paarweiser Weg:** Klassenuniversum und Reihenfolge werden vor dem Zerlegen fixiert. Paare werden in dieser Reihenfolge gebildet, die jeweils spätere Klasse ist das binäre Ereignis. Jedes Paar verwendet ausschließlich seine beiden Klassen, wobei die ursprünglichen Klassenidentitäten in der Diagnose erhalten bleiben. Paarweise Basis-Workflows erhalten einen Faktor mit genau diesen beiden Levels.

Automatische Splits werden **nach** dem Filtern auf das Paar gebildet, mit den bisherigen lokalen Anteils-/Foldvorgaben und eigener reproduzierbarer Zufallssteuerung pro Paar. Es wird kein globaler Multiclass-Foldplan als numerisch gleicher Python-Paarplan ausgegeben.

`splits` kann im Paarweg eine Funktion `function(data)` sein, die für den jeweiligen aktuellen Paarbestand einen gültigen lokalen `rsplit`/`rset` erzeugt. Alternativ ist beim direkten Fit eine benannte Liste solcher Paarpläne erlaubt. Stabile Schlüssel `pair_1`, `pair_2`, … werden in einer Tabelle auf die gespeicherten Klassenpaare abgebildet; kein fehleranfälliges Zusammenkleben von Klassennamen. Die Liste enthält genau alle benötigten Paare. Beim äußeren Resampling müssen die Pläne zu den dortigen lokalen Daten passen; ein Plan für den gesamten Entwicklungsbestand reicht nicht.

Jeder Paarplan erfüllt seinen eigenen vollständigen Inductive-/Cross-Vertrag. Beobachtungen dürfen in mehreren verschiedenen Klassenpaaren vorkommen; innerhalb eines Cross-Paars gehört jede Beobachtung genau einem Kalibrierungsfold an. Fold-IDs sind nur zusammen mit der Paar-ID eindeutig. Es ist keine Zuordnung „Fold 1“ zwischen verschiedenen Paaren erforderlich. Explizite gültige Paarpläne dürfen unterschiedliche Foldzahlen besitzen; automatische Pläne verwenden das konfigurierte `v` je Paar.

Für das paarweise Inductive-Verfahren muss jede der beiden Klassen im Kalibrierungsbestand des Paars vorkommen; dies führt die bisherige Multiclass-Klassenregel fort. Nichtleere einseitige Cross-Teilkalibrierungen bleiben zulässig, sofern die Engine auf dem zugehörigen Trainingsanteil fitten und das geforderte Wahrscheinlichkeitsschema liefern kann. Keine still übersprungenen Paare/Folds, keine automatische Verringerung der Foldzahl und kein Ersatzmodell nach einem Fitfehler. Explizite Planidentität, reservierte Namen und zusätzliche Basis-Postprocessoren bleiben dem vorhandenen Sonderfallticket zugeordnet.

## 3. Training, Preprocessing und Aufbewahrung

Sei `F` der zulässige lokale Fit-Bestand, im Paarweg `F_ab` dessen Ausschnitt für ein Klassenpaar.

1. **Kalibrierungsquellen:** Inductive trainiert einen vollständigen Basis-Workflow auf `T`, hält `C` vollständig von dessen Auswahl und Training fern und erzeugt damit die Kalibrierungsvorhersagen. Cross wiederholt dies mit `T_f = F ohne C_f`. Im Paarweg gilt derselbe Ablauf separat innerhalb `F_ab`.
2. **Kalibratoren:** Die gehaltenen Vorhersagen und zugehörigen Wahrheitswerte erzeugen genau die bisherigen getrennten Inductive-/Fold-Kalibratoren. Rundung betrifft ausschließlich Klassifikations-Kalibrierungswahrscheinlichkeiten. Bei Regression bleiben die asymmetrisch moderierten unteren/oberen Kalibrierungen und wirksamen Fold-Parameter erhalten. Keine gepoolte OOF-Kalibrierung, keine Neukalibrierung auf In-sample-Vorhersagen des Vollmodells.
3. **Zusätzliches Vollmodell:** Nur bei `prediction_model="full"` wird ein vollständiger Basis-Workflow auf ganz `F` beziehungsweise je `F_ab` gefittet. Seine Recipe lernt alle trainierbaren Schritte auf genau diesem Bestand neu. Sie übernimmt keine geschätzte Skalierung, Imputation oder Merkmalsauswahl eines Fold-Modells. Das Vollmodell darf Kalibrierungsbeobachtungen einschließen, aber keine außerhalb seines Fit-Bestands liegenden Daten.
4. **Neue Beobachtungen:** Im passenden Modus liefert jedes gespeicherte Quellmodell die zu seinem Kalibrator gehörige Vorhersage. Im Vollmodell-Modus wird dieselbe Vollmodell-Vorhersage in alle zugehörigen Kalibratoren eingesetzt. Bei gemeinsamem Multiclass werden Klassen-/Paarwahrscheinlichkeiten wie bisher aus der Klassenmatrix abgeleitet; bei paarweisem Training kommen sie direkt aus dem binären Paarmodell.

**Dauerhafter Zustand:** Im passenden Modus bleiben alle für Predict benötigten Quellmodelle samt Recipe und Kalibratoren gespeichert. Im Vollmodell-Modus bleiben die Vollmodelle samt Recipe, alle Kalibratoren, gehaltenen Kalibrierungsvorhersagen/Wahrheitswerte, Aufteilungs- und Klassenidentitäten, Parameter, Suchprotokolle, Seeds und Versionen erhalten. Die nur zur Erzeugung der Kalibrierungsvorhersagen benötigten Quellmodelle werden nach erfolgreichem Aufbau verworfen; kein zusätzlicher Aufbewahrungsschalter im ersten Vertrag. Aus den gespeicherten Kalibrierungsvorhersagen kann die Kalibrierung nachvollzogen werden. Eine erneute Anwendung der verworfenen Modelle erfordert erneutes Training und gehört nicht zu Predict.

Der Fit liefert erst nach erfolgreichem Aufbau aller benötigten Komponenten ein gültiges Objekt. Predict trainiert weder Modelle noch Recipes noch Kalibratoren neu. Für einen Batch werden Modellvorhersagen pro tatsächlich benötigtem Modell einmal berechnet und innerhalb des Aufrufs wiederverwendet. Das Ergebnis darf bei deterministischen Engines nicht von Batchgröße oder anderen mitgelieferten Zeilen abhängen. Es wird kein persistenter Prediction-Cache eingeführt.

**Aufwand ohne Tuning:** Inductive benötigt passend einen, bei Übertragung zwei Basisfits; Cross mit K Folds passend K, bei Übertragung K+1. Bei P Paaren gilt die Summe dieser Kosten über alle Paare. Drei Klassen und fünf Folds bedeuten im Paarweg 15 beziehungsweise 18 Fits; für Vollmodell-Predict werden anschließend drei Modelle gebraucht. Überflüssige vorgelagerte Fits des Python-Wrappers werden nicht nachgebaut. Die Ersparnis betrifft insbesondere Aufbewahrung und Modellvorhersagen, nicht die nötige Erzeugung gehaltener Kalibrierungsvorhersagen. Tuning vervielfacht den Aufwand entsprechend seinem bestehenden Budgetvertrag.

## 4. Einbindung in den bestätigten Tuningvertrag

Gemeinsame und zweistufige Auswahl, Grid und kontrollierte Bayes-Suche bleiben unterstützt. Feste Modell-/Recipe-Parameter werden übernommen. Bei Suche erhält jedes Vollmodell eine eigene lokale Parameterwahl nach derselben konfigurierten Suchregel; keine Übernahme oder Mittelung ausgewählter Fold-Parameter.

Die endliche Verschachtelung der bereits angenommenen Bausteine A bis D wird wie folgt ergänzt:

- **A, feste Einstellungen:** Baut bereits das gewählte Verfahren, einschließlich Vollmodell-Übertragung und gemeinsamem/paarweisem Trainingsweg. Alle Modellparameter sind fest; es gibt keine weitere Suche. Dieser Baustein beendet weiterhin die Verschachtelung.
- **B, lokale Modellwahl:** Resamples stammen ausschließlich aus dem zulässigen Trainingsbestand des jeweils auszuwählenden Modells. Gemeinsam werden Kandidaten anhand kalibrierter Vorhersagen eines A-Fits mit dem gewählten passend/Vollmodell-Modus bewertet; zweistufig zunächst anhand unkalibrierter Basisvorhersagen. Im Paarweg erfolgt diese lokale Auswahl binär auf dem jeweiligen Paar; die Bewertung des gesamten Multiclass-Verfahrens erfolgt erst nach vollständiger Kopplung. Das gewählte Basismodell wird anschließend auf dem ganzen jeweiligen lokalen Trainingsbestand gefittet.
- **C, vollständiger Fit bei festen gemeinsamen Kalibrierungsoptionen:** B wird getrennt auf jedem Kalibrierungsquell-Trainingsanteil ausgeführt. Zusätzlich wird B für jedes Vollmodell auf dem gesamten zulässigen lokalen Fit-Bestand ausgeführt. Die Vollmodellwahl beeinflusst nicht rückwirkend die Quellmodellwahl oder gehaltenen Kalibrierungsvorhersagen. Die dort gewählten Parameter dürfen von allen Fold-Parametern abweichen.
- **D, gemeinsame Optionen:** Bewertet vollständige C-Fits mit genau der gewählten Modellzuordnung und gegebenenfalls vollständiger Multiclass-Kopplung. Gemeinsame Kalibrierungsoptionen gelten für alle Paare/Folds. Auswahl auf `S`, erneuter finaler Ablauf auf dem getrennten `F` und Verbot der Rückführung von `S` gelten unverändert. „Vollmodell“ bedeutet beim endgültigen Fit ganz `F`, niemals `S + F`.

Der gemeinsame Weg darf bei gleicher Datenbasis seine Modellwahl abhängig von der Kalibrierungskonfiguration treffen. Im zweistufigen Weg bleibt die unkalibrierte erste Auswahl bei identischer Konfiguration und Seeds davon unabhängig. Die Suche für das Vollmodell verwendet dieselben konfigurierten lokalen Budgets; die zusätzliche Suche wird in Aufwand und Diagnose ausdrücklich gezählt. Suchfehler, unvollständige Kandidaten, Bayes-Steuerung, Parallelität und Zufallsidentitäten folgen dem bestehenden strengen Vertrag. Nur eine Ebene wird gleichzeitig parallelisiert.

Äußere Bewertung baut den vollständigen Ablauf einschließlich Vollmodell und aller inneren Such-/Kalibrierungsschritte erneut ausschließlich innerhalb des äußeren Trainingsanteils auf. `last_fit()` führt keinen zusätzlichen unkalibrierten Refit auf zusammengeführten Auswahl-/Testdaten durch. Ein späterer Vergleich passend/Vollmodell ist eine Verfahrensauswahl, kein folgenloser Predict-Schalter.

## 5. Aggregation und Ausgaben

Die Modellquelle ändert sich, die bereits beschlossenen numerischen Regeln bleiben gleich:

- Binär: Inductive Log- oder Brier-Regularisierung. Cross stabile gleichgewichtete Log-Zusammenführung der Fold-Endpunkte beziehungsweise gleichgewichteter Brier-Merger; kein Pooling und kein Ersatz durch Mittelung der Log-Punktwerte.
- Multiclass: zuerst je Paar/Klasse die binäre Regularisierung beziehungsweise Fold-Zusammenführung, dann reziproke OvO-Kopplung oder OvR-Normierung. Beim Paarweg werden die jeweiligen Paar-Folds unabhängig aggregiert, bevor die Paare gekoppelt werden. Keine Mittelung fertiger Multiclass-Fold-Vorhersagen.
- Regression: vollständiger gewichteter Punktmerger je Kalibrator/Fold einschließlich bestätigter Nullgewichtsregel; bei Cross Punkt, Untergrenze und Obergrenze jeweils separat gleichgewichtet mitteln. Moderation, Skalierungstoleranzen und konstante Sonderfälle bleiben unverändert.

Native `.pred_*`, `.pred_class` beziehungsweise `.pred`-Ausgaben, gespeicherte Klassenordnung, Ereignis- und Gleichstandsregeln bleiben erhalten. Ungeordnete geometrische Aggregate werden nicht als Intervallgrenzen ausgegeben.

`venn_abers_details()` ergänzt den bisherigen Diagnosevertrag um gespeicherten Vorhersagemodus, Trainingsweg und explizite Modellquelle. Beim Paarweg bezeichnet die Kombination aus Paar-ID und Fold-ID den Kalibrator; die Vollmodell-ID bezeichnet seine neue Vorhersagequelle. Ereignisklasse und ursprüngliche Klassennamen bleiben sichtbar. Die binären Endpunkte und Punktwerte müssen die endgültige Aggregation rekonstruieren lassen. Regression zeigt entsprechend Fold-Punkte/-Grenzen und beschreibende Aggregate. Null/eine Zeile behalten sämtliche Schemata.

Print und Dokumentation nennen die Vollmodell-Übertragung ausdrücklich. Es werden weder `conf_int` noch `pred_int` dafür registriert. Das Ausgeben von Endpunkten behauptet keine automatische Übertragung der ursprünglichen statistischen Aussagen.

## 6. Referenz, Aussagegrenzen und bereits ausgeführte Prüfung

Referenz ist Python venn-abers 1.5.4, Quellcommit `0e7b4bc575ce230134576ba1c76688d46bf99ac7`, SHA-256 der Implementierungsdatei `ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`.

- [Öffentliche Exporte](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/__init__.py): Auch VennAbersCV ist exportiert.
- [Fit und Modellzuordnung](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L639-L837): Python trainiert Voll- und Quellmodelle, speichert gehaltene Kalibrierungswerte und entscheidet über cv_ensemble, welches Modell neue Wahrscheinlichkeiten liefert; auch Inductive erreicht diesen Zweig.
- [Untere Regression](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L839-L887) und [Fassade](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L1462-L1530): unten wählbar; die Fassade reicht cv_ensemble nicht durch.
- [Paarweises Training und Kopplung](https://github.com/ip200/venn-abers/blob/0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py#L986-L1099): eigene Trainingsdomäne je Klassenpaar.

Die beigefügte [ausführbare Referenzprobe](full-model-reference-probe.py) bestand mit NumPy 2.5.3 und scikit-learn 1.9.0 in 20 Fällen. Geprüft wurden die öffentlichen Klassen über das Paket-Exportmodul, der Quellhash, gehaltene Kalibrierungsvorhersagen, separat gelernte StandardScaler-Mittelwerte, Modellzuordnung, binäre Log-/Brier-Formeln und Endpunkte, paarweise Vollmodell-Domänen, endliche Regressionsausgaben und die feste Ensemble-Vorgabe der Regressionsfassade.

Aufruf in einer Umgebung mit venn-abers 1.5.4, NumPy, pandas und scikit-learn: `python tools/full-model-reference-probe.py`. In dieser Sitzung wurden die vorhandenen Abhängigkeiten und ein Paketimport des unveränderten versionierten Quellstands verwendet. Python erzeugte dabei interne `All-NaN slice encountered`-Warnungen in seiner Gradientenberechnung; die geprüften Ausgaben waren endlich und alle Assertions bestanden. Es wurde keine Warnungsfreiheit behauptet.

Diese Probe ist weder eine R-Implementierung noch eine vollständige statistische Validierung. Insbesondere ist sie kein Beleg für die Übertragung einer Kalibrierungs- oder Coverage-Garantie auf ein anders trainiertes Modell. Numerische Parität bedeutet gleiche Ergebnisse bei festgehaltenen vergleichbaren Eingaben, Modellen und Splits; gleiche Seeds über Python/R hinweg reichen dafür nicht. Native R-Objekte, strengere Validierung, einmaliger Kalibrator-Fit, keine unnötigen Basisfits und kompakte Aufbewahrung sind bewusste Unterschiede zur Referenz.

Die bestehenden statistischen Aussagen werden nur mit ihren jeweiligen Voraussetzungen dokumentiert. Für Vollmodell-Übertragung werden keine pauschale Kalibrierung, nominelle Coverage oder stets bessere Güte zugesagt. Bei einer später gewünschten positiven Garantie ist zunächst eine eigene, auf dieses konkrete Verfahren und seine Annahmen gerichtete Research-Frage erforderlich. Für den hier ausdrücklich begrenzten numerischen Verfahrensvertrag ist keine solche Garantie Voraussetzung.

## 7. Verbindlich vorgeschlagene Implementierungsabnahme

1. **Unterstützungsmatrix:** Alle 20 Kombinationen laufen über `fit()`, Standard-Predict, Details und äußere Bewertung. Klassifikation zusätzlich Log/Brier und die beschlossenen Rundungsvarianten; Regression `m`/`epsilon`. Zwei bis vier Klassen, minimale zulässige und ungleiche Kalibrierungsgrößen, automatische und explizite lokale Paarpläne abdecken. Für alle Wege beide Tuningstrategien mit Grid/Bayes und festen Teilmengen prüfen.
2. **Numerik:** Feste Kalibrierungswerte, neue Modellvorhersagen und exakte Split-/Paaridentitäten verwenden. Fehlerfreie Python-Komponenten prüfen, bei gemeinsamem R-Multiclass eigenständige Rekonstruktion über die binären Referenzbausteine. Klassifikation maximal absolute Abweichung 1e-10; Regression `abs(actual-expected) <= 1e-10*s + 1e-10*abs(expected)` mit vorab dokumentierter positiver Zielskala s. Eigene Randfallregeln getrennt prüfen. Die hier ausgeführte Probe ersetzt diese R-Prüfung nicht.
3. **Unterschiedliche Modellquellen:** Ein deterministischer Testfall muss absichtlich unterschiedliche Voll-/Fold-Vorhersagen erzeugen und zeigen, dass beide Modi verschiedene Endergebnisse liefern. Gleichbleibende Kalibrierungsdaten/Konfiguration erzeugen dabei dieselben Kalibratoren. Eine vertauschte Modell-/Kalibrator- oder Paar-/Klassen-Zuordnung muss die Prüfung scheitern lassen. Ein gepoolter OOF-Kalibrator darf den erwarteten getrennten Ablauf nicht bestehen.
4. **Datenrollen:** Fits und Auswahl bis auf Beobachtungspositionen instrumentieren. Quellmodell und seine vollständige lokale Suche sehen ihren Kalibrierungsanteil nicht. Das Vollmodell darf ihn sehen und lernt seine Recipe auf dem ganzen erlaubten Bestand neu. Ein extremer ausschließlich dortiger Prädiktor darf die Quell-Recipe nicht, die Vollmodell-Recipe dagegen sehr wohl verändern. Mutationen ausschließlich äußerer Assessment-/Testziele ändern keine gefitteten Zustände oder Vorhersagen. Bei festen gemeinsamen Optionen bleibt der Vollmodell-Fit von einem separat gehaltenen Auswahlanteil unberührt.
5. **Tuning:** Eigene Vollmodellparameter und Paar-/Foldparameter samt Suchdaten nachvollziehen; unterschiedliche Ergebnisse zulassen. Auswahl bewertet bereits die konfigurierte Übertragung und finale Fits wiederholen dieselbe Regel. `S` darf nicht in `F` zurückgeführt werden. A beendet die Verschachtelung ohne Suche. Fehler-/Budget-/Bayes-Negativkontrollen des bestehenden Vertrags auch in der zusätzlichen Vollmodellsuche ausführen; kein Rückfall auf ein Fold-Modell nach Vollmodellfehler.
6. **Aufwand und Predict:** Fit-Zähler prüfen 1/2 für Inductive und K/K+1 für Cross, jeweils pro Modelltrainingsdomäne; Paarweg prüft die Summe. Predict zählt nur die tatsächlich gespeicherten benötigten Modelle, je Modell einmal pro nichtleerem Batch, und keinerlei fit/prep/Kalibrator-Fit. Für null Zeilen werden typisierte leere Ausgaben vor dem Engine-Aufruf erzeugt. Tuning-Aufwandsabschätzung umfasst die zusätzlichen Suchen und Fits.
7. **Zustand und Serialisierung:** Im passenden Modus sind alle benötigten Quellmodelle vorhanden, im Vollmodell-Modus nur die für Vorhersagen benötigten Vollmodelle plus vollständige Kalibrierungs-/Diagnosezustände. Entfernen der temporären Quellmodelle verändert keine Vollmodell-Predict-/Detailausgabe. RDS-Roundtrip im frischen Prozess mit geprüften R-Engines erhält Ergebnisse und Metadaten. Externe Pointer-/GPU-/Remote-Engines erhalten keine ungeprüfte allgemeine Portabilitätszusage.
8. **Pläne und Fehler:** Falsche Paarbestände, fremde/umgeordnete Daten, doppelte/fehlende Paar- oder Fold-IDs, unvollständige/überlappende Partitionen, nicht trainierbare Teilmodelle und ungültige Moderation scheitern nachvollziehbar. Kein Überspringen oder still verkleinerter Verbund. Eindeutige Klassen-/Paarzuordnung auch bei vertauschten Spalten und numerisch ähnlichen Klassennamen. Die besonderen reservierten Namensfälle werden mit dem gesonderten Namensvertrag geprüft.
9. **Ausgaben und Aussagen:** Alle Endvorhersagen lassen sich aus den Details mit der gespeicherten Konfiguration rekonstruieren. Klassenregel und Loss-Wechsel bleiben konsistent; neue Wahrscheinlichkeiten werden nicht durch Kalibrierungsrundung verändert. Grenzen und Print kennzeichnen die Übertragung ohne Coveragebehauptung. Null/eine Zeile und Batchinvarianz prüfen. Metriken bewerten Endvorhersagen nach den bestehenden yardstick-Konventionen.
10. **Integration und Kompatibilität:** Ausführbare Beispiele für passenden und Vollmodell-Modus, gemeinsamen und paarweisen Weg, direkte Fits, Tuning, `fit_resamples()` und `last_fit()` gegen das gebaute/installierte Package prüfen. Fehlgeschlagene äußere Fits bleiben sichtbar. Bestehende manuelle APIs, Beispiele und Kernprüfungen bestehen unverändert; optionale Installation und `R CMD check` auf den zugesagten Versionen bestehen. Keine Python-Laufzeit als R-Produktabhängigkeit.

## 8. Geordnete Umsetzung und verbleibende Zuständigkeiten

1. Bestehende Kalibrierungskerne und optionale Integration mit passenden Modellen als Basis; explizite Modellquelle und Metadaten ergänzen.
2. Vollmodell-Übertragung zunächst mit festen Einstellungen für Binär, gemeinsamen Multiclass-Weg und Regression verbinden; Kalibratoren bei Fit speichern, Zustand und Predict-Aufwand abnehmen.
3. Paarweise Trainingsdomänen, lokale Pläne und Klassenidentität auf den binären Ablauf aufsetzen; passende und Vollmodell-Modi sowie Kopplung abnehmen.
4. Tuning-Bausteine A bis D und Aufwand-/Fehlerdiagnose um zusätzliche Domänen und Vollmodellsuchen erweitern; zunächst Grid, danach die bestehende kontrollierte Bayes-Steuerung.
5. Vollständige Referenz-/Vertragsabnahme, Beispiele, Dokumentation und Paketprüfung abschließen.

Die erste Integration bleibt vorläufig v0.5 mit passenden Modellen; die hier beschlossenen zusätzlichen Fähigkeiten müssen bis v1.0 hinzukommen. Die endgültigen Zwischenversionen legt [Release-Reife und verbindliche Milestone-Zuschnitte festlegen](https://github.com/RMKruse/venn-abers/issues/7) fest.

[Kalibrierung bereits trainierter Modelle und Workflows festlegen](https://github.com/RMKruse/venn-abers/issues/12) bleibt eine eigene Entscheidung: Vollmodell-Übertragung nimmt einen ungefitten Basis-Workflow und führt Training aus; sie erlaubt keinen heimlichen Refit eines als eingefroren angebotenen Fremdmodells. [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen](https://github.com/RMKruse/venn-abers/issues/13) und [Namens- und Sonderfallgrenzen der nativen tidymodels-Integration entscheiden](https://github.com/RMKruse/venn-abers/issues/15) werden nicht durch diesen Entwurf stellvertretend aufgelöst.

Diese Sitzung entscheidet ausschließlich das Vollmodell-/Paarpfad-Ticket. Produktimplementierung, Veröffentlichung, Umsetzungstickets und die Auflösung anderer Planungsfragen gehören nicht zu diesem Entwurf.
