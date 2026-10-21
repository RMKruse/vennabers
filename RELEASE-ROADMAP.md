# Release-Roadmap für vennabers: v0.3 bis v1.0

Stand: 7. September 2026. Dieses Dokument hält die im Live-Gespräch bestätigten Entscheidungen und die daraus zusammengestellten abschließenden Release-Definitionen fest.

**Planungsstatus:** Abgeschlossen. Release-Zuordnung, allgemeine Reifekriterien, CI-Matrix, rollierende R-Untergrenze, Abhängigkeitsprüfung, Performance-Messregel, konkrete Benchmarkfälle und CRAN-Vorbereitung sind bestätigt. Die fachlichen Verträge sind in den verlinkten abgeschlossenen Entscheidungstickets festgelegt. Diese Release-Synthese ordnet sie verbindlich zu; es verbleibt keine bekannte offene Planungsentscheidung für dieses Ziel.

**Produktstatus:** Ausgangspunkt ist das R-Package v0.2.0. Die hier definierten Erweiterungen sind geplante Funktionen. Dieses Dokument behauptet weder ihre Implementierung noch bestandene Produktabnahmen oder veröffentlichte Releases. Der lokale Branchname `v0.3` ist kein Nachweis eines fertigen v0.3-Releases.

Die [Wayfinder: Release-Roadmap bis v1.0 mit Python-Parität und tidymodels][map] bleibt der gemeinsame Tracker-Index. Die Zusammenführung erfolgt in [Release-Reife und verbindliche Milestone-Zuschnitte festlegen][release]. Auf ausdrücklichen Nutzerwunsch enthält diese Datei zusätzlich eine zusammenhängende, detaillierte Release-Sicht. Die Quellenlinks erhalten die Herkunft der Entscheidungen; die früher bestätigten Detailverträge gelten fort. Ihre damaligen vorläufigen Versionszuordnungen werden durch die hier bestätigte Staffelung ersetzt.

## 1. Ziel und verbindliche Staffelung

Ziel ist ein stabiles, veröffentlichungsreifes R-Package mit vollständiger Funktionsparität zum vereinbarten Python-Referenzstand und den ausdrücklich beschlossenen zusätzlichen R-/tidymodels-Abläufen. Die Roadmap definiert Umfang, Abhängigkeiten, geordnete Umsetzung und überprüfbare Abnahme je künftigem GitHub-Milestone. Veröffentlichungstermine wurden nicht festgelegt.

| Version / vorgesehener Milestone | Ziel und zusätzlicher Umfang | Release-Voraussetzung |
|---|---|---|
| v0.3 — Multiclass und Klassifikationsoptionen | Binäre Zusatzoptionen; manueller Inductive-/Cross-Multiclass-Kern mit OvO/OvR, Brier, Rundung und Diagnostik | v0.2-Kern; binäre Optionen vor ihrer Multiclass-Nutzung im selben Release |
| v0.4 — Moderierte Regression | Manuelle IVAR und CVAR mit Punktwerten, Grenzen und Fold-Ergebnissen | v0.3 erhalten; eigener geprüfter Regressionskern |
| v0.5 — Native tidymodels-Grundabläufe | Modelltraining, Kalibrierungsaufteilungen, passende Fold-Modelle und vollständige äußere Bewertung für alle bisherigen Verfahren | Klassifikations- und Regressionskerne aus v0.3/v0.4 |
| v0.6 — Eingefrorene Workflows, Namen und Aufteilungen | Eingefrorene Inductive-Kalibrierung, reversible Namenskodierung und vollständige Referenzaufteilungen einschließlich geordneter Holdouts | Gemeinsame Integrationsadapter aus v0.5 |
| v0.7 — Paartraining und Vollmodell-Übertragung | Separate OvO-Paarmodelle sowie Inductive-/Cross-Vollmodell-Übertragung; zunächst feste Parameter | Integration, lokale Pläne und Namensvertrag aus v0.5/v0.6 |
| v0.8 — Vollständiges Tuning | Gemeinsame und zweistufige Auswahl mit Grid/Bayes für sämtliche bis dahin unterstützten Trainingsverfahren | Feste Trainingsverfahren einschließlich Paar-/Vollmodellwegen aus v0.7 |
| v0.9 — Gelerntes Postprocessing | Holdout und inneres Ensemble einschließlich der beschlossenen Tuning-, Paar- und Vollmodellkombinationen | Daten-, Namens-, Trainings- und Auswahlverträge aus v0.5–v0.8 |
| v1.0 — Stabilität, Paritätsnachweis und Veröffentlichungsreife | Abschließende Stabilisierung, vollständiger Paritätsnachweis und vollständig CRAN-vorbereitetes GitHub-Release | Vollständiger beschlossener Funktionsumfang aus v0.9 und bestandene Gesamtfreigabe |

Die Releases bauen kumulativ aufeinander auf. Ein späteres Release erhält die bis dahin zugesagten Fähigkeiten und ihre Prüfungen. Regression hängt mathematisch nicht von der Multiclass-Kopplung ab; die Reihenfolge ist eine Release-Entscheidung. Die Staffelung ist keine Behauptung, dass sämtliche Umsetzungsschritte technisch seriell ausgeführt werden müssen.

Die binären Voraussetzungen erhalten kein separates Zwischenrelease. Der gesamte beschlossene Funktionsumfang soll vor v1.0 vorhanden sein. v1.0 bündelt Stabilisierung und abschließende Freigabe.

Bestätigung: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Staffelung v0.3 bis v0.5][schedule-first] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Staffelung v0.6 bis v1.0][schedule-rest].

## 2. Referenz und Bedeutung der Paritätsaussage

Die festgelegte Referenz ist Python `venn-abers` **1.5.4**, Quellstand `0e7b4bc575ce230134576ba1c76688d46bf99ac7`.

| Referenzartefakt | SHA-256 |
|---|---|
| Numerisches Modul `src/venn_abers.py` | `ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5` |
| Release-Sdist | `a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69` |

Grundlage sind [Python-Funktionsumfang und Paritätslücken erfassen][parity] und dessen [versionierte Fähigkeitsmatrix][parity-asset], ergänzt durch die späteren Fachentscheidungen und die ausgeführten Gegenproben aus [Vorläufige Integrationsgrenzen gegen die vollständige Python-Parität prüfen][boundaries].

Die Abnahme unterscheidet:

- **Numerische Verfahrensparität:** dieselben gültigen Eingaben, Kalibrierungs-/Testvorhersagen, Optionen und Fold-Zuordnungen ergeben innerhalb der festgelegten Toleranzen dieselben Ergebnisse.
- **Trainings- und Datenparität:** Quellmodelle, Paar-/Fold-Aufteilungen, Preprocessing und Kalibrierungsrollen folgen dem jeweiligen Verfahren. Ein Arrayvergleich allein belegt keine korrekte Trainingsorchestrierung.
- **Native R-Bedienung:** R-Funktionen, Workflows, Tabellen und Ausgaben erfüllen den beschlossenen R-Vertrag. Python-Klassennamen, Tupelformen und Wrapper-Vererbung werden nicht als notwendige öffentliche R-API übernommen.
- **Bewusste R-Ergänzungen:** unter anderem manuelle Cross-Multiclass-Kalibrierung, manueller Regressionszugang, trainiertes OvR, direkte eingefrorene Workflow-Übernahme und die ausdrücklich erweiterten Kompositions-/Tuningwege.
- **Referenzdefekte und definierte Abweichungen:** stabile Cross-Log-Aggregation, endliche konstante Regressionsfälle, klare Validierung, konsistente Ausgabeformen, korrekte Klassenauswahl und native R-Rundung. Defekte werden dokumentiert und durch eigene Vertragsprüfungen ersetzt; numerische Toleranzen werden dafür nicht gelockert.

„Vollständig“ bezieht sich auf den untersuchten und ausdrücklich vereinbarten Fähigkeitsumfang. Es verspricht keine beliebigen sklearn-Schätzer, Tailor-Schrittfolgen oder fremden Engine-Rohschnittstellen. Die endliche Kompositionsgrenze wurde ausdrücklich entschieden. Eine später entdeckte zusätzliche Referenzfähigkeit oder tatsächliche Lücke verlangt eine sichtbare Neubewertung der Paritätsaussage.

## 3. Gemeinsame Release-Abnahme

Diese Kriterien gelten für jedes geplante Release, jeweils bezogen auf dessen enthaltenen Funktionsumfang. Die fachlichen Prüfungen in den Versionskapiteln kommen hinzu.

### 3.1 API-Stabilität und Kompatibilität

- Vor v1.0 sind dokumentierte API-Änderungen mit Migrationshinweisen erlaubt.
- Ab v1.0 bleiben öffentliche Funktionen, Argumente und dokumentierte Ausgabeformate innerhalb von 1.x kompatibel. Inkompatible Änderungen kommen erst mit v2.0.
- Die R-Untergrenze folgt ausdrücklich auch innerhalb von 1.x dem rollierenden Supportfenster. Neue Releases dürfen sie mit Hinweis in NEWS anheben; die Mindestversion bereits veröffentlichter Releases bleibt unverändert. Die API-Kompatibilitätszusage friert die R-Untergrenze nicht ein.
- Fehlerkorrekturen dürfen numerische Ergebnisse berichtigen.
- Neue Optionen behalten ohne ausdrückliche Aktivierung die fachlich zugesagten bisherigen Standards. Geplante Schnittstellen in den Quellen sind keine Behauptung bereits verfügbarer Funktionen.
- Der manuelle Kern bleibt ohne tidymodels installierbar, ladbar und verwendbar. Die optionale Integration bleibt im selben Package.

Quellen: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — API-Stabilität][api-decision] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — rollierende R-Untergrenze][r-minimum-decision].

### 3.2 R-Versionen und CI

Ab v0.3 gelten acht verpflichtende Kombinationen. „Aktuell“ und „vorherig“ beziehen sich auf die R-Minorreihen zum jeweiligen Release; die tatsächlich verwendeten Patchstände und Betriebssystem-/Runnerstände werden im Prüfprotokoll festgehalten.

| Plattform | Aktuelle R-Minorreihe | Vorherige R-Minorreihe |
|---|---|---|
| Linux x86_64 | Verpflichtend | Verpflichtend |
| Windows x86_64 | Verpflichtend | Verpflichtend |
| macOS Intel | Verpflichtend | Verpflichtend |
| macOS ARM | Verpflichtend | Verpflichtend |

**Entwicklungsabweichung vom 24. September 2026:** Der Maintainer prüft vor
v1.0 nur unter macOS. Die hier geplante plattformübergreifende Matrix wird
erst bei v1.0 ausgeführt; frühere Entwicklungsstände dürfen deshalb keinen
bestandenen Acht-Plattformen-Nachweis behaupten. GitHub Actions bleiben bis
dahin deaktiviert.

Jede Kombination prüft das gebaute Package mit `R CMD check --as-cran`, Referenztests und ausführbaren Beispielen. Die acht regulären Kombinationen verwenden aktuelle veröffentlichte Abhängigkeiten. Ab v0.5 werden die im jeweiligen Release enthaltenen Integrationsabläufe geprüft. Installation, Beispiele und Produkttests verwenden das gebaute/installierte Artefakt.

Es gibt keine Fehler oder Warnungen auf der verpflichtenden Matrix. Verbleibende NOTEs werden einzeln begründet. R-devel unter Linux dient zusätzlich als Frühwarnprüfung: Befunde werden geprüft und dokumentiert, blockieren ein Release aber nicht automatisch. Ab v0.5 prüft ein weiterer Linux-Lauf Installation und Nutzung des manuellen Kerns ohne tidymodels.

Ab v0.5 kommt ein weiterer verpflichtender Linux-Lauf auf der vorherigen R-Minorreihe hinzu: die deklarierten Mindestversionen der direkten Integrationspakete mit einem kompatiblen, dokumentierten Satz transitiver Abhängigkeiten. Dieser Lauf prüft die enthaltenen Integrationsabläufe und wächst mit Tuning in v0.8 und Postprocessing in v0.9 mit. Er ersetzt weder den Kernlauf ohne tidymodels noch eine der acht regulären Kombinationen. Tatsächlich verwendete Paketversionen werden je Freigabe gespeichert.

Die bisherigen lokalen v0.2-Prüfungen und der deaktivierte Workflow sind historische Ausgangsevidenz, kein Nachweis dieser neuen Matrix. Die tatsächliche CI-Aktivierung gehört zur Umsetzung.

**Deklarierte Mindestversion:** Ab v0.3 verlangen neue Releases mindestens die zum jeweiligen Veröffentlichungszeitpunkt vorherige R-Minorreihe. Die konkrete Untergrenze wird beim Release in `DESCRIPTION` eingetragen. Eine Anhebung wird in NEWS dokumentiert und ist ausdrücklich auch innerhalb von 1.x zulässig. Die Mindestversion jedes bereits veröffentlichten Releases bleibt unverändert.

Damit ersetzt das bestätigte Supportfenster den früheren technischen R-4.1-Ausgangsvertrag für künftige Releases. Eine zusätzliche dauerhafte R-4.1-Abnahme ist nicht vorgesehen. Die Paketmetadaten des derzeitigen v0.2.0-Stands werden durch diese Planung nicht geändert.

Quellen: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — CI-Matrix][ci-decision], [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — rollierende R-Untergrenze][r-minimum-decision] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Abhängigkeitsprüfung][dependency-decision].

### 3.3 Numerik, Datenrollen und Fehler

- Automatisierte Funktions-, Randfall- und Integrationstests bestehen. Bekannte Python-Fehler werden nicht nachgebaut.
- Klassifikationskernvergleiche verwenden eine maximale absolute Abweichung von `1e-10`, ohne relativen Anteil. Zeilensummenvalidierung und Ergebnistoleranz sind verschiedene Regeln.
- Regressionskernvergleiche verwenden `abs(actual - expected) <= 1e-10*s + 1e-10*abs(expected)`. Die positive Einheitenskala `s` wird vor dem Vergleich dokumentiert und bei einem Einheitenwechsel entsprechend angepasst; keine nachträgliche Wahl anhand des Fehlers.
- Bei v0.9 gelten für direkte Sigmoid-Referenzausgaben `1e-7` absolut und für direkte Isotonievergleiche `1e-10` absolut plus `1e-10` relativ. Diese Toleranzen ersetzen nicht die strengeren VA-Kernprüfungen bei identischen Eingaben.
- Form, Typen, Endlichkeit, Klassen-/Fold-/Zeilenidentität und Randfälle werden unabhängig von der numerischen Toleranz geprüft.
- Tests verwenden identische Eingaben und zugeordnete Vorhersagen. Gleiche Seeds in unterschiedlichen Ökosystemen reichen nicht als Paritätsnachweis.
- Gelerntes Preprocessing, Modellwahl, Modelltraining, zusätzliches Postprocessing, VA-Kalibrierung und äußere Bewertung bleiben in ihren definierten Datenrollen. Instrumentierte Zugriffe und gezielte Änderungen ausschließlich gehaltener Zielwerte prüfen diese Trennung.
- Kein stilles Weglassen von Folds, Klassen, Vorhersagezeilen oder gescheiterten Kandidaten. Fehler werden mit ihrem lokalen Kontext erkennbar.
- Vollständige äußere Bewertung prüft die erwarteten Beobachtungs-, Resample- und Kandidatenidentitäten einschließlich Wiederholungen. Ein erfolgreicher Collector-Aufruf oder eine vorhandene Metriktabelle allein genügt nicht.
- Predict trainiert nichts. Gespeicherte passende Modelle beziehungsweise Vollmodelle und vollständige Pre-/Postprocessing-Pfade bleiben dem gewählten Fit-Verfahren zugeordnet.

Quellen: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — technische Abnahme][technical-decision] sowie die jeweiligen fachlichen Abnahmen.

### 3.4 Dokumentation und Beispiele

Alle öffentlichen Funktionen dokumentieren Eingaben, Ausgaben, Annahmen und Grenzen. Jeder neu unterstützte Hauptablauf erhält ein ausführbares, automatisch geprüftes Beispiel mit korrekter Datenaufteilung. NEWS und erforderliche Migrationshinweise sind vollständig. Erreichter Python-Paritätsumfang, R-Erweiterungen und bewusste Abweichungen bleiben nachvollziehbar.

Die Beispiele werden für das installierte Package geprüft. Paper-orientierte Beispiele für binäre Klassifikation, Multiclass und Regression erklären den jeweiligen Anwendungsbezug. Eine Reproduktion aller Paper-Datensätze und Benchmarktabellen wurde nicht verlangt. Behauptete Referenzwerte benötigen reproduzierbare Daten-, Split- und Modellangaben.

Keine Zusage universell besserer Accuracy, Log Loss, Brier oder RMSE; keine pauschale Coverage-Garantie. Binäre VA-Endpunkte, beschreibende Cross-Regression-Aggregate und gewöhnliche Konfidenz-/Vorhersageintervalle bleiben begrifflich getrennt. Die Fachbegriffe folgen den verlinkten fachlichen Verträgen.

Quelle: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Dokumentationsreife][docs-decision] und [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen][splits].

### 3.5 Performance

Reproduzierbare Laufzeit- und Speichermessungen mit dokumentierten Datengrößen und Testumgebungen gehören zur Abnahme. Bestehende Verfahren werden mit dem vorherigen Release verglichen; Verschlechterungen werden vor Freigabe untersucht und begründet. Ein festes Geschwindigkeitsverhältnis zu Python ist nicht zugesagt. Zusätzliche feste Größen-, Laufzeit- oder Speichergrenzen wurden nicht verlangt.

Der bisherige IVAP-Fall mit 100.000 Kalibrierungs- und 100.000 Vorhersagezeilen bleibt erhalten. Ab v0.3 ersetzt der dokumentierte Vergleich zum vorherigen Release die historische feste 10-Sekunden-Grenze. Für jeden Fall werden ein Aufwärmlauf und drei Messläufe durchgeführt. Einzelwerte, Median und Spitzenspeicher werden erfasst, bei Modellobjekten zusätzlich die RDS-Größe.

Beide Releases werden unter denselben Bedingungen gemessen. Verschlechterungen bleiben vor Freigabe untersuchungs- und begründungspflichtig. Neue Fähigkeiten erhalten zunächst eine Ausgangsmessung; ein Vergleich zu einer im Vorgänger nicht vorhandenen Funktion wird nicht behauptet. Umfangreiche Benchmarks laufen separat von der CRAN-Paketprüfung.

Die konkreten zusätzlichen Fälle und ihre Messumgebung im folgenden Abschnitt sind ebenfalls im Live-Gespräch bestätigt. Sie sind Teil der jeweiligen Release-Abnahme.

Quellen: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Performance-Abnahme][performance-decision], [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Performance-Messung und Freigaberegel][performance-method-decision] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — konkreter Benchmarkplan][benchmark-decision]; Ausgangsevidenz: [v0.2-Abnahme](tools/acceptance-v02.md).

#### 3.5.1 Verbindliche Benchmarkfälle je Version

**Zweck:** Die folgenden Fälle messen gezielt den Aufwand der jeweils neu eingeführten Verfahren. Sie ergänzen die vollständigen fachlichen Testmatrizen und ersetzen diese nicht. Messgrößen sind keine zusätzlichen API-Größenlimits.

**Gemeinsame Vorbereitung:** Reproduzierbare synthetische Daten, feste Seeds, tatsächliche Zeilen-/Fold-Zuordnungen, Modellkonfiguration und Paketstände werden als versionierte Benchmark-Eingaben beziehungsweise Generator-/Konfigurationsstand festgehalten. Klassifikationsdaten und lokale Pläne erfüllen die benötigten Klassenbesetzungen; Regressionsdaten sind endlich und erfüllen die Moderationsbedingungen. Erzeugung und Prüfung der Eingaben liegen außerhalb der Laufzeitmessung. Es werden keine externen Datensätze benötigt.

| Ab Version | Zusätzliche Fälle | Feste Größe und Konfiguration |
|---|---|---|
| v0.3 | Bestehendes binäres IVAP; binäres Cross; manuelles Multiclass Inductive/Cross × OvO/OvR | IVAP: unveränderter bisheriger 100.000/100.000-Fall. Weitere Kernfälle: insgesamt 10.000 Kalibrierungszeilen, 1.000 neue Zeilen, bei Cross fünf Folds. Multiclass mit drei und zehn Klassen. Standard Log Loss, keine Rundung; zusätzlich binäres Cross und Drei-Klassen-Cross-OvO mit Brier und `precision = 2`. |
| v0.4 | Manuelle IVAR und CVAR | 10.000 Kalibrierungszeilen insgesamt, 1.000 neue Zeilen; CVAR mit fünf Folds. Je ein Fall mit `m = 1` und mit `epsilon = 0.1`; Moderationsdomäne pro Fold prüfen. |
| v0.5 | Vollständiges Fit/Predict und äußere Bewertung für binär, gemeinsames Drei-Klassen-OvO/OvR und Regression, jeweils Inductive/Cross | 2.000 Entwicklungszeilen, zehn numerische Prädiktoren, 500 neue Zeilen; Inductive-Holdout mit 20 % Kalibrierungsanteil, Cross mit fünf Folds; äußere Bewertung mit drei Folds. |
| v0.6 | Eingefrorene Kalibrierung aller vier Ziel-/Methodenwege; Schema-/Kodierungs-/Dekodierungsaufwand; geordneter Holdout | Gemeinsame Integrationsgröße 2.000/500 und zehn Prädiktoren. Eingefrorene Basis-Workflows vor dem Messfenster auf einem separaten Trainingsbestand fitten; die 2.000 Zeilen dienen ausschließlich der neuen Kalibrierung. Kodierten und unkodierten zulässigen Ablauf sowie gemischten und geordneten Holdout auf vergleichbaren Daten messen. |
| v0.7 | Paarweises OvO und Vollmodell-Übertragung | Gemeinsame Integrationsgröße; drei und zehn Klassen im Paarweg. Binär, gemeinsame OvO/OvR, Paar-OvO und Regression jeweils Inductive/Cross × passend/Vollmodell; feste Parameter. Die Zehn-Klassen-Paarfälle ergänzen die Drei-Klassen-Grundmatrix. |
| v0.8 | Gemeinsames/zweistufiges Tuning, jeweils Grid/Bayes | Gemeinsame Integrationsgröße. Repräsentativ binär passend, Drei-Klassen-Paar-OvO im Vollmodus und Regression im Vollmodus, jeweils Cross mit fünf VA-Folds. Zwei Auswahlresamples je lokaler Suche; eigener Optionsauswahlanteil S von 20 % und endgültiger Fit auf dem Rest, soweit gemeinsame Kalibrierungsoptionen ausgewählt werden. Grid mit vier Kandidaten; Bayes mit vier gültigen Initialkandidaten und höchstens vier weiteren Vorschlägen je Suche. |
| v0.9 | Holdout-/Ensemble-Postprocessing mit passenden Modellen und Vollmodell-Übertragung | Gemeinsame Integrationsgröße und Cross mit fünf VA-Folds. Binäres Sigmoid auf Wahrscheinlichkeiten, Drei-Klassen-Paar-OvO mit Sigmoid, gemeinsames Drei-Klassen-OvO mit Tailor-multinomial und Regression mit Referenzisotonie. Je Holdout mit 20 % P-Anteil oder Ensemble mit drei inneren Folds, jeweils passend/Vollmodell. Zusätzlich ein binärer Vollmodell-Ensemblefall mit zweistufiger Grid-Suche und vier Kandidaten je lokaler Suche. |
| v1.0 | Kumulative Gesamtmessung | Sämtliche bis v0.9 eingeführten Benchmarkfälle erneut ausführen; gemeinsame Fähigkeiten jeweils gegen den Vorgänger vergleichen. Kein neuer spekulativer Größentest allein wegen des Versionsnamens. |

**Referenzmodelle:** Für feste Integrationsfälle logistische Regression mit `stats::glm`, gemeinsame Multiclass-Modelle mit `nnet::multinom`, lineare Regression mit `stats::lm`; Paarmodelle verwenden binäre GLMs. Gelerntes Preprocessing umfasst eine lokal angepasste Normalisierung. Tuningfälle verwenden `rpart`-Bäume mit begrenzter Tiefe, damit tatsächliche Modellparameter ohne teure Basismodelle variiert werden. Konkrete gültige Suchräume, Kalibrierungskandidaten und Seeds werden vor der ersten Messung fixiert; sie sind Benchmarkkonfiguration und kein neuer Produktvertrag. Die vollständige fachliche Abnahme prüft weiterhin alle zugesagten Tuning- und Postprocessingkombinationen.

**Messumfang:** Fit und Predict werden getrennt gemessen. Vollständige äußere Bewertung und Tuning erhalten zusätzlich eine Gesamtlaufzeit einschließlich aller zugehörigen inneren Fits. Die v0.6-Kodierungs-/Dekodierungsoperationen werden separat ausgewiesen. Ein- und Ausgabevalidierung des Produktaufrufs bleiben im Messfenster; Datengenerierung, Paketinstallation und das vorherige Training eingefrorener Workflows nicht. Fit-Zähler und Anzahl der für Predict erhaltenen Modelle beziehungsweise Postprocessor ergänzen die Messwerte der v0.7–v0.9-Fälle.

**Umgebung und Wiederholungen:** Eine dokumentierte Linux-x86_64-Referenzmaschine führt die Messreihe seriell aus, mit dokumentierten CPU-/RAM-/OS-Angaben, festem R-/Abhängigkeitssatz und einem Thread für kontrollierbare Engine-/BLAS-Pools. Der Vorgänger wird auf derselben Maschine und mit derselben kompatiblen Konfiguration erneut gemessen. Vor Messung des jeweils anderen Releases wird ein frischer R-Prozess gestartet. Ein Aufwärmlauf und drei Messläufe werden je Fall und Release durchgeführt; temporäre Fits werden zwischen Messläufen freigegeben. Der Spitzenspeicher ist die separat protokollierte Prozess-Speicherspitze der Fallmessung, keine Behauptung isolierter R-Objektbelegung.

Für die Entwicklung bis v1.0 werden entsprechende lokale Messungen auf macOS
gekennzeichnet. Der Linux-x86_64-Referenzvergleich wird mit der
plattformübergreifenden Abnahme bei v1.0 nachgeholt; Mac- und Linux-Zeiten
werden nicht als direkt vergleichbar ausgegeben.

**Speicherung:** Für gespeicherte kalibrierte Modellobjekte wird zusätzlich die Größe eines mit identischen RDS-Einstellungen geschriebenen Objekts erfasst. Die frische Wiederherstellung und Vorhersagegleichheit bleiben Teil der funktionalen Abnahme. Die Dateigröße ist kein Ersatz für die Speicherspitze beim Fit.

**Vergleichbarkeit:** Daten, Optionen, erwartete Modellzahlen, R-/Paketstände, Messhardware und RDS-Einstellungen werden mit den Ergebnissen gespeichert. Erfordert ein späteres Release eine neue Messumgebung oder ein angepasstes Benchmark-Eingabeformat, wird der Vorgänger soweit kompatibel erneut in derselben Umgebung mit semantisch identischen Eingaben gemessen; Brüche werden ausdrücklich ausgewiesen. Es werden keine Geschwindigkeitsquotienten aus unvereinbaren Bedingungen als Releasevergleich ausgegeben.

### 3.6 Optionale Abhängigkeiten

Der technische Integrationsvertrag nennt folgende konservative Versionsbaselines. Sie bezeichnen den belegten Entwicklungsstand; vollständige Kombinationen auf der vereinbarten R-/Plattformmatrix müssen in der Implementierungsabnahme geprüft werden.

| Teilpaket | Technische Baseline | Verwendung |
|---|---|---|
| parsnip | 1.6.0 | Spezifikation, Registrierung, Predict-Adapter |
| workflows | 1.3.0 | Vollständige Basis-Workflows |
| hardhat | 1.4.3 | Blueprint und öffentliche Extraktoren |
| rsample | 1.3.2 | Lokale Aufteilungen |
| tune | 2.1.0 | Äußere Bewertung, später Suchverfahren |
| yardstick | 1.4.0 | Bewertungsmetriken |
| recipes | 1.4.0 | Gelerntes Preprocessing bei entsprechenden Workflows |
| rlang | 1.2.0 | Spezifikationen |
| tibble | 3.3.1 | Native Ergebnistabellen |
| withr | 3.0.3 | Lokale Zufallszustände |
| generics | 0.1.4 | Dokumentierter Fit-Einstieg |

Die direkten Integrationsabhängigkeiten werden als `Suggests` geführt; es gibt kein obligatorisches tidymodels-Metapaket und keine automatische Paketinstallation beim Laden. Bewertungsaufrufe prüfen ihre zusätzlich erforderlichen Pakete. Tuning ergänzt die tatsächlich benötigten optionalen dials-/tune-Abhängigkeiten; Postprocessing ergänzt seine tatsächlich benötigten optionalen Teilpakete. Die Forschung verwendete unter anderem tailor 0.1.0 und probably 1.2.0; daraus folgt kein ungeprüfter pauschaler Mindestversionsvertrag für alle späteren Kombinationen.

Optionale Registrierung funktioniert bei beiden Ladereihenfolgen, bei bereits geladenem parsnip und in frischen Workerprozessen. Fremde Registrierungen werden nicht überschrieben.

**Verbindlicher Mindest-/Aktuell-Vertrag ab v0.5:** Die acht regulären CI-Kombinationen prüfen aktuelle veröffentlichte Abhängigkeiten. Ein zusätzlicher verpflichtender Linux-Lauf auf der vorherigen R-Minorreihe verwendet die deklarierten Mindestversionen der direkten Integrationspakete mit einem kompatiblen, dokumentierten Satz transitiver Abhängigkeiten. Er prüft die im jeweiligen Release enthaltenen Integrationsabläufe, einschließlich Tuning ab v0.8 und Postprocessing ab v0.9. Es wird nicht die Prüfung jeder denkbaren Versionskombination behauptet. Die tatsächlich installierten Versionen werden für jede Freigabe festgehalten.

Quellen: [Native tidymodels-Schnittstelle und v0.5-Integrationsvertrag konkretisieren][integration-research], dessen [versionierter technischer Vertrag][integration-asset] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Abhängigkeitsprüfung][dependency-decision].

## 4. v0.3 — Multiclass und Klassifikationsoptionen

### Ziel und Umfang

Der manuelle Klassifikationskern erhält einen einheitlichen Optionsvertrag. Binäre Inductive-/Cross-Kalibrierung und alle vier Multiclass-Kombinationen Inductive/Cross × OvO/OvR unterstützen Log Loss/Brier, optionale Rundung, Klassenvorhersagen und die beschlossene Diagnostik.

Log Loss bleibt Standard. `precision = NULL` bedeutet keine Rundung. Andernfalls ist eine einzelne endliche numerische ganze Zahl erlaubt, auch null oder negativ. Die ursprünglichen Wahrscheinlichkeiten werden vor der Rundung validiert. Nur Kalibrierungswahrscheinlichkeiten werden nativ in R gerundet; neue Modellvorhersagen bleiben ungerundet. Bei OvO erfolgt zuerst die Paarnormierung, danach die Rundung. Native R-/NumPy-Rundungsunterschiede werden gesondert dokumentiert.

Für binäre Endpunkte `l,u` gilt der Brier-Punktwert `u + (l²-u²)/2`. Cross-Brier mittelt die Fold-Brier-Punkte gleichgewichtet. Cross-Log behält die stabile Log-Aggregation der Fold-Endpunkte. Die Loss-Wahl ändert Punktwerte, nicht Endpunkte. Erst nach der binären Cross-Zusammenführung folgen OvO-Kopplung beziehungsweise OvR-Normierung.

Multiclass-Truth ist ein Faktor mit mindestens zwei Levels; diese fixieren Klassenuniversum und Ausgabereihenfolge. Wahrscheinlichkeitsmatrizen benötigen vollständige eindeutige Klassennamen, endliche Werte in `[0,1]` und Zeilensummen innerhalb `1e-8` von eins. Innerhalb dieser Eingabetoleranz wird normiert. Bei exakt nullwertiger OvO-Paarsumme gilt vor optionaler Fit-Rundung `(0.5,0.5)`.

Manuelles Cross verwendet einen gemeinsamen Foldplan und nach Fold-ID zugeordnete Modellwahrscheinlichkeiten. Jede Klasse muss global beobachtet sein; einzelne Kalibrierungsfolds dürfen Klassen vermissen. Ein leeres OvO-Paar innerhalb eines Folds ist ein Fehler. Nichtleere Ein-Klassen-/Singleton-Teilkalibrierungen bleiben nach dem jeweiligen Vertrag zulässig.

### Öffentliche Ergebnisse und Release-Grenze

Die vorhandenen Klassifikationseinstiege `venn_abers()` und `cross_venn_abers()` werden erweitert. Multiclass liefert standardmäßig eine Klassenwahrscheinlichkeitsmatrix; `type = "class"` einen Faktor und `type = "details"` rekonstruierbare binäre Diagnosen mit Klassen-/Paar-/Fold-Identität.

Binär gewinnt bei einer endgültigen Ereigniswahrscheinlichkeit von mindestens 0.5 das Ereignis. Multiclass wählt die höchste endgültige Klassenwahrscheinlichkeit und bei Gleichstand das erste gespeicherte Level, auch bei genau zwei Klassen im Multiclass-Vertrag. Beide Regeln bleiben getrennt.

`log_loss()`, `brier_score()` und `calibration_plot()` werden um Multiclass erweitert. Der manuelle Multiclass-Brier ist die mittlere Summe der quadrierten Klassenfehler ohne Division durch zwei oder Klassenanzahl. Log Loss clippt nicht; Wahrscheinlichkeit null für die beobachtete Klasse ergibt `Inf`. Plots verwenden endgültige Klassenwahrscheinlichkeiten.

Modelltraining und automatische Aufteilungen folgen in v0.5; paarweises Modelltraining folgt in v0.7. v0.3 kalibriert vom Aufrufer gelieferte Vorhersagen.

### Geordnete Umsetzung

1. Binäre Rundungsvalidierung, Brier-Merger, Klassenregel und öffentliche Cross-Fold-Ergebnisse ergänzen.
2. Klassen-/Matrixvertrag und gemeinsame Optionsübergabe in den bisherigen Einstiegspunkten ergänzen.
3. Inductive OvO/OvR auf dem binären Kern implementieren; Cross mit binärer Zusammenführung vor der Multiclass-Kopplung ergänzen.
4. Konsistente Wahrscheinlichkeits-, Klassen- und Diagnoseausgaben sowie Multiclass-Scores und Plots vervollständigen.
5. Numerische Abnahme, Randfälle, bisherige binäre Kompatibilität, ausführbare Beispiele und gemeinsame Release-Prüfungen abschließen.

### Überprüfbare Abnahme

- Alle vier Multiclass-Verfahren mit beiden Loss-Optionen und Rundungsfällen; zwei, drei und vier Klassen; feste und reproduzierbare zufällige Referenzfälle.
- Binäre und Multiclass-Endergebnisse aus öffentlichen Fold-/Paar-Diagnosen rekonstruieren; ungleiche Foldgrößen unterscheiden Gleichgewichtung von Größenwichtung und Pooling.
- Null-Paarsummen einschließlich `precision = 0`, Bindungen, Extrapolation, fehlende Klassen, leere Teilprobleme, vertauschte Namen sowie Null-/Einzeilenausgaben prüfen.
- Loss-Wechsel lässt Endpunkte unverändert. Vorhersagen bei exakt 0.5 beziehungsweise Multiclass-Gleichstand erfüllen ihren jeweiligen Vertrag.
- Scores und Plot-Gruppenwerte durch unabhängige kleine Rechnungen prüfen; bestehende binäre Beispiele und Tests erhalten.

Detailquellen: [Multiclass-Umfang und Abnahme für v0.3 festlegen][multiclass], [Zusätzliche binäre Kalibrierungsoptionen und Paritätsgrenzen festlegen][binary], [Brier und Rundung für Multiclass bis v1.0 festlegen][multiclass-options].

## 5. v0.4 — Moderierte Regression

### Ziel und Umfang

Die eigenen Einstiegspunkte `venn_abers_regression()` und `cross_venn_abers_regression()` bieten manuelle IVAR/CVAR für endliche reellwertige Ziele und Modellvorhersagen. Auch numerische Ziele 0/1 bleiben Regression. Modelltraining und Aufteilung liegen zunächst beim Aufrufer.

Ohne ausdrückliche Angabe gilt `m = 1`. Für jede Kalibrierungsgröße `k` muss `1 <= m <= floor((k-1)/2)` gelten. Alternativ wird `0 < epsilon < 1` angegeben; pro Fold gilt `m_f = floor(epsilon*(k_f+1)/2)` mit derselben Gültigkeitsprüfung. Das wirksame Niveau ist `2*m_f/(k_f+1)`. Beide Parameter gleichzeitig ausdrücklich anzugeben ist ein Fehler. Unzulässige Parameter werden nicht gekappt; schon `m = 1` benötigt mindestens drei Kalibrierungsbeobachtungen pro Fold.

Asymmetrische Moderation ersetzt Extremwerte statt Beobachtungen zu entfernen. IVAR verwendet den gewichteten Punktmerger: bei Grenzen `L,U` und äußeren Grenzen `a,b` sind die Gewichte `w_L=L-a`, `w_U=b-U`; bei positiver Gewichtssumme gilt `(w_L*L+w_U*U)/(w_L+w_U)`. Sind beide Gewichte exakt null, wird der Mittelpunkt verwendet. Konstantfälle bleiben endlich. Kleine positive Gewichte werden nicht pauschal als null behandelt.

CVAR berechnet vollständige Punkte und Grenzen je Fold und mittelt jede dieser Größen separat gleichgewichtet. Es wird weder gepoolt noch erst auf gemittelten Grenzen ein neuer Punktmerger ausgeführt.

### Ergebnisse und Release-Grenze

Standardausgabe ist ein Dataframe mit Double-Spalten `prediction`, `lower`, `upper`; null und eine neue Zeile behalten das Schema. Cross-Details enthalten die zugeordneten Fold-Ergebnisse. Angeforderte und wirksame Moderationsparameter bleiben nachvollziehbar.

Die Grenzen betreffen regularisierte bedingte Erwartungswerte. Gemittelte Cross-Grenzen sind beschreibende Aggregate; keine pauschale Vorhersageintervall- oder Coverage-Zusage. RMSE-/MAE-Beispiele verwenden Base R. Zusätzliche Regressions-Score-/Plot-Funktionen, ein wählbarer exakter Minimax-Merger, Beobachtungsgewichte oder Regressions-Rundung gehören nicht zu diesem Zuschnitt.

### Geordnete Umsetzung

1. Reellwertigen Kern, Moderation und Validierung aufbauen und bestehende Klassifikation erhalten.
2. IVAR-Fit/Predict einschließlich gewichteten Mergers, Nullgewichtsregel und Konstantfällen ergänzen.
3. CVAR mit passenden Fold-Modellen, foldweiser Moderation und getrennten Mittelwerten ergänzen.
4. Standard-/Diagnoseausgaben und effektive Parameter vervollständigen.
5. Referenz-/Randfalltests, ausführbare RMSE-/MAE-Beispiele und gemeinsame Release-Abnahme abschließen.

### Überprüfbare Abnahme

- Deterministische und zufällige IVAR-/CVAR-Fälle gegen gültige Referenzkomponenten und unabhängige Kleinrechnungen prüfen; den nicht vorhandenen manuellen Python-Wrapper nicht als Vergleichs-API voraussetzen.
- Kleine/große/verschobene Zielskalen mit vorab festgelegter Einheitenskala testen.
- Konstantfälle, zwei Nullgewichte bei nicht konstanten Zielen, kleine positive Gewichte, Ties, äußere Vorhersagebereiche und Moderationsgrenzen abdecken.
- Ungleiche Folds, vertauschte/fehlende/doppelte Modellspalten und null/eine Vorhersage prüfen. Punkte und Grenzen aus Fold-Ergebnissen rekonstruieren.
- Klassifikationskompatibilität, installierte Beispiele und sämtliche gemeinsamen Release-Kriterien erfüllen.

Detailquelle: [Regressionsumfang und Abnahme für v0.4 festlegen][regression].

## 6. v0.5 — Native tidymodels-Grundabläufe

### Ziel und Umfang

Ein eigener parsnip-Modelltyp stellt den vollständigen kalibrierten Prädiktor in einem normalen Workflow dar. Der Basis-Workflow einschließlich Recipe wird innerhalb jedes zulässigen lokalen Trainingsanteils gelernt. Der äußere Workflow dient als Rohdaten-Carrier; er darf vor der inneren Aufteilung kein global gelerntes Preprocessing einschleusen.

Alle acht Kombinationen aus binär, gemeinsamem Multiclass OvO, gemeinsamem Multiclass OvR und Regression × Inductive/Cross gehören dazu. Die numerischen Optionen aus v0.3/v0.4 bleiben erreichbar. Normale Fit-/Predict- und vollständige `fit_resamples()`-Abläufe verwenden die gespeicherten passenden Modelle.

Automatische rsample-Aufteilungen besitzen dokumentierte Parameter und reproduzierbare Zufallssteuerung. Explizite lokale Pläne sind ebenfalls unterstützt. Vorbereitete Zuordnungen binden einen kanonischen lokalen Datenbestand an genau einen Plan; gleiche Zeilenzahl allein reicht nicht. Widersprüchliche vorbereitete Pläne für identische Daten werden abgewiesen. Beliebige Callbacks werden nicht als statisch beweisbar dargestellt.

### Ausgabe, Fehler und vorübergehende Grenzen

Native Ausgaben sind `.pred_<Klasse>`, `.pred_class` beziehungsweise `.pred`. Die gesonderte Diagnostik erhält die methodenspezifischen Grenzen und Fold-Ergebnisse. Regression verwendet für ihre VA-Grenzen weder `conf_int` noch `pred_int`.

yardstick behält seine Konventionen. Insbesondere beträgt sein Multiclass-Brier die Hälfte des manuellen Scores. Ereignisklasse, Loss-Vorgabe für äußere Bewertung und Klassenregeln werden konsistent behandelt.

Der erste trainierbare Zugang verwendet untrainierte konfigurierte Basis-Workflows ohne zusätzlichen Postprocessor und ohne automatische innere Hyperparametersuche. Problematische native Namen werden früh und verständlich abgewiesen, ohne automatische Reparatur. Eingefrorene Übernahme und explizite Kodierung folgen in v0.6, Paartraining/Vollmodell in v0.7, Tuning in v0.8, neu gelerntes Postprocessing in v0.9.

### Geordnete Umsetzung

1. Optionale öffentliche parsnip-Registrierung, Spezifikation und gemeinsame Kernadapter aufbauen.
2. Lokale Workflow-Fits und passende gespeicherte Predict-Pfade mit den vorhandenen VA-Kernen verbinden.
3. Automatische/explizite Aufteilungen, lokale Identitätsprüfung, frühe Namen-/Modusfehler und RNG-Vertrag vervollständigen.
4. Native Ausgaben, Diagnostik, yardstick und vollständige äußere Bewertung anbinden.
5. Acht Verfahrenswege, Datenrollen, frische Worker, optionale Paketinstallation und installierte Beispiele abnehmen.

### Überprüfbare Abnahme

- Alle acht Wege bei festen Modellvorhersagen und Aufteilungen gegen die manuellen Kerne vergleichen.
- Gelerntes Preprocessing und Modelltraining durch instrumentierte Datenrollen prüfen; Änderungen ausschließlich äußerer Bewertungsziele dürfen den Fit und seine Vorhersagen nicht ändern.
- Bei fünf äußeren und fünf inneren Cross-Folds entstehen ohne zusätzliche Suche 25 Basisfits; kein verdeckter Vollmodell-Fit.
- Ungültige innere Partitionen, globale Positionspläne auf fremden lokalen Daten, Klassen-/Namenskollisionen und fehlgeschlagene Teilfits erkennen.
- Ausgaben, Ereignisklasse, Brier-Skala und vollständige äußere Assessment-Abdeckung prüfen. Fehlende Fit-/Metrikergebnisse werden sichtbar.
- Manuelle Kernnutzung ohne tidymodels, beide Ladereihenfolgen und frische Worker testen.

Detailquellen: [tidymodels-Abläufe für v0.5 und Ausbau bis v1.0 abgrenzen][integration], [Native tidymodels-Schnittstelle und v0.5-Integrationsvertrag konkretisieren][integration-research], [Namens- und Sonderfallgrenzen der nativen tidymodels-Integration entscheiden][initial-boundaries].

## 7. v0.6 — Eingefrorene Workflows, Namen und Referenzaufteilungen

### Ziel und Umfang

`calibrate_workflow()` übernimmt vollständig trainierte tidymodels-Workflows und kalibriert deren endgültige Vorhersagen auf neuen separaten Kalibrierungsdaten. Modell, gelerntes Preprocessing und vorhandenes Postprocessing bleiben unverändert. Unterstützt sind binär, gemeinsames Multiclass OvO/OvR und IVAR, jeweils Inductive. Es entsteht kein Cross-Ensemble aus einem einzelnen eingefrorenen Workflow.

Direkte Adapter für einzelne parsnip-Fits oder extrahierte Engines gehören nicht dazu; deren externe Vorhersagen bleiben über die manuellen Kerne nutzbar.

Die expliziten Hilfsfunktionen `venn_abers_schema()`, `venn_abers_encode()` und `venn_abers_decode()` ermöglichen reversible Namen. Das feste Schema bewahrt bijektive Spalten-/Klassenzuordnungen, Klassenreihenfolge und Ereignisidentität. Neue Basis-Workflows und äußere Resamples werden ausdrücklich auf dem kodierten Schema aufgebaut. Es gibt keine automatische Umformulierung bestehender Recipes.

Native Ausgaben bleiben kodiert; die dekodierte Sicht hält Wahrscheinlichkeiten, Klasse, Wahrheit, ursprünglichen Zielnamen, Identitäten und vorhandene Diagnostik in getrennten Rollen. Dadurch kollidieren beispielsweise Originalklasse `class` und Originalziel `.pred_class` nicht. Fehlende Ergebnisarten werden nicht erfunden.

Eingefrorene Workflows erhalten ihr beim Training verwendetes Schema. Ein nachträglich erzeugtes Schema erlaubt weder Refit noch interne Umbenennung noch Umgehen eines Postprocessors. Kann ein alter Workflow keinen gültigen vollständigen Predict-Pfad liefern, gilt der dokumentierte Fehlervertrag. Ein begrenzter GLM-Rohzugriff ist keine Zusage universeller Engine-Fallbacks.

Referenzaufteilungen umfassen Inductive-Holdouts mit und ohne Mischen, insbesondere Erhalt vorgegebener Zeilenreihenfolge, sowie gewöhnliche/stratifizierte Cross-Partitionen. Cross trainiert weiterhin auf dem Komplement des gehaltenen Folds. Geordnete Holdouts werden nicht als allgemeine Zeitreihenvalidierung bezeichnet. Die spätere Paarvariante übernimmt in v0.7 denselben Vertrag lokal je Klassenpaar.

### Geordnete Umsetzung

1. Gemeinsame Schema-/Zuordnungsfunktionen und explizite kodierte Ein-/Ausgänge ergänzen.
2. Eingefrorenen Workflow-Eingang samt Zustands-, Klassen- und Datenprüfung anbinden; vollständigen Original-Predict verwenden.
3. Schema in trainierbaren und eingefrorenen Zuständen erhalten; native Collector und getrennte dekodierte Diagnosen verbinden.
4. Vollständige Referenzoptionen der lokalen Aufteilungen und deren Rollenprüfungen ergänzen.
5. Frische Speicherung, Fehlerfälle, Beispiele und kumulative Integrationsabnahme abschließen.

### Überprüfbare Abnahme

- Vier eingefrorene Varianten gegen manuelle Kalibrierung derselben endgültigen Workflow-Vorhersagen prüfen; Lernwächter belegen unveränderte Modell-/Pre-/Postprocessing-Zustände.
- Besondere Klassen-/Zielnamen, vertauschte benannte Spalten, unbekannte Klassen und fremde Schemata prüfen; keine stillen Reparatursuffixe oder überschriebenen Wahrheiten.
- Native und dekodierte Ergebnisse samt Identitäten und Diagnostik nach `saveRDS()`/`readRDS()` in einem frischen R-Prozess erhalten, soweit die geprüfte Engine diesen Speicherweg unterstützt.
- Geordnete Holdouts bewahren Reihenfolge und Rollen; unzulässige Vorwärtspläne werden nicht als gewöhnliches Cross akzeptiert.
- Wiederholte äußere Bewertung auf genaue `(id, id2, .row, .config)`-Abdeckung prüfen; ein globaler Aufrufzähler ersetzt keine lokale Planidentität.

Detailquellen: [Kalibrierung bereits trainierter Modelle und Workflows festlegen][frozen], [Reversible Namenskodierung für native und eingefrorene Workflows festlegen][names], [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen][splits], [Vorläufige Integrationsgrenzen gegen die vollständige Python-Parität prüfen][boundaries].

## 8. v0.7 — Paartraining und Vollmodell-Übertragung

### Ziel und Umfang

Fünf Wege werden jeweils mit Inductive/Cross und passend/Vollmodell angeboten: binär, gemeinsames Multiclass OvO, gemeinsames Multiclass OvR, paarweises binäres OvO-Modelltraining und Regression. Das sind **20 Verfahrenskombinationen**, zunächst mit festen Modell-/Recipe-/Kalibrierungseinstellungen.

Die geplanten Optionen heißen `prediction_model = "matched"/"full"` und `model_training = "shared"/"pairwise"`. Passende Modelle und gemeinsames Multiclass-Training bleiben Standard. Paartraining setzt OvO voraus. Der Modus wird beim Fit festgelegt; ein Predict-Schalter ersetzt keinen neuen Fit.

Jedes Klassenpaar erhält eigene binäre Modelle und lokale Aufteilungen. Vollmodell bedeutet im Paarweg den vollständigen zulässigen Bestand dieses Paars. Gehaltene Kalibrierungsvorhersagen stammen weiterhin aus Quellmodellen, deren vollständiges Lernen die jeweiligen Kalibrierungsdaten ausgeschlossen hat. Vollmodell-Übertragung ersetzt weder diese Vorhersagen durch In-sample-Werte noch einzelne Kalibratoren durch einen gepoolten Kalibrator.

Im Vollmodell-Modus bleiben Vollmodelle, Kalibratoren, gehaltene Kalibrierungswerte und erforderliche Identitäts-/Parameterdaten erhalten. Nur für die Kalibrierungsquellen benötigte Modelle werden nach erfolgreichem Fit verworfen. Im passenden Modus bleiben sämtliche zur Vorhersage benötigten Quellmodelle erhalten. Es gibt keinen zusätzlichen Aufbewahrungsschalter in diesem Vertrag.

Die mathematischen Aussagen passender Modell-/Kalibrierungspfade werden nicht automatisch auf Vollmodell-Übertragung übertragen. Automatische lokale Parameterwahl folgt in v0.8; die v0.7-Teilgrenze verkleinert nicht den endgültigen Vollmodellvertrag.

### Geordnete Umsetzung

1. Modellmodi und Paar-/Fold-Identitäten an der vorhandenen Spezifikation ergänzen.
2. Lokale Paaraufteilungen und passende Quellmodelle mit bestehenden binären Kernen verbinden.
3. Zusätzliches Vollmodell-Fit auf dem zulässigen lokalen Gesamtbestand und dessen Predict-Zuordnung ergänzen.
4. Aufbewahrung, Diagnostik und tatsächliche Fit-/Predict-Kosten absichern.
5. Alle 20 festen Verfahren, Namenskodierung, Referenzaufteilungen und vollständige äußere Bewertung abnehmen.

### Überprüfbare Abnahme

- Jede der 20 Kombinationen ausführen; Paarmodelle und gemeinsame Multiclass-Modelle anhand ihrer Daten und Vorhersagen unterscheiden.
- Quell-/Vollmodellrollen instrumentieren; gehaltene Kalibrierungswerte bleiben nach dem Vollmodell-Fit unverändert.
- Ohne Suche entstehen pro Domäne bei Inductive 1/2 und bei Cross K/K+1 Basisfits für passend/Vollmodell. Im Paarweg werden diese Zahlen über Paare summiert.
- Klassen-, Paar- und Fold-Zuordnung, Aggregation, aufbewahrte Zustände und frische Speicherung prüfen; Predict trainiert nichts und vermeidet doppelte Modellvorhersagen.
- Gleiche feste Eingaben gegen die jeweiligen Referenz-/Kernverfahren prüfen. Ein Trainingsvergleich zwischen unterschiedlichen Engines ersetzt keinen isolierten Kernvergleich.

Detailquelle: [Vollmodell-Alternative für vollständige Python-Parität festlegen][full] und der [angenommene vollständige Modellvertrag][full-asset].

## 9. v0.8 — Vollständiges Tuning

### Ziel und Umfang

Gemeinsame Auswahl bewertet kalibrierte Endvorhersagen; zweistufige Auswahl bestimmt zuerst Modell-/Recipe-Einstellungen anhand unkalibrierter Vorhersagen und anschließend Kalibrierungsoptionen bei festgehaltener erster Stufe. Beide Strategien unterstützen Grid und kontrollierte Bayes-Suche für alle bis v0.7 eingeführten Trainingsverfahren einschließlich Paar-/Vollmodellwegen. Feste Teilmengen von Parametern bleiben möglich.

Klassifikation erlaubt Log/Brier und eine endliche kategoriale Auswahl von Rundungswerten einschließlich keiner Rundung. Regression erlaubt `m` oder `epsilon`. Methodenfamilie, Kalibrierungsanteil und Foldzahl bleiben je Suchlauf fest. Verfahrensvergleiche erfolgen durch vollständige Läufe auf gemeinsamen Auswahlaufteilungen.

### Daten, Auswahl und Betrieb

Lokale Modell-/Recipe-Auswahl bleibt vollständig innerhalb des zugehörigen Modelltrainingsanteils. Cross-Foldmodelle dürfen unterschiedliche Einstellungen wählen. Gemeinsame Kalibrierungsoptionen werden bei automatischer Auswahl auf einem ausdrücklich konfigurierten separaten Auswahlanteil S gewählt. S wird nicht in den endgültigen Fit-Bestand F zurückgeführt. Äußere Assessment-/Testdaten bleiben ausgeschlossen.

Ein Vollmodell erhält bei automatischer Suche eine eigene lokale Parameterwahl nach derselben Regel auf seinem zulässigen Bestand. Fold-Parameter werden weder gemittelt noch beliebig übernommen. Die Wahl bewertet bereits das ausgewählte vollständige passende beziehungsweise Vollmodellverfahren.

Nur Kandidaten mit vollständigen Vorhersagen und endlicher gültiger Hauptmetrik auf sämtlichen vorgesehenen Resamples sind auswählbar. Zusätzliche Berichtsmetriken werden isoliert behandelt. Standard-Hauptmetriken sind Log Loss beziehungsweise RMSE; geeignete andere Metriken und unterschiedliche Metriken der beiden Stufen sind erlaubt. Bei exaktem Gleichstand entscheidet die stabile Kandidatenreihenfolge.

Bayes verwendet gültige Initialergebnisse und öffentliche schrittweise Fortsetzung. Unvollständige Kandidaten gelangen nicht in den nächsten Gaussian Process. Budgets zählen auch Fehler und wiederholte Vorschläge; globale IDs, `no_improve`, Zeitgrenzen zwischen vollständigen Schritten und Abbruchgründe werden erhalten. Es gibt keinen stillen Suchverfahrenswechsel oder Ersatzkandidaten nach fehlgeschlagenem finalem Fit.

Nur eine Ebene wird gleichzeitig parallelisiert. Seeds, Pläne, Suchkonfiguration und Versuchshistorie bleiben gespeichert; Reproduzierbarkeit bezieht sich auf dieselbe geprüfte Konfiguration und reproduzierbare Engines, nicht auf bitweise Gleichheit beliebiger Plattformen.

Ein enger dokumentierter Sonderfall vergleicht Log/Brier nach eingefrorenem Fit auf neuen separaten Validierungsdaten. Bestehende Predict-/yardstick-Bausteine reichen; keine neue Komfortfunktion oder Nachschulung. v0.8 dokumentiert diesen Weg im Zusammenhang der Auswahlverfahren.

### Geordnete Umsetzung

1. Parameterabbildung, eindeutige IDs und native Finalisierung ergänzen.
2. Feste Fits, lokale Modellauswahl, vollständige Kandidaten und separate gemeinsame Optionsauswahl in endlicher Verschachtelung verbinden; zuerst Grid für beide Strategien.
3. Dieselben Regeln auf Paartraining und Vollmodelle anwenden.
4. Strenge Kandidatenprüfung, isolierte Berichtsmetriken und schrittweise Bayes-Fortsetzung ergänzen.
5. Budgets, Seeds, eine Parallelitätsebene, Diagnostik und Speicherzustände vervollständigen; gesamte Abnahme ausführen.

### Überprüfbare Abnahme

- Beide Strategien und Grid/Bayes für die unterstützten Verfahrensfamilien; Modell-/Recipe-Parameter tatsächlich variieren und feste Parameter unverändert lassen.
- S/F- sowie Kalibrierungs-/Trainingsausschlüsse instrumentieren. Eine absichtlich eingeschleuste Kalibrierungsbeobachtung muss die Prüfung scheitern lassen.
- Einen fehlgeschlagenen Fold, fehlende/doppelte Vorhersagezeilen, nur fehlerhafte Zusatzmetriken, wiederholte Bayes-Vorschläge und fehlende gültige Initialpunkte gezielt prüfen.
- Vollmodellwahl erfolgt eigenständig; finale Fits, Kosten und gespeicherte lokale Einstellungen lassen sich rekonstruieren.
- `fit`, `predict`, `fit_resamples`, `last_fit`, frische Worker und die zulässige Parallelkonfiguration abnehmen. Numerische Ergebnisse bleiben aus manuellen Kernen rekonstruierbar.

Detailquellen: [Tuning des vollständigen kalibrierten Verfahrens bis v1.0 festlegen][tuning], [angenommener Tuningvertrag][tuning-asset] und [Vollmodell-Alternative für vollständige Python-Parität festlegen][full].

## 10. v0.9 — Gelerntes Postprocessing und innere Ensembles

### Ziel und endliche Unterstützungsmatrix

Neu trainierte Basiskompositionen erhalten zusätzliches Holdout-Postprocessing oder ein inneres Cross-Kalibrierungsensemble. Jede unten aufgeführte Methode gilt für beide Strategien, Inductive/Cross-VA und passend/Vollmodell.

| Äußerer VA-Weg | Zusätzliche Methoden | Kombinationen |
|---|---|---:|
| Binär | sklearn-Sigmoid, Tailor-logistisch | 16 |
| Paarweises OvO-Training | sklearn-Sigmoid, Tailor-logistisch | 16 |
| Gemeinsames Multiclass ab drei Klassen, OvO | Tailor-multinomial | 8 |
| Gemeinsames Multiclass ab drei Klassen, OvR | Tailor-multinomial | 8 |
| Gemeinsames Zwei-Klassen-Modell, OvO | Tailor-logistisch | 8 |
| Gemeinsames Zwei-Klassen-Modell, OvR | Tailor-logistisch | 8 |
| Regression | Numerische Referenzisotonie, Tailor-linear | 16 |
| **Gesamt** | | **80** |

Tailor-Methoden verwenden `smooth = FALSE`. Genau zwei Klassen im gemeinsamen OvO-/OvR-Weg behalten den Multiclass-VA-Vertrag; Multinomialwahl ist dafür unzulässig. Die 80 Kombinationen zählen zusätzliche Engine-, Namens-, Loss-, Rundungs-, Moderations- und Tuningprüfungen nicht mit.

### Lokale Datenrollen und Verfahren

Ein ausdrückliches `postprocessing`-Listenargument erweitert den trainierbaren Konstruktor. Methode, Strategie und automatische Anteile/Foldzahlen werden bewusst konfiguriert; gültige explizite lokale Pläne sind alternativ möglich.

B lernt Recipe, Engine und deren Einstellungen. Das davon getrennte P lernt den Postprocessor. Bei inneren Ensembles gilt das je Modell-/Postprocessor-Paar; die P-Folds bilden eine vollständige Partition. Die endgültigen Vorhersagen dieser vollständigen Paare werden gleichgewichtet gemittelt, bevor sie in den äußeren unveränderten VA-Kern eingehen. VA-Kalibrierungsdaten C bleiben vom zugehörigen Quelltraining ausgeschlossen. Äußere Bewertung und separat zurückgehaltene Auswahlanteile gelangen nicht in finale B/P-Fits.

Sigmoid verwendet ausdrücklich Wahrscheinlichkeiten oder den begrenzten `glm_link`-Zugang für binomiale GLM-Workflows mit Logit-Link. Numerische Isotonie folgt der Referenz mit linearer Interpolation und konstanter Randfortsetzung. Tailor verwendet den vollständigen gespeicherten Workflow-Predict. Sigmoid und Tailor-logistisch sind keine numerisch austauschbaren Methoden.

Bei Klassifikation braucht B alle Klassen des lokalen Modells. Sigmoid/logistisches P braucht beide Klassen; multinomiales P alle gespeicherten Klassen. P benötigt mindestens zwei Zeilen; parametrische Tailor-Fits zusätzlich genügend Zeilen und volles Rangvermögen nach dem Detailvertrag. Für logistische/lineare Zwei-Koeffizienten-Fits sind mindestens drei Zeilen nötig. Zulässige Ein-Klassen-C-Fälle der VA-Kerne bleiben davon getrennt.

Keine stille Umstellung auf `none`, Foldzahlreduktion, Ersatzmethode oder unvollständige Ensembles. Rang- und Konvergenzfehler werden in der jeweils tatsächlich erkennbaren Lernstufe gemeldet.

### Tuning, Vollmodell und Speicherung

Die v0.8-Auswahl wird auf das jeweilige B beschränkt. Das zugehörige P beeinflusst die B-Suche nicht. Methodenfamilie, Sigmoid-Eingang, Strategie und Planparameter bleiben pro Suchlauf fest. Gemeinsame/zweistufige Auswahl, Grid/Bayes und Fehler-/Budgetregeln gelten für die vollständigen Kompositionen.

Vollmodell bezeichnet den gesamten auf seinem zulässigen Fit-Bestand trainierten Verbund mit eigenen B/P-Aufteilungen. Es bedeutet nicht, dass jede Engine auf allen Beobachtungen lernt. Ursprüngliche gehaltene C-Vorhersagen und VA-Kalibratoren bleiben erhalten. Alle für Predict benötigten vollständigen Verbünde, Schemata und Diagnosen werden gespeichert; reine C-Quellverbünde können nach erfolgreichem Vollmodell-Fit verworfen werden.

### Geordnete Umsetzung

1. Listenargument und gemeinsame lokale B/P-Validierung an die bestehende Quellfit-Stelle anbinden.
2. Feste Tailor-Holdouts, ausdrückliche Sigmoid-Eingänge und numerische Referenzisotonie implementieren; jeweils isoliert prüfen.
3. Innere Ensembles aus denselben vollständigen Paarfits und gleichgewichteter Mittelung bilden.
4. In sämtliche VA-, Paar- und Vollmodellwege integrieren; C-Quellen und Speicherregeln erhalten.
5. Lokale Grid-/Bayes-Suche auf B begrenzen und Kosten-/Seed-/Diagnosevertrag erweitern.
6. Vollständige Matrix, numerische Schichten, Datenrollen, native Bewertung, Speicherung und Paketbetrieb abnehmen.

### Überprüfbare Abnahme

- Alle 80 Kombinationen durch Fit/Predict und vollständige native äußere Bewertung führen; zusätzliche Options-, Namens-, Engine- und Tuningachsen gezielt prüfen.
- Postprocessor gegen eigene Referenz prüfen, dann innere Mittelung, anschließend den identischen manuellen VA-Kern. End-to-End-Ähnlichkeit zwischen verschieden trainierten Engines ersetzt keine dieser Schichten.
- Änderungen ausschließlich an P dürfen B-Suche/Engine/Recipe nicht ändern. Änderungen an C dürfen den zugehörigen Quellverbund nicht ändern; beim zusätzlichen Vollmodell dürfen sie dessen Fit beeinflussen. Äußere A-Daten bleiben ausgeschlossen.
- Ungültige Pläne, fehlende B-/P-Klassen, erlaubte C-Randfälle, Rangmangel, Nichtkonvergenz und stille Methodenwechsel unterscheiden.
- Gemeinsame/zweistufige Grid-/Bayes-Suche, unvollständige Kandidaten und Budgets auch mit inneren Paaren prüfen.
- Das Vertragsbeispiel mit drei Klassenpaaren, fünf VA-Folds und drei inneren Folds im Vollmodus benötigt 54 Engine- und 54 Postprocessor-Fits; neun Modell-/Postprocessor-Paare bleiben für Predict erhalten. Mit Zählern nachweisen.
- Vollständige Vorhersagepfade und Diagnosen in frischen R-Prozessen wiederherstellen; keine doppelten Postprocessor-Aufrufe und kein Lernen bei Predict.

Detailquellen: [Zusätzlich gelerntes Postprocessing und innere Datenverträge bis v1.0 festlegen][postprocessing] und [angenommener Postprocessing-Vertrag, Abschnitte 1 bis 10][postprocessing-asset].

## 11. v1.0 — Paritätsnachweis, Stabilität und Veröffentlichungsreife

### Ziel und Umfang

v1.0 stabilisiert den bis v0.9 vorhandenen vollständigen Funktionsumfang. Alle bisherigen fachlichen Verträge, die gemeinsame CI-Matrix und die dokumentierten R-Erweiterungen bleiben enthalten. Die öffentliche 1.x-Kompatibilitätszusage beginnt mit dieser Version.

Ein vollständig CRAN-vorbereitetes GitHub-Release genügt. Eine erfolgreiche CRAN-Aufnahme ist kein Freigabekriterium. Die eigentliche Veröffentlichung und Einreichung gehören zur späteren Umsetzung, nicht zur aktuellen Planungs-Map.

### Verbindliche CRAN-Vorbereitung

1. **Quellpaket:** aus dem Release-Stand gebaut, sauber installierbar, mit fehlerfrei erzeugtem PDF-Handbuch.
2. **Metadaten:** echte Maintainer-Kontaktdaten, korrekte Urheber-/Lizenzangaben, Literaturverweise und geprüfter Paketname. Die gegenwärtige Platzhalteradresse wird vor Freigabe ersetzt.
3. **Paketbetrieb:** korrekt deklarierte Abhängigkeiten, bedingte Nutzung optionaler Pakete. Reguläre Tests und Beispiele benötigen weder Python noch Netzwerkzugriff. Python bleibt Werkzeug der gesonderten Referenzerzeugung/-prüfung.
4. **Prüflast:** kurze Beispiele und begrenzte Parallelität. Umfangreiche Benchmarks laufen separat und bleiben Bestandteil der Release-Abnahme.
5. **Freigabenachweis:** vollständige CI-Ergebnisse, einzeln begründete NOTEs, vorbereitete `cran-comments.md` und abschließender Abgleich mit den dann geltenden CRAN-Regeln.

Die [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) und [Writing R Extensions: Checking packages](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) sind die geprüften Ausgangsquellen. Ihre Anforderungen werden bei der tatsächlichen Freigabe erneut abgeglichen; dieses Planungsdokument behauptet keine bereits erteilte CRAN-Freigabe.

### Geordnete Umsetzung und abschließende Abnahme

1. Vollständige Fähigkeitsmatrix auf den tatsächlich implementierten Stand beziehen und jede Zeile mit ihrer ausführbaren Evidenz verknüpfen.
2. Sämtliche manuellen, trainierbaren, eingefrorenen, Tuning- und Postprocessing-Wege kumulativ prüfen; verbleibende Fehler beseitigen.
3. Öffentliche Funktionen, Argumente und Ausgabeformate abschließend auf Konsistenz prüfen; Migrationshinweise und Dokumentation vervollständigen.
4. Referenzdefekte, R-Abweichungen und R-Erweiterungen einzeln dokumentieren; keine ungeklärte Fähigkeitslücke als vollständige Parität ausgeben.
5. Performancevergleiche und Speicherprüfungen abschließen; Regressionen untersuchen und begründen.
6. Die acht verpflichtenden CI-Kombinationen, den Mindestversionslauf, den Kernlauf ohne tidymodels und die dokumentierte R-devel-Einordnung nachweisen.
7. Quellpaket, PDF-Handbuch, Metadaten, NEWS, Beispiele und CRAN-Kommentare prüfen. Erst nach Erfüllung aller Kriterien ist das Produkt veröffentlichungsreif.

Bestätigung: [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Veröffentlichungsreife][publication-decision] und [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — konkrete CRAN-Vorbereitung][cran-decision].

## 12. Fähigkeitszuordnung für die abschließende Paritätsprüfung

Die Tabelle ordnet die untersuchten Fähigkeiten und beschlossenen R-Ergänzungen einem Release zu. Sie ist ein Abnahmeindex; die vollständigen Randfälle und Detailverträge stehen in den oben verlinkten Quellen.

| Fähigkeit | Erste geplante Abdeckung / Ausbau | Wesentlicher Nachweis |
|---|---|---|
| Binärer manueller Inductive-/Cross-Log-Kern | Bereits v0.2; erhalten in allen Releases | Vorhandene numerische Fixtures und stabile Cross-Aggregation |
| Binäres Brier, Rundung, Klassen und Fold-Diagnostik | v0.3; native Nutzung v0.5 | Formeln, Rundungsreihenfolge, Ereignisregel, Rekonstruktion |
| Manuelles Multiclass OvO/OvR | v0.3 | Kopplung/Normierung, Klassenidentität, Referenzkomponenten |
| Manueller Cross-Multiclass-Vertrag und einheitliche Optionen | v0.3; native Nutzung v0.5 | Gemeinsamer Foldplan, binäre Aggregation vor Multiclass; R-Ergänzungen ausweisen |
| Moderierte IVAR/CVAR mit m/epsilon und Fold-Ergebnissen | Manuell v0.4; modellgestützt v0.5 | Moderation, gewichteter Merger, gleichgewichtete Cross-Mittelung |
| Modelltraining, Preprocessing und passende Foldmodelle | v0.5 | End-to-End-Datenrollen und gespeicherte Modellzuordnung |
| Automatische/explizite Standardaufteilungen | v0.5 | Lokale Partition, Klassen-/Größenprüfung, Seeds |
| Vollständige Referenzaufteilungen einschließlich geordneter Holdouts | v0.6; Paarübertragung v0.7 | Reihenfolge und lokale Trainingskomplemente |
| Besonderer Klassen-/Spaltennamensumfang | Explizite Kodierung v0.6; spätere Wege erben sie | Bijektives Schema, native und dekodierte Gesamtpfade |
| Kalibrierung externer Vorhersagen / eingefrorener Workflows | Manuelle Kerne; direkte Workflow-Übernahme v0.6 | Unveränderte vollständige Predict-Pfade; direkte Übernahme als R-Ergänzung |
| Python-artiges paarweises trainiertes OvO | v0.7 | Eigene Modelle und lokale Pläne je Klassenpaar |
| Inductive-/Cross-Vollmodell-Übertragung | Feste Parameter v0.7; automatische Auswahl v0.8 | Unveränderte gehaltene Quellen, eigenständiger vollständiger Fit |
| Vollständige gemeinsame/zweistufige Auswahl | v0.8 | Lokale Suche, separater Optionsauswahlanteil, strenge Kandidateneignung |
| Native Workflow-/Resampling-/Scoring-Abläufe | v0.5, je Erweiterung ausgebaut | Korrekte Ausgaben und vollständige äußere Bewertung; Python-Scoringdefekte nicht kopieren |
| Zusätzlich gelerntes Postprocessing und innere Ensembles | v0.9 | Endliche 80er-Matrix, numerische Schichten, B/P/C-Trennung |
| Vollständige RDS-Vorhersagepfade und frische Worker | Je eingeführtem Integrationsweg, insbesondere v0.6–v0.9 | Kein Nachlernen, vollständiger Pre-/Postprocessing-Zustand |
| Scores, Reliability-Plots und fachliche Beispiele | Binär v0.2; Multiclass v0.3; Regressionsbeispiele v0.4; weitere native Beispiele je Release | Definitionen und Aussagegrenzen, keine erfundenen Python-Exporte |
| Abschließende öffentliche Paritätsaussage und Produktreife | v1.0 | Vollständige Evidenzmatrix und gemeinsame Freigabe |

## 13. Ausdrücklich außerhalb dieser Planungs-Map

- Implementierung der geplanten Produktfunktionen, Release-Publishing und tatsächliche CRAN-Einreichung während der Planung. Das Schreiben dieser Roadmap ist ausdrücklich beauftragt.
- Zusätzliche allgemeine Gruppen-/Zeitreihenverfahren, etwa Gruppen-IDs, rollierende Fenster, Horizonte, Embargos oder Online-Updates, über die belegten Referenzpfade hinaus. Der manuelle externe Zugang bleibt möglich.
- Eigenständige Multikalibrierungs-, Quantil- oder Conformal-Erweiterungen als zusätzliche v1.0-Pflicht.
- OOF-Postprocessing mit anschließendem vollständigem Engine-Refit und weitere neu trainierte Methoden außerhalb der endlichen Postprocessing-Liste. Der separat bestätigte eingefrorene Zugang bleibt unberührt.
- Vollständige Nachbildung aller Optionen fremder sklearn-/Tailor-Kompositionen und pauschale Reparatur beliebiger bereits trainierter Workflows.

Quellen: [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen][splits], [Zusätzlich gelerntes Postprocessing und innere Datenverträge bis v1.0 festlegen][postprocessing] und [Reversible Namenskodierung für native und eingefrorene Workflows festlegen][names].

## 14. Abschluss und Übergabe an die Umsetzung

Die bislang offenen Entscheidungen aus [Release-Reife und verbindliche Milestone-Zuschnitte festlegen][release] sind geklärt. Die bestätigten Fachverträge, Release-Zuordnungen und gemeinsamen Abnahmen sind hier vollständig zusammengeführt. Eine erneute stellvertretende Entscheidung über bereits abgeschlossene Fachfragen findet nicht statt.

Aus den acht Versionskapiteln können die entsprechenden GitHub-Milestones und Umsetzungstickets abgeleitet werden. Die Reihenfolge der Schritte, ihre Quellenverträge und die überprüfbare Abnahme sind dabei zu erhalten. Die Planung selbst erstellt keine Produktimplementierung und setzt kein Release als veröffentlicht voraus.

Noch nicht vorliegende Messergebnisse, reale spätere Runnerstände, Maintainer-Metadaten und bestandene Produktprüfungen sind Umsetzungsnachweise. Sie werden nicht erfunden und sind für sich keine zusätzliche Produktentscheidung. Falls ihre Umsetzung einen beschlossenen Vertrag ändern müsste, wird genau diese Abweichung gesondert entschieden.

## 15. Entscheidungsquellen

### Bestätigte Release-Entscheidungen

- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Veröffentlichungsreife][publication-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — R-Versionen und Plattformen][r-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — API-Stabilität][api-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — technische Abnahme][technical-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Dokumentationsreife][docs-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Performance-Abnahme][performance-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Performance-Messung und Freigaberegel][performance-method-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — konkreter Benchmarkplan][benchmark-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Staffelung v0.3 bis v0.5][schedule-first]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Staffelung v0.6 bis v1.0][schedule-rest]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — CI-Matrix][ci-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — rollierende R-Untergrenze][r-minimum-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — Abhängigkeitsprüfung][dependency-decision]
- [Release-Reife und verbindliche Milestone-Zuschnitte festlegen — konkrete CRAN-Vorbereitung und Markdown-Auftrag][cran-decision]

### Fachliche Entscheidungen und versionierte Verträge

- [Python-Funktionsumfang und Paritätslücken erfassen][parity]
- [Multiclass-Umfang und Abnahme für v0.3 festlegen][multiclass]
- [Regressionsumfang und Abnahme für v0.4 festlegen][regression]
- [tidymodels-Abläufe für v0.5 und Ausbau bis v1.0 abgrenzen][integration]
- [Zusätzliche binäre Kalibrierungsoptionen und Paritätsgrenzen festlegen][binary]
- [Brier und Rundung für Multiclass bis v1.0 festlegen][multiclass-options]
- [Native tidymodels-Schnittstelle und v0.5-Integrationsvertrag konkretisieren][integration-research]
- [Tuning des vollständigen kalibrierten Verfahrens bis v1.0 festlegen][tuning]
- [Vollmodell-Alternative für vollständige Python-Parität festlegen][full]
- [Kalibrierung bereits trainierter Modelle und Workflows festlegen][frozen]
- [Gruppen- und Zeitreihenabläufe bis v1.0 abgrenzen][splits]
- [Namens- und Sonderfallgrenzen der nativen tidymodels-Integration entscheiden][initial-boundaries]
- [Vorläufige Integrationsgrenzen gegen die vollständige Python-Parität prüfen][boundaries]
- [Reversible Namenskodierung für native und eingefrorene Workflows festlegen][names]
- [Zusätzlich gelerntes Postprocessing und innere Datenverträge bis v1.0 festlegen][postprocessing]

[map]: https://github.com/RMKruse/vennabers/issues/2
[release]: https://github.com/RMKruse/vennabers/issues/7
[publication-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562417633
[r-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562421879
[api-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562427356
[technical-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562437254
[docs-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562447801
[performance-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5562453701
[performance-method-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5571218144
[benchmark-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5571263691
[schedule-first]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5570960053
[schedule-rest]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5570971671
[ci-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5570984218
[r-minimum-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5571104475
[dependency-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5571130876
[cran-decision]: https://github.com/RMKruse/vennabers/issues/7#issuecomment-5571000175
[parity]: https://github.com/RMKruse/vennabers/issues/3#issuecomment-5561425780
[multiclass]: https://github.com/RMKruse/vennabers/issues/4#issuecomment-5561592433
[regression]: https://github.com/RMKruse/vennabers/issues/5#issuecomment-5561777290
[integration]: https://github.com/RMKruse/vennabers/issues/6#issuecomment-5562394965
[binary]: https://github.com/RMKruse/vennabers/issues/8#issuecomment-5562516771
[multiclass-options]: https://github.com/RMKruse/vennabers/issues/14#issuecomment-5562565289
[integration-research]: https://github.com/RMKruse/vennabers/issues/9#issuecomment-5562631101
[tuning]: https://github.com/RMKruse/vennabers/issues/10#issuecomment-5568603972
[full]: https://github.com/RMKruse/vennabers/issues/11#issuecomment-5569044325
[frozen]: https://github.com/RMKruse/vennabers/issues/12#issuecomment-5569800958
[splits]: https://github.com/RMKruse/vennabers/issues/13#issuecomment-5569944742
[initial-boundaries]: https://github.com/RMKruse/vennabers/issues/15#issuecomment-5570134201
[boundaries]: https://github.com/RMKruse/vennabers/issues/16#issuecomment-5570317984
[names]: https://github.com/RMKruse/vennabers/issues/17#issuecomment-5570473475
[postprocessing]: https://github.com/RMKruse/vennabers/issues/18#issuecomment-5570885418
[parity-asset]: https://github.com/RMKruse/vennabers/blob/d7b87f1b093e6d1cd9b96a0116ced8ee19b973b2/tools/python-parity-research.md
[integration-asset]: https://github.com/RMKruse/vennabers/blob/846d724c55726ee38324a2e30fe75a8041e83e9e/tools/tidymodels-integration-research.md
[tuning-asset]: https://github.com/RMKruse/vennabers/blob/5944fcc189dd063021a21b0f43ec01ba4a595726/tools/tuning-contract-draft.md
[full-asset]: https://github.com/RMKruse/vennabers/blob/7931ddbb21020ebeef73b3af4a306b7380d7f17b/tools/full-model-contract-draft.md
[postprocessing-asset]: https://github.com/RMKruse/vennabers/blob/918c1c13b2f0626765c6a4d336a2365cd9d08d05/tools/postprocessing-contract-draft.md
