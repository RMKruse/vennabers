# Zusätzlich gelerntes Postprocessing bis v1.0

Vertragsentwurf vom 2026-09-07 für [Zusätzlich gelerntes Postprocessing und innere Datenverträge bis v1.0 festlegen](https://github.com/RMKruse/venn-abers/issues/18), Teil von [Wayfinder: Release-Roadmap bis v1.0 mit Python-Parität und tidymodels](https://github.com/RMKruse/venn-abers/issues/2).

**Status:** Die Verfahrensfamilien, Vollmodellbedeutung, Datenplan-Grundsätze, Methodenmatrix, Zwei-Klassen-Sonderfall und Tuning-Grenze wurden einzeln im Live-Gespräch bestätigt. Die Abschnitte 1 bis 10 verbinden diese Entscheidungen mit konkreten vorgeschlagenen Aufrufen, numerischen Regeln, Validierungen, Speicherung und Abnahme. Diese vollständige Fassung steht noch zur Schlussentscheidung. Keine Produktionsimplementierung und keine bestandene Produktabnahme.

## 1. Verbindlicher Zielumfang und seine Grenzen

| Äußerer VA-Weg | Methoden des zusätzlichen Postprocessings | Kombinationen |
|---|---|---:|
| Binär | sklearn-Sigmoid, Tailor-logistisch ohne Glättung | 16 |
| Paarweises binäres OvO-Training | sklearn-Sigmoid, Tailor-logistisch ohne Glättung | 16 |
| Gemeinsames Multiclass-Modell ab drei Klassen mit OvO-VA | Tailor-multinomial ohne Glättung | 8 |
| Gemeinsames Multiclass-Modell ab drei Klassen mit OvR-VA | Tailor-multinomial ohne Glättung | 8 |
| Gemeinsames Zwei-Klassen-Modell mit OvO-VA | Tailor-logistisch ohne Glättung | 8 |
| Gemeinsames Zwei-Klassen-Modell mit OvR-VA | Tailor-logistisch ohne Glättung | 8 |
| Numerische Regression | Isotonie nach Python-Probe, Tailor-linear ohne Glättung | 16 |

Jede Methode unterstützt Holdout und inneres Cross-Kalibrierungsensemble, jeweils Inductive/Cross-VA und passende Modelle/Vollmodell-Übertragung: insgesamt **80 Methoden-/Verfahrenskombinationen**, bestehend aus der zuerst bestätigten 64er-Matrix und 16 ausdrücklich bestätigten gemeinsamen Zwei-Klassen-Randfällen. Diese Zahl zählt weder Enginevarianten noch Loss-, Rundungs-, Moderations-, Tuning- oder Namensfälle zusätzlich. Für genau zwei Klassen im gemeinsamen OvO-/OvR-Weg wird ausdrücklich `tailor_logistic` gewählt; `tailor_multinomial` bleibt auf mindestens drei Klassen beschränkt. Kein automatischer Methodenwechsel und keine Umdeutung der anschließenden OvO-/OvR-Kalibrierung in den binären VA-Vertrag.

Ohne zusätzliches Postprocessing gelten die bisherigen Verfahren weiter. Eingefrorene vollständige Workflows einschließlich bereits gelernter Postprocessor behalten ihren [eigenen Vertrag](https://github.com/RMKruse/venn-abers/issues/12#issuecomment-5569800958); die endliche Liste hier begrenzt neu trainierte Kompositionen, nicht deren eingefrorene Übernahme.

Die konkrete Python-Evidenz betrifft ein Sigmoid-CCC-Ensemble bei binären beziehungsweise paarweise trainierten Klassifikationsproblemen sowie einen eigenen numerischen Ridge-/Isotonie-Holdout-Verbund. Die zwölf R-Proben betreffen vollständige Tailor-Quellworkflows, noch ohne VA-Produktintegration. Gemeinsames Multiclass und das numerische innere Ensemble sind bewusste R-Erweiterungen. Ein weiterer unterstützter R-Basisworkflow muss den bestehenden Modell-/Recipe-Vertrag und den hier gewählten Vorhersageeingang erfüllen; es gibt keine Zusage beliebiger sklearn-Schätzer, Tailor-Schrittfolgen oder Engine-Rohschnittstellen.

OOF-Postprocessing mit anschließendem vollständigem Engine-Refit ist **keine zusätzliche v1.0-Pflicht**. Auch weitere neu trainierte Methoden wie Beta-, Temperatur-, Bootstrap-Isotonie oder geglättete GAM-Varianten gehören nicht zu dieser endlichen Zusage. Die Kompositionsfähigkeit ist damit ausdrücklich definiert; „Python-Parität“ bedeutet hier keine vollständige Nachbildung aller Optionen sämtlicher fremder Basisschätzer.

## 2. Geplanter öffentlicher Aufruf

Der bestehende geplante `calibrated_workflow()`-Konstruktor erhält genau ein zusätzliches Argument `postprocessing = NULL`. Ein benanntes, streng validiertes Listenargument genügt; kein weiterer öffentlicher Konstruktor und kein neues Resampling-Frontend.

```r
# Geplanter vennabers-Aufruf; base ist ein untrainierter Basis-Workflow.
spec <- calibrated_workflow(
  base, outcome = "truth", method = "cross", v = 5L,
  prediction_model = "full", seed = 42L,
  postprocessing = list(
    method = "tailor_logistic", strategy = "ensemble", v = 3L
  )
)
fitted <- generics::fit(spec, data = development)
predict(fitted, new_data, type = "prob")
venn_abers_details(fitted, new_data)

# Holdout: prop ist ausdrücklich der Anteil für P, nicht für B.
post <- list(method = "tailor_linear", strategy = "holdout", prop = 0.25)

# Vorbereiteter lokaler Plan; hier keine zusätzlichen prop-/v-Angaben.
post <- list(
  method = "tailor_multinomial", strategy = "ensemble",
  splits = function(data) local_postprocessing_plan(data)
)

# Sigmoid: Art des Eingangs ausdrücklich wählen, kein erratener Rohzugriff.
post <- list(
  method = "sigmoid", strategy = "ensemble", v = 3L,
  sigmoid_input = "glm_link"
)
```

`method` ist genau einer von `sigmoid`, `tailor_logistic`, `tailor_multinomial`, `isotonic_numeric`, `tailor_linear`. `strategy` ist ausdrücklich `holdout` oder `ensemble`. Bei automatischen Plänen ist ausschließlich der passende Größenparameter erforderlich: `prop` endlich und strikt zwischen null und eins, `v` eine ganze Zahl mindestens zwei. Logische Werte, Vektoren, fehlende Werte, unbekannte oder doppelte Felder sowie irrelevante ausdrückliche Angaben sind Fehler. Es gibt keine Methoden-, Strategie-, Anteil- oder Foldzahl-Defaults. Bei `sigmoid` ist zusätzlich `sigmoid_input` erforderlich; bei anderen Methoden ist dieses Feld unzulässig.

`splits` ist ein lokaler `rsplit` für Holdout, ein gültiges unrepeated `rset` für das innere Ensemble oder eine serialisierbare `function(data)`, die genau den passenden lokalen Plan liefert. `analysis` bedeutet B, `assessment` bedeutet P. Ein expliziter Plan bestimmt die Größe selbst und darf nicht gleichzeitig mit `prop` oder `v` angegeben werden. Ein statischer Plan ist nur für exakt passende lokale Daten verwendbar; bei mehreren unterschiedlichen Quellbeständen ist gewöhnlich die lokale Planfunktion erforderlich.

Für einen Basisworkflow ohne Postprocessor erzeugt die Integration den gewählten kanonischen Postprocessing-Schritt. Ein Basisworkflow mit genau einem bereits konfigurierten, ungefitten Tailor-Schritt ist ebenfalls zulässig, wenn er exakt zur angegebenen Tailor-Methode mit `smooth=FALSE` und ohne weitere Optionen passt; dann wird dieser Schritt verwendet, nicht zusätzlich angehängt oder ersetzt. Mehrere Schritte, widersprüchliche Konfigurationen und bereits trainierte Zustände werden früh abgewiesen. Sigmoid und numerische Referenzisotonie verlangen einen Basisworkflow ohne vorhandenen Postprocessor.

Die vorhandenen Argumente für `tuning`, `schema`, `model_training`, VA-Aufteilungen und numerische VA-Optionen behalten ihre Bedeutung. `postprocessing=NULL` lernt keinen zusätzlichen Postprocessor und ist kein Auftrag, einen im Basisworkflow vorhandenen zu entfernen. Normale `fit()`, `predict()`, `fit_resamples()` und `last_fit()` bleiben die Zugänge. Die komplette Spezifikation einschließlich innerer Komposition wird vor dem äußeren Aufruf festgelegt; Predict schaltet die Komposition nicht nachträglich um.

## 3. Lokale Datenrollen, Pläne und Zufall

Die folgenden Buchstaben gelten nur innerhalb dieses Dokuments. Sie sind keine Umbenennung der Bausteine A bis D oder des Auswahlanteils S im bestehenden Tuningvertrag.

- **F:** vollständiger zulässiger Bestand eines finalen lokalen Fits. Äußere Bewertung und der gegebenenfalls separat reservierte gemeinsame Auswahlanteil gehören nicht dazu.
- **C:** jeweiliger gehaltener VA-Kalibrierungsanteil.
- **Q:** Quelltrainingsbestand des zugehörigen zusammengesetzten Basisschätzers. Für gehaltene Kalibrierungsvorhersagen ist C vollständig aus Q ausgeschlossen.
- **B, P:** innere Modell-/Recipe-/Auswahldaten und davon getrennte Postprocessing-Daten, jeweils innerhalb Q.
- **A:** unabhängige äußere Bewertungsdaten, von sämtlichen Lern- und Auswahlstufen dieses Fits ausgeschlossen.

Im Holdout gilt B∩P=∅ und B∪P=Q. Beim inneren Ensemble partitionieren P_1 bis P_J den Bestand Q genau einmal; B_j ist jeweils Q ohne P_j. B_j und P_j sind innerhalb ihres Paars disjunkt. Dass eine Beobachtung in einem anderen Paar eine andere Rolle erhält, ist beabsichtigt; globale Disjunktheit aller B- und P-Mengen wäre falsch. Entsprechend darf eine VA-Kalibrierungsbeobachtung in einem anderen VA-Fold dessen Quelltraining angehören.

Vor jedem Quellfit werden aktuelle lokale Daten und Planbindung, gültige eindeutige Positionen, Vollständigkeit, Disjunktheit, nichtleere Mengen und eindeutige Fold-IDs geprüft. Für Ensemblepläne gelten exakte Komplementbildung und genau eine P-Zuordnung pro Zeile. Repeated-Folds, Bootstrap-Duplikation oder überlappende Monte-Carlo-P-Anteile sind kein solcher Ensembleplan. Gleiche Datenwerte an verschiedenen Positionen bleiben unterschiedliche Beobachtungen; tatsächliche duplizierte Herkunft wird nicht durch Wertgleichheit beweisbar.

Die Datenbindung übernimmt den [beschlossenen Identitätsvertrag](https://github.com/RMKruse/venn-abers/issues/15#issuecomment-5570134201): Werte, Typen, Faktorlevels, ausgewählte Spalten und Zeilenreihenfolge zählen; Row Names und bloße Zeilenzahl genügen nicht. Gleiche kanonische lokale Daten erhalten bei vorbereiteten Plänen denselben eindeutigen Plan. Kein Zugriff auf einen globalen Positionsplan, äußere Bewertungsdaten oder Aufrufzähler. Explizite Vorkommensorchestrierung bleibt ein getrenntes Verfahren; diese Erweiterung führt keine versteckte äußere Resample-ID ein. Beliebiger Code in Nutzer-Closures kann nicht automatisch auf seine gesamte Herkunft geprüft werden.

Automatische Pläne entstehen mit den bereits verwendeten öffentlichen rsample-Verfahren. `prop` wird als P-Anteil umgesetzt; tatsächlich entstandene B-/P-Größen werden gespeichert. Klassifikation wird nach dem lokalen Ziel mit `pool=0` stratifiziert, Regression ohne Stratifikation. Ungültige Ergebnisse werden gemeldet; keine Wiederholungsversuche, Klassenpoolung oder automatische Größenkorrektur. Geordnete explizite Holdouts bleiben bei erfüllten Mengen- und Klassenregeln möglich; daraus folgt keine neue Gruppen-/Zeitreihengarantie.

Die vorhandene `seed`-Option steuert den vollständigen lokalen Fit. `seed=NULL` verwendet den vom Aufrufer beziehungsweise tune verwalteten RNG-Strom; ein expliziter Seed setzt und restauriert den lokalen Zustand nach bestehendem Vertrag. VA-Plan, Postprocessing-Pläne, Suchläufe und Fits konsumieren diesen Strom in gespeicherter stabiler Reihenfolge. Nicht denselben Seed in jedem inneren Paar neu setzen. Die dokumentierte äußere Parallelkonfiguration und reproduzierbare Engines bleiben Voraussetzung; ein beliebiger zustandsbehafteter Callback wird nicht dadurch deterministisch. Tatsächliche Pläne und RNG-Metadaten bleiben nachvollziehbar.

Bei paarweisem Training wird zuerst auf das betreffende Klassenpaar eingeschränkt. Erst danach entstehen dessen VA- und Q-/B-/P-Pläne; fremde Klassen gehören nie zum Paartraining. Kodierte Eingänge folgen dem [festen Namensschema](https://github.com/RMKruse/venn-abers/issues/17#issuecomment-5570473475); Planfunktionen erhalten lokale kodierte Daten, Klassenidentitäten werden nicht je Fold neu erfunden.

## 4. Methoden und vollständiger Vorhersagepfad

### Sigmoid

`sigmoid` folgt dem Platt-Vertrag des in der Recherche verwendeten sklearn 1.9.0, einschließlich geglätteter binärer Zielwerte und unregularisierter logistischer Zielfunktion. Bei N_1 Ereignissen und N_0 Nichtereignissen in P sind die Fit-Zielwerte (N_1+1)/(N_1+2) beziehungsweise 1/(N_0+2); die gelernte Sigmoidabbildung wird auf neue Eingänge angewendet. Ein bloßes unmodifiziertes Tailor-GLM ist dafür kein numerischer Ersatz. Optimierungsdetails dürfen variieren, sofern die festgelegten Referenzvergleiche einschließlich schwieriger Eingänge bestehen.

Der Methodenvertrag orientiert seine interne Wahrscheinlichkeit am zweiten gespeicherten binären Faktorlevel; anschließend erfolgt die benannte Ausrichtung für den VA-Ereignisvertrag. `sigmoid_input="probability"` verwendet die endgültige benannte Wahrscheinlichkeit dieses Levels aus dem Basisworkflow ohne Postprocessor. `sigmoid_input="glm_link"` verwendet für den ausdrücklich unterstützten binomialen GLM-Workflow mit Logit-Link dessen vollständigen öffentlichen Workflow-Rohvorhersagepfad (`type="raw", opts=list(type="link")`) einschließlich gelerntem Recipe. Der Link bezieht sich auf dasselbe zweite Modelllevel. Die genaue Rohschnittstelle ist vor Produktfreigabe separat zu prüfen.

Ein anderer Engine-/Linktyp mit `glm_link` wird abgewiesen; es wird weder die Engine aus dem Workflow herausgelöst noch eine gerundete oder gesättigte Wahrscheinlichkeit zurück in einen Linkwert umgerechnet. Weitere enginespezifische Entscheidungswertadapter sind keine Zusage dieses Vertrags. Der Wahrscheinlichkeitseingang bleibt für geeignete vollständige Basisworkflows verfügbar. Python-Gegenproben verwenden jeweils denselben Eingang: `decision_function` für den Linkvergleich oder einen ausdrücklich nur `predict_proba` anbietenden Referenzschätzer für den Wahrscheinlichkeitsvergleich.

### Tailor-Methoden

Die kanonischen Schritte sind `adjust_probability_calibration(method="logistic", smooth=FALSE)`, `adjust_probability_calibration(method="multinomial", smooth=FALSE)` und `adjust_numeric_calibration(method="linear", smooth=FALSE)`. Die öffentlichen Workflows/Tailor/probably-Pfade bleiben erhalten. Es gibt keine zusätzliche Glättung, nachträgliche Methodenauswahl oder Übernahme der zufälligen Defaults einer anderen Methode.

Pro innerem Paar erfolgt nach der lokalen Auswahl `fit(base_with_tailor, data=B, data_calibration=P)`. Die komplette gespeicherte Workflow-Vorhersage wird später auf C und neue Beobachtungen angewendet, mit `prob` beziehungsweise `numeric`. Tailor wird weder umgangen noch zweimal angewendet. Multinomiale Kalibrierung des gemeinsamen Modells ist nicht mit dessen anschließender OvO-/OvR-VA-Kalibrierung zu verwechseln.

### Numerische Isotonie

`isotonic_numeric` entspricht der numerischen [Python-Probe](https://github.com/RMKruse/venn-abers/blob/6abd3cb9825df419f0c158923c665bfed1acdb51/tools/integration-boundaries-python.py): ungewichtete monoton steigende Least-Squares-Isotonie auf gehaltenen numerischen Basisvorhersagen, lineare Interpolation zwischen den gelernten Stützstellen und konstante Fortsetzung an den Randwerten (`out_of_bounds="clip"`). Es gibt keine Begrenzung auf [0,1]. Gleiche Eingangswerte werden mit ihren Häufigkeiten berücksichtigt; bei einem einzigen eindeutigen Eingang gilt die konstante mittlere Wahrheit. Tailors isotone Treppenfunktion ist kein ungeprüfter Ersatz.

Recipe und numerische Engine werden auf B gelernt; der Postprocessor erhält ausschließlich ihre Vorhersagen und die Wahrheiten aus P. Der gespeicherte Verbund ruft zuerst den vollständigen Basisworkflow und dann genau einmal die gespeicherte Isotonie auf. Ein zusätzlicher Ridge-Zwang wird nicht eingeführt: Ridge ist eine Referenzengine, geeignete bestehende numerische Workflows bleiben möglich.

### Gemeinsame Aggregation

Ein inneres Ensemble mittelt gleichgewichtet die **fertigen Vorhersagen seiner Modell/Postprocessor-Paare**, nach Ausrichtung derselben Klassenreihenfolge. Bei Regression sind dies numerische Werte, bei Klassifikation vollständige Wahrscheinlichkeitsvektoren. Erst diese Q-Verbundvorhersage geht in die VA-Kalibrierung. Das innere Ensemble besitzt noch keine VA-Kalibratoren.

Die äußeren VA-Kerne, Log-/Brier-Merger, Rundung, OvO-Kopplung, OvR-Normierung und Regressionsmoderation bleiben unverändert. Insbesondere wird nicht erst jeder innere Postprocessing-Teil mit VA kalibriert und dann beliebig gemittelt. Unter Cross-VA entstehen die bisherigen getrennten VA-Fold-Kalibratoren aus ihren jeweiligen Q-Verbundvorhersagen.

## 5. Mindestbedingungen und Fehler

Vor Modelltraining werden alle aus dem Plan erkennbaren Bedingungen geprüft. Die zusätzlichen P-Regeln ersetzen nicht die bisherigen, teilweise großzügigeren Regeln für VA-Kalibrierungsdaten C.

- Jedes B muss für die gewählte Engine, das Recipe und eine etwaige lokale Suche ausreichend sein. Bei Klassifikation sind sämtliche Klassen des lokalen Modells in B erforderlich; ein Paarmodell benötigt seine beiden Klassen.
- Sigmoid und Tailor-logistisch verlangen beide Klassen in P. Tailor-multinomial verlangt jede gespeicherte Klasse des gemeinsamen Modells in P. Die gültigen Ein-Klassen-C-Fälle des manuellen VA-Kerns bleiben davon unberührt.
- P enthält mindestens zwei Zeilen. Für parametrische Tailor-Fits sind zusätzlich ausreichend Zeilen und volle Rangfähigkeit des tatsächlichen Postprocessing-Designs erforderlich: mindestens eine Zeile mehr als dessen Rang; logistische und lineare Zwei-Koeffizienten-Fits benötigen damit mindestens drei Zeilen. Diese Rangprüfung ist erst nach den notwendigen B-Vorhersagen möglich. Sie verlangt keine unnötige Einzigartigkeit aller Zeilen.
- Numerische Wahrheiten und Postprocessor-Eingänge sind endlich; Klassenwahrscheinlichkeiten haben eindeutige vollständige Zuordnungen, Werte in [0,1] und gültige Zeilensummen nach bestehender Toleranz. Isotonie erlaubt konstante Eingänge beziehungsweise Wahrheiten nach Abschnitt 4. Ein genereller Mindestwert von 1.000 P-Zeilen wird nicht eingeführt.
- Fehlgeschlagene oder nach der jeweiligen Engine-Konvention nicht konvergierte Fits sind Fehler. Warnungen werden mit Kontext bewahrt; erfolgreiche endliche Ergebnisse werden nicht allein wegen irgendeiner Warnung verworfen. Ein Methodenwechsel auf `none`, ein fehlender Lernzustand oder eine nicht erfüllte strukturelle Fit-Bedingung ist unabhängig von endlichen Ausgaben ein Fehler.
- Der gelernte Tailor-Zustand muss die ausdrücklich verlangte Methode bewahren. Die dokumentierte Kleinmengen-Umstellung auf `none` wird durch Vorprüfungen und Kontrolle des Fit-Ergebnisses verhindert. Kein Ersatzverfahren, kein Weglassen eines inneren Paars, kein Reduzieren von J oder der VA-Foldzahl.

Fehler nennen betroffene Methode, Datenrolle, VA-Fold, inneren Fold und gegebenenfalls Klassenpaar sowie verfügbare und erforderliche Größen. Bei vorher erkennbaren Schema-/Planfehlern bleiben die Lernzähler des betroffenen lokalen Fits null; spätere datenabhängige Rang-/Konvergenzfehler können erst nach notwendigen B-Fits erkannt werden. Bei Predict reichen neue Prädiktoren ohne Wahrheit aus. Unvollständige, falsch ausgerichtete oder nichtendliche Ausgaben werden nicht repariert oder still als Teilbatch weitergereicht.

## 6. Vollmodell und Tuning

Im passenden Modus liefert derselbe gespeicherte Q-Verbund die gehaltenen C-Vorhersagen und die späteren Vorhersagen für neue Beobachtungen. Bei Vollmodell-Übertragung entsteht zusätzlich ein vollständiger Verbund auf F, bei Paartraining auf dem entsprechenden Paarbestand. Dieser behält seine eigenen inneren B/P-Aufteilungen. „Voll“ verlangt nicht das Training jeder Engine auf jeder F-Zeile. Die ursprünglichen gehaltenen C-Vorhersagen und ihre VA-Kalibratoren werden nicht rückwirkend ersetzt.

Die [bestehende eigenständige Vollmodellwahl](https://github.com/RMKruse/venn-abers/issues/11#issuecomment-5569044325) erfolgt nach derselben Suchregel, nun separat innerhalb jedes B des Vollverbunds. Keine willkürliche Übernahme oder Mittelung von Einstellungen aus den ursprünglichen VA-Quellverbünden. F enthält weder äußere Bewertung noch den separat reservierten gemeinsamen Auswahlanteil.

Postprocessing-Methode, Sigmoid-Eingang, Strategie, Anteil/Foldzahl und vorbereitete Pläne sind feste Konstruktionsoptionen je Suchlauf. Ihre Auswahl wird durch Vergleich vollständiger Verfahren auf zulässigen Auswahl-/Bewertungsdaten vorgenommen. Gelernte Postprocessor-Koeffizienten beziehungsweise Stützstellen werden auf P geschätzt; sie sind keine eigenständigen zu suchenden Hyperparameter dieses Vertrags.

Engine-/Recipe-Einstellungen werden mit dem [bestehenden gemeinsamen oder zweistufigen Grid-/Bayes-Vertrag](https://github.com/RMKruse/venn-abers/issues/10#issuecomment-5568603972) ausschließlich innerhalb des jeweiligen B gewählt. Auch alle für diese lokale Suche benötigten inneren Kalibrierungen, Postprocessing-Aufteilungen und Bewertungen liegen in B. Der unmittelbar zugehörige endgültige P-Anteil wird nicht zum Scoring oder zur Auswahl der Engine verwendet. Bei festen Engine-/Recipe-Einstellungen entfällt diese Suche.

Die bestehende endliche Verschachtelung bleibt maßgeblich: Bei der Bewertung eines festen Kandidaten wird keine neue automatische Suche in dessen inneren Fits gestartet. Ein Kandidatenablauf, der für seine Bewertung weitere VA- oder Postprocessing-Aufteilungen benötigt, verwendet dort feste Kandidateneinstellungen. So entsteht keine rekursive Aufforderung, jedes Teilmodell erneut zu tunen. Gemeinsame VA-Optionsauswahl bleibt auf ihrem separat reservierten Anteil; sie darf die festgelegte lokale Auswahlregel beeinflussen, diesen Anteil aber nicht in finale B/P-Daten zurückführen.

Planwiederverwendung, vollständige Kandidatenbewertung, schrittweise Bayes-Steuerung, Budgetverbrauch fehlgeschlagener Versuche, stabile Gleichstände und ein Fehler bei fehlender gültiger Auswahl bleiben unverändert. Lokale Suchfehler können Kandidaten ausschließen; ein fehlgeschlagener finaler Verbundfit erzeugt keinen Ersatzkandidaten. Nur eine Resampling-Ebene wird gleichzeitig parallelisiert.

## 7. Speicherung, Diagnostik und Aufwand

Ein passender Prädiktor speichert alle für neue Vorhersagen benötigten Q-Verbünde einschließlich jedes inneren Recipes, jeder Engine und jedes Postprocessors. Im Vollmodell-Modus werden alle benötigten F-Verbünde gespeichert. Die nur zur Erzeugung gehaltener C-Vorhersagen benötigten Q-Verbünde dürfen erst nach erfolgreichem Fit vollständig verworfen werden; deren gehaltene Vorhersagen, VA-Kalibratoren und beschlossene Diagnose-/Plan-/Auswahlmetadaten bleiben erhalten. Kein neuer Aufbewahrungsschalter und kein nachträglicher Moduswechsel ohne Fit.

Gespeichert werden Format-/Paketversionen, Methode und Eingangstyp, tatsächliche B/P- und VA-Mitgliedschaften mit lokalen Zuordnungen, Klassen-/Ereignis-/Paaridentität, Schema, Parameter, Seed-/RNG-Angaben, Such- und Fehlerhistorie sowie tatsächliche Fit-Zähler. Aufbewahrte Workflows können selbst Trainingsdaten enthalten; die Integration verlangt keine zusätzliche vollständige Kopie der Rohdaten für jede Diagnosetabelle. Vorbereitete Nutzerplanfunktionen müssen nur für erneutes Training transportierbar sein; Predict benötigt keine erneute Planauflösung.

Der vorhandene `venn_abers_details()`-/Tuning-Diagnosezugang wird um Quellverbund, inneren Fold, Methode, Eingangstyp und B-/P-Größen erweitert. Gehaltene C-Verbundvorhersagen und die erhaltene Methode machen den Übergang zum VA-Kern nachvollziehbar. Verworfenes Q-Training wird nicht als weiterhin vorhersagefähig dargestellt; die Diagnose erfindet keine inneren Vorhersagen, deren Modelle nicht aufbewahrt wurden. Originalnamen folgen dem vorhandenen Decodervertrag.

Ohne Tuning gilt pro äußerer Trainingsdomäne bei J inneren Paaren; Holdout entspricht J=1:

| VA-Verfahren / Vorhersagequelle | Trainierte Engine/Postprocessor-Paare | Dauerhaft benötigte Paare |
|---|---:|---:|
| Inductive / passend | J | J |
| Inductive / voll | 2J | J |
| Cross mit K VA-Folds / passend | KJ | KJ |
| Cross mit K VA-Folds / voll | (K+1)J | J |

J zählt jeweils einen Enginefit und einen Postprocessorfit; Recipe-Fits kommen mit jedem Enginefit hinzu. Bei expliziten Plänen mit verschiedenen J werden die tatsächlich geplanten Werte pro Q beziehungsweise F addiert. Bei Klassenpaaren wird über sämtliche Paare summiert. Modellinterne Optimierungsschritte sind keine zusätzlichen Verbundfits; Engine-interne Ensembles müssen bei realen Speicher-/Laufzeitangaben trotzdem ausgewiesen werden.

Beispiel: drei Klassen im Paarweg, K=5 äußere VA-Folds und J=3 innere Postprocessing-Paare, Vollmodell: 3×6×3=54 Enginefits und 54 Postprocessorfits; für Predict bleiben neun vollständige Paare erhalten. Tuning und unabhängige äußere Bewertung multiplizieren beziehungsweise ergänzen diesen Aufwand nach ihren realen Ausführungspfaden. Vorab werden die aus Plänen/Budgets bestimmbaren Kosten angegeben; unbekannte datenabhängige Kosten werden nicht als exakte Zahl ausgegeben.

Predict trainiert und selektiert nichts. Je benötigtem inneren Paar und nichtleerem Batch wird der vollständige Vorhersagepfad genau einmal ausgeführt, danach aggregiert und im VA-Kern weiterverwendet. Insbesondere wird ein F-Verbund nicht je VA-Kalibrator erneut vorhergesagt. Leere Batches erhalten das bisherige wohldefinierte leere Schema ohne Engineaufruf. `saveRDS()`/`readRDS()` in einem frischen R-Prozess muss bei den geprüften Engines denselben vollständigen Pfad einschließlich Schema und innerer Postprocessor wiederherstellen. Externe Engine-Ressourcen behalten ihre bestehenden Einschränkungen.

## 8. Verbindliche Abnahme nach Implementierung

Die folgenden Prüfgruppen sind mit installierter optionaler Integration auszuführen. Die 80er-Matrix ist vollständig zu prüfen; weitere Achsen werden mit gezielten Fällen ergänzt, nicht durch einen einzelnen glücklichen Workflowaufruf ersetzt.

1. **Methodenmatrix und native Wege:** Alle 80 Kombinationen einschließlich der 16 gemeinsamen Zwei-Klassen-Fälle mit geeigneten Referenzengines durch Fit/Predict und vollständige native äußere Bewertung führen. Binär beide Ereigniswahlen, gemeinsam OvO/OvR, Paaridentität, Log/Brier/Rundung sowie Regressionsmoderation nach ihren bestehenden Verträgen ergänzen. `last_fit()` und gespeicherte äußere Extrakte für die drei Zielarten prüfen.
2. **Numerische Schichtung:** Dieselben B/P-/VA-Pläne und eingefrorenen Basisvorhersagen verwenden. Zuerst jeden Postprocessor gegen seine eigene Referenz prüfen, dann die gleichgewichtete innere Mittelung, dann den identischen manuellen VA-Kern und schließlich die Endausgabe. Sigmoid wird mit beiden Eingangstypen, seltenen Klassen, konstanten und großen endlichen Eingängen geprüft; numerische Isotonie mit Ties, einzelnen Stützstellen, Zwischenwerten und Randfortsetzung. Tailor-Verfahren gegen vollständige öffentliche Workflow-Pfade vergleichen. Gleiche Seeds oder ähnliche Methodennamen genügen nicht. Klassifikations-VA-Kernvergleiche verwenden die bestehende absolute Toleranz 1e-10; Regression die beschlossene skalenabhängige absolute und relative Toleranz. Direkte sigmoidale Referenzausgaben bei identischen Eingängen dürfen höchstens 1e-7 absolut abweichen; keine Forderung identischer Koeffizienten bei nicht identifizierbaren konstanten Eingängen. Isotonievergleiche verwenden 1e-10 absolut plus 1e-10 relativ; End-to-End-Vergleiche zwischen verschieden numerisch trainierten Engines ersetzen die isolierten Vergleiche nicht.
3. **Datenrollen mit Mutation:** IDs und Fit-/Suchzugriffe instrumentieren. Änderungen ausschließlich an P-Zielwerten dürfen die zugehörige B-Suche, Engine und Recipe nicht verändern, aber den Postprocessor verändern. Änderungen an C dürfen den zugehörigen Q-Verbund nicht beeinflussen; bei Vollmodell dürfen sie dessen F-Verbund beeinflussen. A und separat zurückgehaltene Auswahlanteile gelangen nie in finale B/P-Fits. Im Ensemble nur die jeweilige B_j/P_j-Grenze verlangen: Eine P_j-Zeile darf in B_k eines anderen Paars liegen. Paarfremde Klassen und kodierte Namensfälle ergänzen.
4. **Pläne und Reproduzierbarkeit:** Automatische und explizite Pläne, verschiedene lokale Größen, identische Daten mit eindeutiger Vorbereitung, umgekehrte Aufrufreihenfolge sowie frische Worker prüfen. Fremde gleich große Daten, falsche Reihenfolge, Lücken, doppelte P-Zuordnung, Überschneidung, widersprüchliche vorbereitete Zuordnungen und globale Positionspläne führen zum kontextreichen Fehler. Kein Retry und keine still verkleinerte Foldzahl. Ein gültiger geordneter Holdout bleibt zulässig.
5. **Methoden-/Datenfehler:** Fehlende Klassen in B/P, zulässige fehlende C-Klassen, null/eine P-Zeile, parametrischer Rangmangel, Nichtkonvergenz, Methodenwechsel auf `none`, unbekannte Schritte, vorhandener passender einzelner Tailor und doppelt angehängter Tailor werden getrennt geprüft. Absichtlich erzeugte Fehlzustände dürfen keinen scheinbar erfolgreichen Verbund liefern. Vorher erkennbare Fehler lösen keinen lokalen Lernschritt aus; später erkennbare Fehler werden nicht fälschlich als Vorprüfung ausgegeben.
6. **Tuning:** Gemeinsame und zweistufige Auswahl mit Grid sowie kontrollierter Bayes-Suche, fixed/tuned Engineparameter, passender/Vollmodell-Verbund und getrennte innere B-Suchen prüfen. Kandidatenbewertungen dürfen keine rekursive automatische Suche starten. Kandidaten mit einem fehlgeschlagenen inneren Paar sind unvollständig; keine Aufnahme in Auswahl oder nächsten GP. Budgets, Wiederholungsversuche und endgültige unabhängige Bewertung rekonstruieren.
7. **Speicher und Aufwand:** Die Formeln aus Abschnitt 7 einschließlich des 54-Paare-Beispiels mit Zählern prüfen. Keine doppelten Workflow-/Tailor-Predict-Aufrufe. Nach frischem R-Prozess liefern vollständige trainierte und separat eingefrorene Pfade dieselben Vorhersagen und vorhandenen Diagnosen; fitfreie Zustandswächter bleiben unverändert. Q-Verwerfen im Vollmodus lässt die festgelegten C-Diagnosen erhalten und reduziert tatsächlich die gespeicherten Vorhersagemodelle.
8. **Vollständige äußere Ergebnisse:** `save_pred=TRUE`, `collect_predictions(summarize=FALSE)`, unzusammengefasste Metriken und Notes auf exakte erwartete `(id, id2, .row, .config)`-Abdeckung prüfen. Für innere Diagnosen vollständige Zustände per passender `extract`-Konfiguration speichern. Einzelne Fit-, Predict- oder Metrikfehler und vollständigen Ausfall erkennen. Native und auf Originalidentitäten rekonstruierte Metriken müssen ihren vereinbarten Ereignis-/Skalierungsregeln entsprechen; ein erfolgreicher Collector-Return allein genügt nicht.
9. **Regression und Paketbetrieb:** Bisherige manuelle Kerne, eingefrorene Zugänge, optionale Installation ohne tidymodels und bereits zugesagte Plattform-/Paketprüfungen bleiben erfolgreich. Null-/Einzeilenausgaben, Zielspaltenfreiheit bei Predict und besondere Namen durch vollständige Postprocessor-Pfade prüfen. Python ist Referenzwerkzeug der Abnahme, keine neue R-Produktlaufzeitabhängigkeit.

## 9. Geordnete Umsetzung

1. Auf dem bestehenden Integrations-, Namens-, Vollmodell- und Tuningvertrag aufbauen. Das neue Listenargument und gemeinsame lokale B/P-Validierung ergänzen; Quellfit und gespeicherte Quellvorhersage bleiben die zentrale Integrationsstelle.
2. Feste Holdout-Fits für die drei kanonischen Tailor-Verfahren implementieren, vollständige Workflow-Pfade und Methodenprüfung verwenden. Geeignete bestehende Basisworkflows samt einem passenden Tailor übernehmen. Sigmoid mit ausdrücklich gewähltem Eingang und numerische Referenzisotonie ergänzen, jeweils gegen die Referenz isoliert prüfen.
3. Das innere Ensemble aus denselben vollständigen Paarfits und gleichgewichteten Endvorhersagen aufbauen. Pläne, Identität, Fehler und Aufwand wiederverwenden. Keine zweite VA-Implementierung innerhalb des Ensembles.
4. Die zusammengesetzten Quellfits in Inductive/Cross, gemeinsames/paarweises Training und Vollmodell-Übertragung einsetzen. Gehaltene C-Quellen und die Aufbewahrungsregeln instrumentiert absichern.
5. Vorhandene lokale Grid-Auswahl auf B begrenzen, danach kontrollierte Bayes-Fortsetzung anbinden. Endliche Kandidatenbewertung, Seeds, Kosten und Diagnosen auf innere Paare erweitern.
6. Die vollständige Abnahme aus Abschnitt 8 ausführen; native Beispiele, Fehlerhilfen, Speicher-/Aufwandsangaben und die endliche Paritäts-/Erweiterungsmatrix dokumentieren. Abhängigkeiten bleiben in der optionalen Integration; vorhandene Bibliotheksverfahren werden verwendet, soweit sie den festgelegten numerischen Vertrag erfüllen.

Ein größerer benötigter Implementierungsaufwand ist keine zusätzliche ungeklärte Produktentscheidung. Scheitert dagegen eine notwendige öffentliche Schnittstelle oder erfordert die Umsetzung eine Änderung des hier festgelegten Nutzer-/Verfahrensvertrags, muss genau diese Abweichung vor einer geänderten Zusage entschieden werden; kein stiller Wechsel auf eine einfachere Methode.

## 10. Evidenz, offene Schlussentscheidung und Release-Grenze

Die [versionierte Integrationsrecherche](https://github.com/RMKruse/venn-abers/blob/6abd3cb9825df419f0c158923c665bfed1acdb51/tools/integration-boundaries-research.md) samt dort verlinkten Python-/R-Proben ist die ausgeführte Grundlage. Sie enthält weder die 80er-Produktmatrix noch die neuen R-Sigmoid-/Referenzisotonie-Adapter. Der geplante GLM-Linkzugriff ist eine ausdrücklich begrenzte Implementierungs- und Abnahmezusage, kein hier bereits erfolgreich ausgeführter Nachweis.

Zusätzlicher geprüfter Randfall: Die [versionierte probably-Multinomialquelle](https://github.com/tidymodels/probably/blob/4a2b767aa2c2f3bb1b0770db3ce8f7bf2873c80a/R/cal-estimate-multinomial.R#L204-L209) weist genau zwei Klassen vor dem Fit ausdrücklich ab. Der ausdrückliche logistische Sonderfall für genau zwei Klassen wurde daraufhin im Live-Gespräch bestätigt.

Methodenquellen: [sklearn 1.9 CalibratedClassifierCV](https://scikit-learn.org/1.9/modules/generated/sklearn.calibration.CalibratedClassifierCV.html), [sklearn 1.9.0 Kalibrierungsquelle](https://github.com/scikit-learn/scikit-learn/blob/1.9.0/sklearn/calibration.py), [sklearn 1.9 IsotonicRegression](https://scikit-learn.org/1.9/modules/generated/sklearn.isotonic.IsotonicRegression.html), [Tailor-Klassifikation](https://tailor.tidymodels.org/reference/adjust_probability_calibration.html), [Tailor-Regression](https://tailor.tidymodels.org/reference/adjust_numeric_calibration.html), [öffentlicher Workflow-Fit](https://workflows.tidymodels.org/reference/fit-workflow.html), [Workflow-Predict](https://workflows.tidymodels.org/reference/predict-workflow.html). Die Recherche fixiert zusätzlich die tatsächlich geprüften R-Paketstände. Diese Quellen beweisen keine pauschale numerische Gleichheit zwischen unterschiedlichen Engines oder Postprocessor-Methoden.

Die aufgenommenen Fähigkeiten gehören bis v1.0 zum Zielumfang; ihre Zwischenversionen und endgültigen Milestones werden in [Release-Reife und verbindliche Milestone-Zuschnitte festlegen](https://github.com/RMKruse/venn-abers/issues/7) entschieden. Frühere v0.5-Einschränkungen werden dadurch als Vorversionsgrenzen eingeordnet. Keine Termine, Umsetzungstickets oder Veröffentlichungen werden hier erzeugt.

Zur Schlussentscheidung stehen die vollständigen Abschnitte 1 bis 10 einschließlich der konkreten Schnittstellen, Sigmoid-Eingänge, Mindestbedingungen, Toleranzen, Speicher-/Aufwandsregeln und Abnahme. Bei Bestätigung wird ausschließlich dieses Planungsticket per Resolution geschlossen und die Map um einen verlinkten Kurzverweis ergänzt. Die OOF-/Engine-Refit-Variante sowie nicht zugesagte zusätzliche Methoden werden als außerhalb dieses endlichen v1.0-Vertrags dokumentiert. Es entsteht daraus kein weiterer unbearbeiteter Forschungsauftrag innerhalb dieser Map.
