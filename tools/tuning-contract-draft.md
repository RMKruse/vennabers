# Entwurf zur Abnahme: vollständige und zweistufige Tuning-Abläufe vor v1.0

Stand: 2026-09-07. Für [Tuning des vollständigen kalibrierten Verfahrens bis v1.0 festlegen](https://github.com/RMKruse/venn-abers/issues/10). Dieser Entwurf verbindet die bestätigten Entscheidungen mit den folgenden technischen Konkretisierungen. Er ist noch keine Resolution und beschreibt noch nicht implementierte Features. Die endgültige Release-Zuordnung bleibt der Release-Synthese vorbehalten.

## 1. Umfang

Binäre Klassifikation, Multiclass OvO/OvR und moderierte Regression erhalten jeweils Inductive und Cross. Zwei Tuning-Wege sind verbindlich:

- **Gemeinsam:** Die lokale Modell-/Recipe-Auswahl bewertet kalibrierte Vorhersagen. Automatisch gewählte gemeinsame Kalibrierungsoptionen werden durch den Vergleich des vollständigen Verfahrens einschließlich dieser lokalen Auswahl bestimmt.
- **Zweistufig:** Die lokale Modell-/Recipe-Auswahl bewertet zuerst unkalibrierte Vorhersagen und legt diese Einstellungen fest. Anschließend werden gemeinsame Kalibrierungsoptionen anhand vollständiger kalibrierter Vorhersagen ausgewählt. Die erste Stufe wird nicht nachträglich vom Ergebnis der zweiten Stufe verändert.

Das ist eine gekoppelte, geschachtelte Auswahl, kein einzelner flacher Parametervektor für sämtliche Cross-Fold-Modelle. Gemeinsame Kalibrierungsoptionen gelten für den Verbund; Modell-/Recipe-Einstellungen dürfen je Fold unterschiedlich sein. Im gemeinsamen Weg kann eine andere gemeinsame Kalibrierungsoption auch eine andere lokal gewählte Modellkonfiguration ergeben. Im zweistufigen Weg bleibt die lokale unkalibrierte Modellwahl bei gleicher Daten-/Seedkonfiguration davon unabhängig.

Alle tune-fähigen Modell-/Recipe-Parameter des unterstützten Basis-Workflows sind zugänglich. Klassifikation: Log/Brier und Rundungspräzision einschließlich keiner Rundung. Regression: `m` oder `epsilon`. Jede Option darf fest vorgegeben werden. Inductive/Cross, OvO/OvR, Kalibrierungsanteil und Foldzahl bleiben je Suchlauf fest; verschiedene Verfahren werden als vollständige Läufe auf denselben Auswahlaufteilungen verglichen. Eine unabhängige Bewertung bleibt von dieser Verfahrensauswahl getrennt.

Die hier konkretisierten Standardpläne betreffen den beschlossenen IID-Verbund passender Fold-Modelle. Gruppen-/Zeitpläne, eingefrorene Fremdmodelle, paarweise Python-Modellpfade und die Vollmodell-Alternative bleiben bei ihren eigenen Planungstickets; deren Beschlüsse müssen mit diesem Tuningvertrag abgeglichen werden, bevor der Gesamtumfang von v1.0 abgeschlossen wird. Kein dortiger Umfang wird durch dieses Ticket still ausgeschlossen.

## 2. Eindeutiger Daten- und Auswahlvertrag

`D` bezeichnet ausschließlich die Daten eines aktuellen Fits; ein äußerer Bewertungsanteil und der abschließende Test stehen diesem Fit nicht zur Verfügung. `lambda` steht für eine gemeinsame Kalibrierungskonfiguration, `theta` für Modell-/Recipe-Einstellungen.

### Baustein A: feste Einstellungen ohne weitere Suche

Für fest vorgegebene `theta` und `lambda` wird auf einem lokalen Datensatz der bereits beschlossene vollständige Inductive- beziehungsweise Cross-Prädiktor aufgebaut:

- Inductive: Modell-/Recipe-Fit auf Training, Kalibrator auf separater Kalibrierung.
- Cross: lokale Partition in Kalibrierungsfolds; je Fold Modell-/Recipe-Fit ausschließlich auf dessen Komplement, danach passende Kalibrierung und spätere Aggregation.

Dieser Baustein enthält keine automatische Modellwahl. Er beendet die Verschachtelung.

### Baustein B: lokale Modell-/Recipe-Auswahl

Für einen Modelltrainingsanteil `T` und eine feststehende `lambda` werden Auswahlresamples ausschließlich innerhalb von `T` gebildet.

- Gemeinsam: Jede Kandidatenkonfiguration `theta` wird auf dem Analysis-Anteil eines Auswahlresamples mit Baustein A einschließlich seiner eigenen inneren Kalibrierungsaufteilung aufgebaut. Ihre vollständigen kalibrierten Vorhersagen werden auf dem Assessment-Anteil dieses Auswahlresamples bewertet. Es gilt dieselbe Verfahrensfamilie, also Inductive oder Cross, wie in der Konfiguration.
- Zweistufig: Jeder Kandidat ist hier nur der unkalibrierte Basis-Workflow; er wird auf Analysis gefittet und auf Assessment bewertet.

Die strenge Vollständigkeitsregel wird vor Auswahl angewendet. Anschließend wird der gewählte Basis-Workflow mit `theta` auf ganz `T` neu gefittet. Die Auswahlresamples aus `T` sind keine späteren Kalibrierungsfolds dieses Basis-Modells. Wenn alle Modell-/Recipe-Parameter feststehen, entfällt die lokale Suche.

### Baustein C: vollständiger Prädiktor bei fester `lambda`

Auf einem Datensatz `A` wird die gewünschte Kalibrierungsaufteilung gebildet. Für jeden zugehörigen Modelltrainingsanteil `T_f` wird Baustein B angewendet; erst danach wird sein gespeichertes Modell auf dem getrennten Kalibrierungsanteil `C_f` kalibriert.

Bei Cross sind die `C_f` eine gemeinsame vollständige Partition von `A`, und `T_f = A ohne C_f`. `C_f` darf weder Baustein B noch dessen gelernte Vorverarbeitung beeinflussen. Gewählte `theta_f` dürfen verschieden sein. Vorhersagen verwenden ausschließlich die passenden gespeicherten Modelle, Preprocessoren und Kalibratoren. Es gibt keinen nachträglichen Ersatz durch ein Vollmodell.

### Baustein D: gemeinsame Kalibrierungsoptionen auswählen und final fitten

Wenn gemeinsame Kalibrierungsoptionen automatisch gesucht werden, wird `D` vorab in einen Auswahlanteil `S` und einen getrennten endgültigen Fit-Anteil `F` geteilt. Auf `S` werden Auswahlresamples erstellt. Für jede Kandidatenkonfiguration `lambda` wird Baustein C auf deren Analysis-Anteil neu ausgeführt und auf deren Assessment-Anteil bewertet.

Nach Auswahl von `lambda` wird Baustein C mit genau derselben lokalen Auswahlregel auf `F` erneut ausgeführt. Gewählte numerische Modellparameter können sich ändern, weil auf `F` andere Trainingsdaten vorliegen; die bewertete und endgültig angewendete Auswahlregel bleibt dieselbe. Weder Kandidatenmodelle noch deren Kalibratoren werden einfach übernommen. `S` fließt im einfachen Vertrag nicht in den endgültigen Fit auf `F` zurück.

Wenn gemeinsame Kalibrierungsoptionen vorgegeben sind, entfällt `S` allein für diese Auswahl, und Baustein C wird unmittelbar auf `D` ausgeführt. Andere erforderliche innere Auswahl-/Kalibrierungstrennungen bleiben bestehen.

### Unabhängige Bewertung und abschließender Test

`fit_resamples()` bewertet den gesamten trainierbaren Ablauf: pro äußerem Trainingsanteil wird Baustein D neu ausgeführt, einschließlich der dort nötigen Aufteilung `S/F`. Keine bereits auf allen Entwicklungsdaten gefundenen Einstellungen werden in die äußeren Trainingsanteile hineingetragen. Ein Vergleich verschiedener Verfahrenskonfigurationen anhand solcher Ergebnisse macht diese Ergebnisse zu Auswahlergebnissen; eine zusätzliche unabhängige Bewertung muss diesen Vergleich einschließen oder auf einem weiterhin unberührten Test erfolgen.

Der abschließende Fit führt Baustein D auf den Entwicklungsdaten durch. Erst danach werden Testvorhersagen und Testmetriken erzeugt. Änderungen ausschließlich an äußeren Assessment-Zielwerten beziehungsweise Test-Zielwerten dürfen die vorher erzeugten Modelle, ausgewählten Einstellungen und Vorhersagen nicht verändern.

### Aufteilungen und lokale Datenbindung

Automatische Pläne und gültige explizite lokale rsample-Pläne werden unterstützt. Auswahlresamples werden durch einen Provider `function(data)` aus den tatsächlich zulässigen lokalen Daten erzeugt oder als genau zu diesen Daten gehörige Objekte übergeben. Die bestehenden Regeln gegen fremde, umgeordnete oder mehrdeutige lokale Pläne gelten fort. Innere Cross-Kalibrierung ist eine einfache Partition; wiederholte äußere beziehungsweise Auswahl-CV ist davon zu unterscheiden.

Für den neuen Anteil `S` gibt es keinen stillen Standardprozentsatz: Bei automatischer gemeinsamer Kalibrierungssuche ist entweder `selection_prop` oder ein expliziter `selection_split` erforderlich. `selection_prop` ist der Anteil für `S`. Bei einem `selection_split` als `rsplit` bedeutet `analysis` den endgültigen Fit-Anteil `F`, `assessment` den Auswahlanteil `S`; diese Rollen werden in Diagnose und Dokumentation ausdrücklich benannt. Beide Angaben gleichzeitig sind ein Fehler. Die bestehenden Defaultwerte für Inductive-Kalibrierungsanteil und Cross-Foldzahl gelten innerhalb der jeweiligen lokalen Fits weiter, soweit die übergreifende Integrationsentscheidung nichts anderes festlegt.

## 3. Geplante Aufrufe

`calibrated_workflow()` bleibt der vorgesehene Konstruktor des vorherigen Integrationstickets. Er erhält zusätzlich `tuning = NULL` oder eine validierte Konfigurationsliste. `NULL` erhält den Ablauf mit festen Parametern. Die Konfigurationsliste beschreibt die zwei tatsächlich nötigen Suchaufgaben, ohne eigene Suchalgorithmen:

```r
# Geplante vennabers-Erweiterung; noch nicht ausführbare Produkt-API.
va <- calibrated_workflow(
  base, outcome = "truth", method = "cross", classification = "ovo",
  v = 5, seed = 42,
  loss = tune::tune("va_loss"),
  precision = tune::tune("va_rounding"),
  tuning = list(
    strategy = "joint",  # alternativ "two_stage"
    selection_prop = 0.3, # Beispiel, kein Default
    model = list(
      method = "grid", grid = model_grid, param_info = model_parameters,
      resamples = function(data) rsample::vfold_cv(data, v = 3),
      primary_metric = yardstick::mn_log_loss,
      control = tune::control_grid(save_pred = TRUE)
    ),
    calibration = list(
      method = "bayes", initial = 8L, iter = 20L,
      param_info = calibration_parameters,
      resamples = function(data) rsample::vfold_cv(data, v = 3),
      primary_metric = yardstick::mn_log_loss,
      control = tune::control_bayes(seed = 42, no_improve = 10L)
    )
  )
)

fitted <- generics::fit(va, data = development)
predict(fitted, new_data, type = "prob")
venn_abers_details(fitted, new_data)
venn_abers_tuning(fitted) # geplanter Diagnosezugang

assessment <- tune::fit_resamples(va, resamples = outer_folds)
# Der vollständig konfigurierte äußere Ablauf besitzt keine offenen
# äußeren Kandidatenparameter; seine Suchräume gehören zum inneren Fit.
final <- tune::last_fit(va, split = development_test_split)
```

`base` ist weiterhin ein untrainierter Basis-Workflow einschließlich ungefittem Preprocessing. Seine Tuning-IDs werden eindeutig Modell-/Recipe-Parametern zugeordnet. Die neue Konfiguration besitzt jeweils `method = "grid"` oder `"bayes"`; Grid nimmt `grid` als konkrete Tabelle oder Kandidatenzahl, Bayes `initial` und `iter`. `param_info` nutzt vorhandene dials-Objekte. Ein `report_metrics`-Metriksatz ist optional. Für feste Kalibrierungsoptionen entfallen deren `tune()`-Markierungen, `calibration`-Suche und `selection_prop`/`selection_split`. Für vollständig feste Modell-/Recipe-Einstellungen entfällt `model`.

Modell- und Kalibrierungsparameter werden während der Konstruktion in eine intern verwaltete Suchkonfiguration überführt. Die äußerste parsnip-Spezifikation repräsentiert danach einen vollständig konfigurierten **trainierbaren Auswahlablauf** und bietet native `fit()`, `fit_resamples()` und `last_fit()`-Aufrufe; sie darf keine versehentlich nach außen sichtbaren ungelösten Parameter enthalten. Die eigentlichen lokalen Suchen verwenden die anhand der Forschungsprobe belegten Parameter-Stellvertreter und native tune-Aufrufe. Eine direkt vom Nutzer ohne die vorgeschriebene Steuerung aufgerufene ununterbrochene `tune_bayes()`-Suche erhält dadurch nicht automatisch unseren strengen Fehlervertrag.

Die vorgeschlagene Konfigurationsform und der zusätzliche Diagnosezugang sind Teil dieses Abnahmeentwurfs, noch keine veröffentlichte Schnittstelle. Die Laufzeitprobe belegt die zentralen Parameter-/Fit-Seams; die vollständige paketregistrierte Orchestrierung und die native `last_fit()`-Integration stehen als Implementierungsabnahme aus. Der äußere `last_fit()`-Aufruf darf die internen Auswahl-/Kalibrierungsdaten nicht zusätzlich zu einem Vollmodell zusammenführen.

## 4. Parameter- und Metrikregeln

IDs müssen eindeutig sein; kollidierende Modell-/Recipe-/Kalibrierungs-IDs werden vor der Suche abgewiesen, nicht still umbenannt. Herkunft, ID und tatsächlich gewählte Werte bleiben sichtbar. Vorhandene Engines behalten ihre Grenzen; nicht unterstützte Modi, gelernte Recipes und gefittete Basis-Workflows werden im automatischen Eingang abgewiesen.

Rundung besitzt im Suchraum eine endliche kategoriale Darstellung, etwa `"none"`, `"0"`, `"2"`, `"-2"`, mit eindeutiger Rückabbildung auf den Kernvertrag. Es gibt keinen stillen unendlichen Suchbereich; der Nutzer legt die Kandidatenwerte fest. Feste Präzisionen bleiben `NULL` oder ganze Zahlen. `loss` ist kategorial `log`/`brier`. Regression weist diese Klassifikationsoptionen ab; `m` und `epsilon` schließen einander aus. Alle lokalen Kalibrierungsgrößen müssen die Moderationsdomäne erfüllen, einschließlich der zusätzlichen inneren Kalibrierungsfits. Keine automatische Kappung ungültiger Kandidatenwerte.

Pro Suche bestimmt eine vorab festgelegte Hauptmetrik die Auswahl: standardmäßig Log Loss für Klassifikation beziehungsweise RMSE für Regression. Beide Stufen dürfen verschiedene geeignete yardstick-Hauptmetriken verwenden. Zusätzliche Metriken sind Berichtswerte. Hauptmetrik, Richtung und Ereignisklasse werden explizit in Suche und Auswahl konsistent gehalten; Bewertungsmetrik und Kalibrierungsverlust bleiben unabhängig.

Die Suche berechnet ihre Hauptmetrik getrennt von den zusätzlichen Berichtsmetriken. Die notwendigen Vorhersagetypen werden erzeugt und für Vollständigkeitsprüfung beziehungsweise anschließende Auswertung verfügbar gehalten. Ein explizites `save_pred = FALSE`, das diese Prüfung verhindern würde, wird nicht still als kompatibel behandelt. Zusätzliche Metriken werden unabhängig voneinander ausgewertet; ihr Ausfall kann die gültige Hauptmetrik nicht zerstören. Bei Klassifikation können dafür zusätzliche Wahrscheinlichkeiten nötig sein, auch wenn die Hauptmetrik nur Klassen verwendet. Die bestehenden binären/Multiclass-Klassenregeln und yardstick-Konventionen gelten weiter.

Auswählbar sind nur Kandidaten mit vollständigen Vorhersagen und endlicher gültiger Hauptmetrik auf allen vorgesehenen Resamples. Die Prüfung vergleicht IDs und erwartete Assessment-Zeilen einschließlich Wiederholungen, nicht nur die Zahl vorhandener Metriken. Ein nachträgliches Weglassen schwieriger Folds oder Zeilen ist unzulässig. Bei exaktem Gleichstand entscheidet eine stabile Kandidatenreihenfolge: deklarierte Reihenfolge bei vorgegebenem Grid, protokollierte Generierungs-/Versuchsreihenfolge bei automatisch erzeugten Kandidaten. Es gibt keine nachträgliche zweite Auswahlmetrik.

## 5. Bayes, Budget und Reproduzierbarkeit

Grid verwendet native `tune_grid()`-Ergebnisse mit strenger Eignungsprüfung vor Auswahl. Bayes startet aus gültigen Initialergebnissen und wird öffentlich in einzelnen Iterationen fortgesetzt. Nach jedem Schritt werden unvollständige Kandidaten aus den an den nächsten GP übergebenen Ergebnissen entfernt. Genügen die gültigen Startkandidaten nicht für die native Bayes-Initialisierung, gibt es einen klaren Fehler mit den verfügbaren Diagnosen; keinen stillen Wechsel zu einem anderen Suchverfahren.

Globale Versuchszähler und Kandidatenidentitäten sind unabhängig von nativen `.iter`-Werten. Das Initialbudget und das Budget weiterer Vorschläge zählen auch erfolglose beziehungsweise wiederholt vorgeschlagene Kandidaten. Globale `no_improve`-Zähler steigen bei Versuchen ohne gültige strikte Verbesserung, einschließlich Fehlern und Gleichständen. Zeitgrenzen werden zwischen vollständigen Schritten geprüft; laufende Fits werden dadurch nicht hart beendet. Budgeterschöpfung mit gültigen Kandidaten liefert den besten gültigen Kandidaten und einen dokumentierten Abbruchgrund. Ohne gültigen Kandidaten endet die Suche mit Fehler. Scheitert der finale Fit, wird kein Ersatzkandidat oder verkleinerter Cross-Verbund verwendet.

Die Erstabnahme verwendet die gewöhnliche native Akquisitionsfunktion. Nicht sinnvoll durchreichbare native Steuerungen werden ausdrücklich erkannt: insbesondere wird ein endlicher nativer `uncertain`-Zähler nicht still übernommen, da Neustarts seinen Zustand zurücksetzen; der dokumentierte Ausgangswert ist `Inf`. Erweiterte Akquisitions-/Unsicherheitssteuerung benötigt einen eigenen geprüften Vertrag. `no_improve`, Seeds und Zeitlimit werden wie beschrieben global verwaltet, statt neu gestartete native Zähler als Gesamtzustand auszugeben.

Vor Beginn wird die Zahl der erwarteten beziehungsweise maximalen Basismodellfits aus den lokalen Suchbudgets und vollständiger Verschachtelung abgeschätzt. Die Anzeige unterscheidet Bruttoaufwand, mögliche Wiederverwendung und tatsächlich ausgeführte Fits; sie verspricht keine exakte Laufzeit. Beim zweistufigen Weg können identische erste Stufen über Kalibrierungskandidaten wiederverwendet werden, sofern Daten, Aufteilungen, Modell-/Recipe-Regel und Seeds identisch bleiben. Der gemeinsame Weg darf dies bei kalibrierungsabhängiger Modellwahl nicht voraussetzen.

Nur eine Ebene wird zugleich parallelisiert. Bei äußerer paralleler Bewertung laufen alle inneren Suchen seriell. Ohne äußere Parallelität dürfen die Auswahlresamples einer aktiven tune-Suche parallel laufen; darunter bleiben Modell-/Kalibrierungsloops seriell. Die Steuerung plant dies explizit, statt äußere Parallelität zu erraten. Zusätzliche Engine-Threads werden im Budget angegeben und über unterstützte Engine-Optionen begrenzt; fremde Threadpools können nicht pauschal kontrolliert werden.

Ein Root-Seed, lokale Zufallszustände, vollständige Pläne, Suchkonfiguration, Versuchshistorie und Parallelstrategie werden gespeichert. Zuordnung folgt logischen Such-/Resample-/Versuchsidentitäten, nicht der Reihenfolge fertig werdender Worker. Reproduzierbarkeit wird für dieselbe geprüfte Konfiguration und reproduzierbare Engines zugesagt. Keine bitweise Plattform-/Engine-Unabhängigkeit und keine identische Suchfolge zur ununterbrochenen nativen Bayes-Suche.

## 6. Zustand, Vorhersagen und Diagnose

Das endgültige Objekt hält nur die tatsächlich verwendeten passenden Modell-/Recipe-/Kalibrator-Pfade und deren ausgewählte Einstellungen als Vorhersagezustand. Candidate-Modelle müssen nicht dauerhaft gespeichert werden; nötige Kandidatenergebnisse, Auswahlbegründung und Fehler bleiben nachprüfbar. `predict()` führt keine Suche, kein Modelltraining und keine neue Kalibrierung aus.

Die bisherigen Ausgaben bleiben erhalten: `.pred_<Klasse>`, `.pred_class` oder `.pred`; Grenzen und Fold-/Teilproblemergebnisse separat. Weder Klassifikations- noch Regressionsgrenzen werden durch das Tuning zu gewöhnlichen Konfidenz- oder Vorhersageintervallen.

`venn_abers_tuning()` liefert logisch getrennte Suchprotokolle mit nativen Ergebnissen/Collectors soweit verfügbar, Eignungsstatus und Ausschlussgründen, Haupt-/Berichtsmetriken, gewählten gemeinsamen Optionen und lokalen Modellparametern, Datenrollen-/Resample-Identitäten, Seeds, Budgets und Abbruchgründen. Ein fehlgeschlagener äußerer Bewertungsfold bleibt in der Bewertung sichtbar; vorhandene native Mittelwerte werden nicht als vollständige unabhängige Bewertung ausgegeben.

Submodell-Wiederverwendung des vollständigen kalibrierten Prädiktors wird erst aktiviert, wenn Kandidatenidentität und passende Kalibrierung anhand äquivalenter Ergebnisse geprüft sind. Der sichere Ausgangsweg berechnet jeden kalibrierten Kandidaten vollständig. Native Wiederverwendung innerhalb einer unkalibrierten ersten Stufe bleibt möglich; ihre extrahierten Objekte dürfen nicht mit jedem Submodell gleichgesetzt werden.

## 7. Enger Sonderfall: reine Loss-Auswahl nach festem Fit

Als zusätzliche Konkretisierung zur Abnahme vorgeschlagen: Sind alle Basismodelle, Preprocessoren, Kalibratoren, Präzisionen und sonstigen Verfahrensoptionen bereits festgelegt, können Log- und Brier-Punktzusammenführung auf separaten, bisher unbenutzten Validierungsdaten verglichen werden. Es wird genau eine gemeinsame Loss-Regel ausgewählt. Die bereits gefitteten Komponenten bleiben anschließend unverändert.

Dafür sind keine neuen Modellfits und keine zusätzliche Resampling-Verschachtelung allein für den Vergleich dieser beiden Regeln nötig. Der Einstieg ist ein dokumentierter Ablauf aus dem bereits geplanten `predict(fitted, validation_data, type = "prob", loss = ...)` und yardstick; anschließend wird die gewählte Loss-Regel bei neuen Vorhersagen ausdrücklich übergeben. Eine zusätzliche Komfortfunktion ist dafür nicht erforderlich. Die Validierungsdaten bleiben trotzdem Auswahldaten; die abschließende Leistungsbewertung verwendet andere Daten. Aufnahme dieser Daten in ein späteres Modelltraining oder eine erneute Modell-/Recipe-Auswahl verlassen den Sonderfall. Die normale gemeinsame Suche verwendet weiterhin die in Abschnitt 2 bestätigte Aufteilung. Der Sonderfall ist kein allgemeiner Zugang für eingefrorene Fremdmodelle und ersetzt dessen eigenes Planungsticket nicht.

Die Datenflussbegründung und ihre Aussagegrenzen stehen in der [gesonderten Recherche](tuning-loss-selection-research.md). Eine perfekte Kalibrierung der ausgewählten Punktwahrscheinlichkeiten oder eine neue Cross-/Multiclass-Garantie wird daraus nicht abgeleitet.

## 8. Überprüfbare Implementierungsabnahme

1. Alle acht Verfahren × beide Strategien × Grid/Bayes ausführen; feste und automatische Kalibrierungsoptionen, explizite und automatisch erzeugte lokale Pläne sowie native `fit`, `predict`, `fit_resamples` und `last_fit` abdecken. Modell- und Recipe-Parameter tatsächlich verändern; feste Teilmengen bleiben fest.
2. End-to-end-Datenrollen instrumentieren. Jeder finale Kalibrierungsfold ist von der vollständigen Auswahl-/Trainingsabhängigkeit seines Modells ausgeschlossen. `S` wird nicht in `F` zurückgeführt. Äußere Assessment-/Test-Zielwertmutation ändert keine vorher gefitteten Zustände oder Vorhersagen. Eine absichtlich eingeschleuste Kalibrierungszeile muss die Prüfung scheitern lassen.
3. Auswahl auf `S` und finalen Fit auf `F` mit derselben gespeicherten Auswahlregel rekonstruieren. Im gemeinsamen Weg dürfen lokale Modellentscheidungen von `lambda` abhängen; im zweistufigen Weg bleibt die erste Stufe bei gleichen Daten und Seeds davon unabhängig. Unterschiedliche finale `theta_f` sind zulässig und nachvollziehbar.
4. Mit gespeicherten Modellvorhersagen, Kalibrierungsdaten, Foldzuordnungen und Optionen die bestehenden manuellen Kerne aufrufen; Endvorhersagen und verfügbare Details müssen nach den jeweiligen beschlossenen numerischen Toleranzen übereinstimmen. Kein neuer pauschaler Garantie- oder Überlegenheitsanspruch.
5. Fit-/Kalibrierungs-/Hauptmetrikfehler auf genau einem Fold, fehlende beziehungsweise doppelte Vorhersagezeilen und nur fehlerhafte Zusatzmetriken injizieren. Unvollständige Kandidaten dürfen weder ausgewählt werden noch dem nächsten GP als gültige Trainingsdaten dienen. Kein Kandidat wird durch kleineres Bewertungsvolumen bevorzugt.
6. Bayes-Fortsetzung mit echten Fehlern und wiederholten Vorschlägen prüfen: globale Identitäten, exakt gleiche Resamples, Gesamtbudgets, Abbruchgründe, keine Zählerrücksetzung, zu wenige gültige Initialpunkte und kein gültiger Kandidat. Keine private tune-Manipulation und keine künstlichen Strafmetriken als Ersatz für Ausschluss.
7. Parameter-ID-Kollisionen, kategoriales `none`, negative Präzision, m-/epsilon-Grenzen auf sämtlichen inneren Kalibrierungsgrößen, unzulässige Modi, fehlende Klassen und zu kleine Folds abnehmen. Keine stillen Reparaturen.
8. Finaler Fitfehler bleibt ein Fehler. Predict ist zustandsfrei bezüglich Lernen, nutzt passende Pfade und hält die vorhandenen Klassen-/Schema-/Diagnoseverträge ein. RDS-Roundtrip und frische Worker prüfen, soweit die Basisengine serialisierbar ist.
9. Reproduzierbare Wiederholung mit gleicher Konfiguration und erlaubter Parallelstrategie; Fit-Aufwandsanzeige gegen instrumentierte Zähler prüfen. Zusätzliche Metrikfehler isolieren. Reine Loss-Auswahl verändert keine gefitteten Komponenten und verwendet keine Testdaten.
10. Manuelle Kerninstallation ohne Integrationspakete, optionale Registrierung, geeignete Mindest-/aktuelle Teilpaketversionen, ausführbare Beispiele gegen das installierte Package und `R CMD check`. Dials und die tatsächlich benötigten tune-Abhängigkeiten bleiben optional für den manuellen Kern. Bestehende Integrations-Mindestversionen sind der Ausgangspunkt; der konkrete Tuningvertrag ist auf tune 2.1.0 und den Versionen der Forschungsproben belegt, nicht auf älteren Kombinationen.

Die vorhandenen Forschungsproben decken ausgewählte technische Seams ab. Die zusätzliche [strukturelle Datenrollen-Probe](tuning-data-roles-probe.py) prüft die acht Kombinationen Inductive/Cross × gemeinsam/zweistufig × automatische/feste gemeinsame Optionen und erkennt eine absichtlich eingeschleuste Kalibrierungsabhängigkeit. Sie verfolgt ausschließlich Beobachtungsabhängigkeiten im vorgeschlagenen Ablauf; sie berechnet keine Modellvorhersagen oder Venn-Abers-Ergebnisse. Die vollständige Implementierungsabnahme wurde noch nicht ausgeführt.

## 9. Geordnete Umsetzung nach Abschluss der Planung

1. Auf der beschlossenen optionalen parsnip-/Workflow-Integration aufbauen; lokale Datenpläne und feste Inductive-/Cross-Fits als Basis verwenden.
2. Modell-/Recipe-/Kalibrierungsparameter abbilden, Konfiguration validieren und öffentliche native Finalisierung anbinden.
3. Bausteine A bis D mit identifizierbaren Datenrollen und gemeinsamen Auswahlregeln implementieren; zuerst deterministische Grid-Beispiele für beide Strategien.
4. Strenge Kandidatenprüfung, isolierte Berichtsmetriken, globale IDs und native schrittweise Bayes-Fortsetzung ergänzen.
5. Budgetabschätzung, Seeds, eine Parallelitätsebene, Diagnose-/Ausgabezugänge und den engen Loss-Sonderfall vervollständigen.
6. Vollständige oben definierte Abnahme, Dokumentation und Paketprüfungen durchführen; anschließend die Umsetzung in die verbindlichen Release-Milestones einordnen.

Quellen und technische Belege: [Integrationsrecherche](tuning-integration-research.md), [Fehler-/Bayes-Recherche](tuning-error-research.md), [Loss-Auswahl](tuning-loss-selection-research.md), [native Last-Fit-API](https://tune.tidymodels.org/reference/last_fit.html), [Post-hoc-Metriken](https://tune.tidymodels.org/reference/compute_metrics.html).
