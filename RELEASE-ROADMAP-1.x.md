# Release-Roadmap für vennabers: 1.1 bis 1.5

Stand: 26. Oktober 2026. Dieses Dokument fasst die bestätigten Entscheidungen
der Planungskarte [Roadmap für vennabers nach 1.0][map] zu fünf additiven
1.x-Releases zusammen.

**Planungsstatus:** Abgeschlossen. Zuschnitt, Reihenfolge, Abhängigkeiten,
berührte Wege, Abnahme, Prüfpunkte und die 2.0-Kandidatenliste sind im
Live-Gespräch bestätigt ([1.x-Milestones zuschneiden und die Roadmap
festhalten][synthesis]). Die fachlichen Verträge stehen in den verlinkten
Entscheidungstickets und ADRs. Diese Datei ordnet sie Releases zu und
wiederholt sie nur so weit, wie die Abnahme es verlangt.

**Produktstatus:** Ausgangspunkt ist vennabers 1.0.0. Alle hier genannten
Fähigkeiten sind geplant, nicht umgesetzt. Die Datei behauptet weder
Implementierung noch bestandene Abnahmen oder Veröffentlichungen.

**Quellen:** Die Karte, ihre Tickets und die ADRs liegen lokal unter
`.scratch/post-1.0-roadmap/` bzw. `docs/adr/`, die Recherchen unter
`research/`. Alle drei Orte sind nicht versioniert; die Links funktionieren
nur im Arbeitsverzeichnis des Maintainers.

[RELEASE-ROADMAP.md](RELEASE-ROADMAP.md) bleibt die historische Planung bis
1.0. Ihre gemeinsamen Abnahmeregeln gelten weiter (Abschnitt 3).

## 1. Ziel und verbindliche Staffelung

Ziel sind additive 1.x-Releases. Jedes erhält alle öffentlichen Funktionen,
Argumente, Ausgabeformate und Prüfungen der Vorgänger und hält die
Releasetreue (Abschnitt 3.2). Was die 1.x-Zusage bräche, steht in Abschnitt
11 und wird nicht geplant.

| Version | Thema und Umfang | Voraussetzung |
|---|---|---|
| 1.1 — Leistung, Releasetreue, Paritätsdoku | Leistungspaket in reinem R, Releasetreue-Orakel und Archivvergleich, Gegenvergleich-Abschnitt in PARITY; keine neue API | CRAN-Annahme von 1.0 |
| 1.2 — tidymodels | Fallgewichte im Quellmodell-Fit; probably-/tailor-Bausteine; wöchentlicher Lauf gegen tidymodels-`main` | 1.1 auf CRAN |
| 1.3 — Klassenentscheidung und Ereignisse | Top-Label-VA, VA-Abstention, VA-Schwellenwahrscheinlichkeiten, reelle Scores im binären Kern (K04) | 1.2 auf CRAN |
| 1.4 — Beschränkte Regression und Intervalle | Beschränkter IVAR (`outcome_range`), SC-CP-Vorhersageintervall, `coverage_plot()` | 1.3 auf CRAN; Schwellen und gespeichertes C aus 1.3 |
| 1.5 — Quantile und Multikalibrierung | VA-Quantilkalibrierung, Venn-Multikalibrierung | 1.4 auf CRAN; Quantil-Hilfsfunktion, `coverage_plot()` und `outcome_range` aus 1.4 |

**Veröffentlichung:** Ein Minor gilt mit seiner CRAN-Annahme als
veröffentlicht. Die Einreichung macht der Maintainer, getrennt von dieser
Roadmap. Die Umsetzung des nächsten Minors darf auf `dev` vorher beginnen,
sein Release erst nach der Annahme des Vorgängers. Termine sind nicht
festgelegt. Die CRAN-Policy verlangt Abstände von ein bis zwei Monaten
zwischen Updates.

**Feste Reihenfolgekanten aus den Verträgen:**

- Der Top-Label-Teil der VA-Abstention setzt Top-Label-VA voraus.
- VA-Abstention und Schwellenwahrscheinlichkeiten teilen das Cross-GM-Paar
  und entstehen im selben Milestone.
- Die öffentlichen reellen Scores (K04) nutzen den internen Kernzugang der
  Schwellenwahrscheinlichkeiten.
- Das SC-CP-Vorhersageintervall kommt nicht vor dem beschränkten IVAR und
  nutzt das von den Schwellen gespeicherte C.
- Die VA-Quantilkalibrierung kommt nicht vor SC-CP.
- Die Venn-Multikalibrierung kommt nicht vor dem beschränkten IVAR.

Der CRAN-Prüfpunkt (Abschnitt 9.2) darf die Reihenfolge noch nicht begonnener
Milestones ändern, soweit diese Kanten erhalten bleiben.

Quellen: [Lückenkatalog zusammenführen und priorisieren][gaps] (Rangfolge),
[Synthese, Runden 1 und 2][synthesis].

## 2. Referenzen und Kennzeichnung

Die **Hauptreferenz** bleibt Python `venn-abers` 1.5.4 (Pins in
`inst/PARITY.md`). Je Verfahren gilt genau eine bindende Referenz; ohne eine
solche gibt es keine Aussage zur Numerischen Parität, sondern Orakel- und
Handrechnungstests. Gegenvergleiche sind dokumentiert und nicht bindend
(ADR 0004).

| Verfahren | Release | Bindende Referenz | Gegenvergleich | Gültigkeitsaussage |
|---|---|---|---|---|
| Leistungspaket | 1.1 | Releasetreue zu 1.0.0 | – | unverändert |
| Fallgewichte im Quellmodell-Fit | 1.2 | keine (R-Erweiterung; die Referenz bricht bei zeilenweisem `sample_weight`) | – | unberührt, gilt für Zeilen |
| probably-/tailor-Bausteine | 1.2 | bitgleich zum Kern | – | wie der Kern |
| Top-Label-VA | 1.3 | keine, Orakel gegen den binären Kern | – | IVAP-Aussage geerbt, nur Inductive passend |
| VA-Abstention | 1.3 | keine, Orakel | – | keine |
| VA-Schwellenwahrscheinlichkeit | 1.3 | Hauptreferenz auf dem abgeleiteten Binärproblem | calibrated-explanations 1.0.2 | IVAP-Aussage je Schwelle, nur Inductive |
| Reelle Scores im binären Kern (K04) | 1.3 | Hauptreferenz nach ordnungserhaltender Abbildung | – | IVAP-Aussage (Vovk et al. 2015) |
| Beschränkter IVAR | 1.4 | binäre Komponente der Hauptreferenz, falls die Vorabprüfung sie belegt; sonst nur Orakel | – | Preprint: Petej/Vovk 2026, Thm. 2, nur Inductive |
| SC-CP-Vorhersageintervall | 1.4 | keine, Orakel | SelfCalibratingConformal @ `fa2a1eb` | van der Laan/Alaa 2024 (NeurIPS 37), Thm. 4.2 |
| VA-Quantilkalibrierung | 1.5 | keine, Orakel | SelfCalibratingConformal @ `fa2a1eb` | van der Laan/Alaa 2025 (ICML, PMLR 267), Thm. 4.1; geschlossene Form eigene Ableitung |
| Venn-Multikalibrierung | 1.5 | keine, Orakel gegen `lm()` | – (VennCalibration nur beschrieben) | van der Laan/Alaa 2025, Kor. 3.6 |

Hilfeseiten nennen Aussage, Quelle, Voraussetzungen und Grenzen. Preprints
sind als solche gekennzeichnet und werden am Minor-Prüfpunkt nachgeprüft.
Verfahren ohne Gültigkeitsaussage sagen das ausdrücklich.

Quellen: [Paritätsvergleiche mit weiterer VA-Software festlegen][parity],
[Weitere VA-Software numerisch gegen vennabers abgleichen][numeric].

## 3. Gemeinsame Abnahme je 1.x-Release

### 3.1 Fortgeltung

[RELEASE-ROADMAP.md](RELEASE-ROADMAP.md) §3 gilt für jedes 1.x-Release
pauschal:

- API-Stabilität und rollierende R-Untergrenze (§3.1);
- die acht CI-Kombinationen, der Mindestversionslauf, der Kernlauf ohne
  tidymodels und R-devel als Frühwarnung (§3.2);
- Toleranzen, Datenrollen und Fehlerregeln (§3.3);
- Dokumentation und geprüfte Beispiele (§3.4);
- optionale Abhängigkeiten (§3.6).

Neue optionale Pakete kommen in `Suggests`, ihre Mindestversionen in den
Mindestversionslauf. `Imports` bleibt leer, Grafiken bleiben Base-Graphics,
kompilierten Code gibt es nicht (ADR 0002).

### 3.2 Releasetreue und Archivvergleich

**Releasetreue:** Gleiche Scores bzw. Vorhersagen, Labels, Optionen und
Fold-Zuordnungen ergeben in jedem 1.x-Release bitgleich dieselben VA-Ausgaben
wie in 1.0, auf derselben Plattform mit derselben R-Version. Neue Optionen
fallen auf ihrem Standardwert unter die Zusage. Engine-Fits und
Abhängigkeiten sind ausgenommen.

Nachweis auf zwei Wegen:

1. **Testorakel:** Ein umgebauter Kern behält die alte Implementierung in den
   Tests als `identical()`-Orakel. Es läuft in der ganzen CI-Matrix,
   ausdrücklich auch auf Linux x86_64.
2. **Archivvergleich:** Ein Skript unter `tools/` installiert den Vorgänger
   aus dem CRAN-Archiv und den Kandidaten in getrennte Bibliotheken. Auf
   jeder CI-Plattform vergleicht es einen festen Fallkatalog mit
   `identical()`: alle manuellen Kerne sowie je Ziel (binär, OvO, OvR,
   Regression) einen Workflow-Fall ab der Übergabe der Scores. Ausgaben sind
   `predict()`, `venn_abers_details()`, `print()` und die gespeicherten
   Objektfelder. Gebaut wird das Skript in 1.1. Jedes Minor ergänzt den
   Katalog um die Standardwerte seiner neuen Optionen. Es läuft in der
   Release-Abnahme, nicht in `R CMD check`.

**Einzige Ausnahme** ist die Berichtigung eines belegten Defekts. Sie steht in
NEWS unter „Geänderte Ergebnisse“, der Defekt in `inst/PARITY.md`, der
betroffene Archivfall wird mit Begründung angepasst. Ändert eine neuere
Referenzversion ausgelieferte Werte, bleibt der Pin; es folgen ein D-Eintrag
und ein 2.0-Kandidat (ADR 0004).

### 3.3 Berührte Wege und gezielte Kombinatorik

Wege: **M** manuelle Kerne, **W** trainierbare Workflows, **E** eingefrorene
Workflows, **T** Tuning, **P** Postprocessing-Kompositionen, **G** Grafiken.

Neue Fähigkeiten erhalten in den Wegen, die sie berühren, die volle
v1.0-Strenge: Orakel, Randfälle, Fehlerfälle, Datenrollen,
`saveRDS()`-Rundläufe und frische Worker. Kombinationen werden gezielt
gewählt, nicht kartesisch. Jedes Versionskapitel nennt seine Wege.

### 3.4 Leistung

Es gilt die Messregel aus RELEASE-ROADMAP §3.5: Linux-x86_64-Referenzmaschine,
ein Aufwärmlauf, drei Messläufe, Median, Prozessspitze und RDS-Größe, der
Vorgänger frisch auf derselben Maschine gemessen.

- **1.1** führt die ganze Benchmark-Suite v0.3–v0.9 gegen 1.0.0 aus, weil das
  Leistungspaket alle Kerne berührt. Dazu kommen die Fälle aus Ticket 07.
- **Ab 1.2** laufen nur die bestehenden Fälle der berührten Wege gegen den
  Vorgänger, dazu Ausgangsmessungen der neuen Messfälle aus den Verträgen.
  Verschlechterungen werden vor der Freigabe untersucht und begründet.

### 3.5 Patch-Releases

Patch-Releases `1.x.y` sind jederzeit erlaubt, nur für Defekte und
CRAN-Auflagen. Sie haben keinen Prüfpunkt. Abgenommen werden die berührten
Wege, CI-Matrix, Mindestversionslauf und Archivvergleich (mit der Ausnahme
aus 3.2).

## 4. 1.1 — Leistung, Releasetreue, Paritätsdoku

### Ziel und Umfang

Das erste Release nach CRAN ändert keine öffentliche Funktion, kein Argument
und keine Ausgabe. Es macht die Kerne in reinem R schneller, legt die
Prüfwerkzeuge für die Releasetreue an und baut die Paritätsdokumentation um.

1. **Leistungspaket** (ADR 0002):
   - `.cross()` inline in `.upper_scan()` (Scans 3,8–3,9× schneller);
   - `rowsum()` nur für die binären 0/1-Summen. Die Regression behält
     `vapply(sum)`, weil `sum()` auf x86_64 mit 80 Bit summiert;
   - vektorisierte CVAR-Mittelung (`.regression_mean_rows()`) für
     `predict.cross_venn_abers_regression()` und die Mittelung der inneren
     Regressionsensembles in `R/postprocessing.R`. Nicht endliche Zeilen
     rechnet der skalare Pfad. Fällt das Orakel auf x86_64 durch, entfällt nur
     dieser Teil;
   - ein Abschnitt „Große Kalibrierungsbestände“ in `?venn_abers`: Die
     Laufzeit ist linear in den Knoten; `precision` reduziert die Knoten,
     ändert aber die Kalibrierung.
2. **Releasetreue-Werkzeuge:** Testorakel der umgebauten Kerne und
   Archivvergleich (Abschnitt 3.2).
3. **Paritätsdokumentation** (ADR 0004):
   - neuer Abschnitt „Gegenvergleich“ in `inst/PARITY.md` außerhalb der
     Fähigkeitstabelle. Je Paket stehen dort Version bzw. Commit, Ergebnis,
     erklärte Abweichungen und knappe Umsteigerhinweise: MAPIE 1.6.0,
     calibrated-explanations 1.0.2, reliabilitydiag 0.2.1 (verschoben) und neu
     `ptocca/VennABERS` (per Commit, binäre IVAP);
   - Pins je Verfahren unter „Reference and tolerances“;
   - Abgleichskripte aus `research/va-software-abgleich/` versioniert unter
     `tools/`, außerhalb des Paket-Builds, Python nur in einer temporären
     venv.

### Release-Grenze

Keine neue API und keine geänderten Ausgaben. Die Prozessspitze der
CVAR-Vorhersage steigt bei 1e6 Zeilen um etwa 31 %; NEWS nennt das. Kein
kompilierter Code.

### Geordnete Umsetzung

1. Archivvergleich gegen 1.0.0 und Fallkatalog anlegen.
2. Testorakel der alten Kerne einziehen.
3. `.cross()` inline, dann `rowsum()` binär, dann die vektorisierte
   CVAR-Mittelung, jeweils mit Orakel.
4. Hilfeabschnitt zu großen Kalibrierungsbeständen.
5. PARITY-Umbau, Skripte nach `tools/`, `ptocca`-Abgleich.
6. Erster Minor-Prüfpunkt (Abschnitt 9.1), Benchmarks, Abnahme.

### Berührte Wege

M (IVAP, CVAP, IVAR, CVAR), `predict.cross_venn_abers_regression()`, die
Mittelung der inneren Regressionsensembles (P); indirekt alle Wege.

### Überprüfbare Abnahme

- Testorakel bitgleich in der ganzen CI-Matrix, inkl. Linux x86_64.
- Archivvergleich gegen 1.0.0 ohne Abweichung auf allen Plattformen.
- Paritäts-Fixtures unverändert.
- Leistungsfälle gegen 1.0.0:
  - IVAP und IVAR mit 1e6 und 1e7 stetigen Knoten;
  - CVAP und CVAR mit 1e6;
  - CVAR-Vorhersage mit 1e5 und 1e6 Zeilen, mit Prozessspitze;
  - ein Bindungsfall, damit `rowsum()` dort nicht spürbar verliert;
  - die ganze Suite v0.3–v0.9.
- Gegenvergleiche ausgeführt und dokumentiert, Skripte unter `tools/`
  lauffähig ohne Paket-Build.

Quellen: [Über kompilierten Code für die VA-Kerne entscheiden][compiled],
[Vektorisierte CVAR-Mittelung prototypisch messen][cvar],
[Leistung der VA-Kerne gegen den Workflow-Aufwand messen][perf],
[Paritätsvergleiche mit weiterer VA-Software festlegen][parity].

## 5. 1.2 — tidymodels

### Ziel und Umfang

1. **Fallgewichte im Quellmodell-Fit** (ADR 0005, Begriff **Fallgewicht**):
   - Angabe nur über `add_case_weights()` am äußeren Workflow;
     `importance_weights()` und `frequency_weights()` gehen unverändert an die
     Engines.
   - `vennabers` schneidet sie für jeden Fit von Vorverarbeitung und
     Basismodell auf dessen lokale Zeilen zu: Inductive-B, Cross-Folds,
     Klassenpaare, Vollmodell auf F, Basis-B bei Postprocessing, innere
     Tuning-Fits.
   - VA-Kalibrator, Postprocessor und Interop-Bausteine bleiben ungewichtet,
     mit `print()`-Vermerk („case weights: model fits only“). Die Zeile
     bleibt Einheit.
   - `model_adapter()`: Der `fit`-Callback erhält `weights`, wenn er dieses
     Formal hat.
   - Kein allgemeiner Kwargs-Mechanismus, kein externes `eval_set`.
2. **probably-/tailor-Bausteine** (ADR 0003):
   - `adjust_venn_abers_probability()` und `adjust_venn_abers_numeric()`,
     nur IVAP/IVAR: binär, multiclass (OvO/OvR, log/brier) und Regression
     (`m`, `epsilon`);
   - `cal_estimate_venn_abers()` nur für `data.frame`, mit `cal_adjust()`-
     und `required_pkgs()`-Methode;
   - Zusatzspalten `.pred_va_lower`/`.pred_va_upper` für binär und
     Regression, sichtbar in `augment()` und `collect_predictions()`;
   - bitgleich zu `venn_abers()` bzw. `venn_abers_regression()` auf
     denselben Vorhersagen.
3. **Interna-Schicht:** alle Zugriffe auf tailor-, probably- und
   tune-Interna an einer Stelle, mit Layoutprüfung und klarer Fehlermeldung.
   Die bestehenden Zugriffe in `R/tailor.R` ziehen mit um.
4. **Wöchentlicher CI-Lauf**, geplant und nicht blockierend, gegen GitHub
   `main` von tailor, probably, workflows und tune.

### Release-Grenze

Upstream-Beiträge (Delegation von probably an `vennabers`, Extraktor) kommen
danach und sind optional; kein Milestone wartet auf fremde Zeitpläne. Die
Interop-Bausteine bieten keine Abstention, keine Top-Label-VA, kein
Tuning und keine Schwellen; `outcome_range` ergänzt 1.4. Ein gewichteter
Kalibrator (K16) bleibt zurückgestellt und käme in 1.x nur per Opt-in.

### Geordnete Umsetzung

1. Interna-Schicht mit Layoutprüfung; `R/tailor.R` umziehen; wöchentlichen
   `main`-Lauf einrichten.
2. Fallgewichte: Zuschnitt je lokalem Fit, Ablehnungen, `print()`-Vermerk,
   `model_adapter()`-Formal, Tuning nach der tune-Regel, eingefrorener
   gewichteter `fitted_workflow`.
3. Interop-Bausteine mit Vermerk „ungewichtet“.
4. Dokumentation: Abschnitt in `workflows.Rmd`, Beispiel in
   `examples-postprocessing.Rmd`, Abgrenzung zu `calibrate_workflow()`,
   Klarstellung zu `data_calibration` = C. PARITY: Fallgewichte als
   R-Erweiterung; L bleibt für allgemeine Kwargs und `eval_set`.
5. Minor-Prüfpunkt, Benchmarks, Abnahme.

### Berührte Wege

W, E, T, P, G (nur Smoke für `cal_plot_*()`), `model_adapter()`; nicht M.

### Überprüfbare Abnahme

- **Fallgewichte:**
  - Audit-Engine über die 20 Verfahrenskombinationen: jeder lokale Fit
    erhält genau die Gewichte seiner Zeilen, C und P keine;
  - T je ein Grid für gemeinsame und zweistufige Auswahl, je mit
    Häufigkeits- und Importance-Gewichten;
  - P mit sigmoid, isotonic und einer tailor-Methode;
  - E mit gewichtet trainiertem `fitted_workflow`;
  - `model_adapter()` mit und ohne `weights`-Formal;
  - Fehlerfälle, `print()`-Vermerk, RDS-Rundlauf;
  - ein gewichteter `glm`-Fit gleicht `glm(weights =)` auf denselben B-Zeilen;
  - ohne Gewichte alles bitgleich zu 1.0.0.
- **Interop:**
  - bitgleich zum Kern: binär; multiclass OvO/OvR × log/brier; Regression
    mit und ohne `m`/`epsilon`;
  - `saveRDS()`-Rundlauf eines gefitteten Workflows;
  - `cal_estimate_venn_abers()` → `cal_apply()` gleich dem Adjustment;
  - Reihenfolge mit `adjust_equivocal_zone()`: dahinter erlaubt, davor
    abgelehnt;
  - Fehlermeldung bei manipuliertem Layout;
  - Mindestversionslauf mit den von der Umsetzung ermittelten
    Mindestversionen von tailor und tune.
- **Leistung:** bestehende W-, T- und P-Fälle gegen 1.1; die Verträge legen
  keinen neuen Messfall fest.

Quellen: [Vertrag für Fallgewichte im Quellmodell-Fit festlegen][weights],
[Den Weg zur probably-/tailor-Interop entscheiden][interop],
[Erweiterbarkeit von probably und tailor für Venn-Abers klären][tailor].

## 6. 1.3 — Klassenentscheidung und Ereignisse

### Ziel und Umfang

1. **Top-Label-VA** (ADR 0006, Begriff **Top-Label-VA**):
   - gepoolt nach Johansson et al. 2021: ein binärer VA-Kalibrator auf der
     höchsten Quellmodell-Wahrscheinlichkeit und dem Ereignis
     „Klassenentscheidung richtig“;
   - kein Wahrscheinlichkeitsvektor. Die Klasse kommt vom Quellmodell, die
     Kalibrierung ändert sie nie;
   - `method = "top_label"` in `venn_abers()` und `cross_venn_abers()`,
     `classification = "top_label"` in Workflows, eingefrorenen Workflows und
     `schema`;
   - Cross nur mit einer Vorhersagequelle; `type = "prob"` bricht ab; die
     Werte stehen als `.pred_top*` in `venn_abers_details()`;
   - `corp_plot()`/`corp_decomposition_plot()` mit `class` und `by_class`.
2. **Cross-GM-Paar:** gemeinsamer Baustein `1 − GM(1 − p0)`, `GM(p1)` über
   die Folds (Vovk et al. 2015 §4), nur in den neuen Funktionen.
3. **VA-Abstention** (ADR 0007, Begriff **VA-Abstention**):
   - Generic `venn_abers_abstention(object, new_data, max_width = NULL, ...)`
     für binär und Top-Label-VA (manuell, Workflows, eingefroren);
   - gibt die Klassenentscheidung unverändert aus, dazu das VA-Paar,
     `.pred_va_width` und `.abstain` bei `width > max_width`;
   - `abstention_plot()` als Vorhersagediagnose (Breitenhistogramm), mit
     `correct` zusätzlich Fehlerrate gegen Abstentionsrate;
   - keine Gültigkeitsaussage; OvO/OvR und Regression brechen ab.
4. **Gespeichertes C:** Regressionsobjekte speichern Wahrheit und
   Quellmodell-Vorhersage von C, je Fold. `predict()` und
   `venn_abers_details()` bleiben bitgleich; NEWS nennt den Mehrspeicher.
5. **VA-Schwellenwahrscheinlichkeiten** (ADR 0008, Begriff
   **VA-Schwellenwahrscheinlichkeit**):
   - je Schwelle eine binäre IVAP auf der rohen Quellmodell-Vorhersage
     (fallend) mit Label `1{y ≤ t}`;
   - Generic `venn_abers_threshold(object, new_data, threshold, loss =
     "log", ...)` mit langer Ausgabe (`.row`, `.threshold`, `.pred_prob`,
     `.pred_va_lower`/`.pred_va_upper`);
   - schwach monoton in `t`, ohne Korrektur;
   - Cross wie die binäre CVAP, Grenzen über das GM-Paar.
6. **Reelle Scores im binären Kern (K04):**
   - ein Opt-in nur an `venn_abers()` und `cross_venn_abers()`.
     Arbeitsname `score_type = c("probability", "real")`; den Namen bestätigt
     das Umsetzungsticket;
   - mit `"real"` sind endliche reelle Scores erlaubt (etwa SVM-Werte oder
     Logits). Die Ausgabe bleibt VA-Wahrscheinlichkeiten, `precision` rundet
     wie bisher;
   - der Standard behält die bisherige Validierung und Fehlermeldung;
   - kein Multiclass, keine Top-Label-VA, keine Workflows, keine
     Interop-Bausteine. Gültigkeitsaussage: IVAP nach Vovk et al. 2015.

### Release-Grenze

`predict()`, `venn_abers_details()` und `print()` bestehender Objekte bleiben
unverändert. Kein tailor-/probably-Adjustment für Top-Label-VA, Abstention
oder Schwellen; kein Tuning von β oder Schwellen. Abstention als eigene Stufe
der Klassenentscheidung bleibt 2.0-Kandidat.

### Geordnete Umsetzung

1. Top-Label-VA: manueller Kern mit Orakel, dann Workflows, eingefroren, T
   und P.
2. `corp_plot(class =, by_class =)`.
3. Cross-GM-Paar als gemeinsamer Baustein.
4. `venn_abers_abstention()` binär, dann Top-Label; `abstention_plot()`.
5. C in den Regressionsobjekten speichern; interner Kernzugang für reelle
   Scores.
6. `venn_abers_threshold()` mit N-Prüfung gegen die Hauptreferenz und dem
   CE-Gegenvergleich.
7. Öffentliches K04-Opt-in.
8. PARITY-Zeilen, Hilfeseiten mit Kennzeichnung, Minor-Prüfpunkt,
   Benchmarks, Abnahme.

### Berührte Wege

M, W, E, T, P, G. Im Einzelnen:

- Top-Label-VA: M, W, E, T, P, G;
- Abstention: M, W, E, G;
- Schwellen: M, W, E, G nur als Doku-Beispiel;
- K04: M.

### Überprüfbare Abnahme

- **Top-Label-VA:**
  - M: Orakel bitgleich zu `venn_abers(truth = korrekt, probability =
    max_prob)` bzw. zum binären Cross-Kern, Inductive und Cross ×
    log/brier; Randfälle Gleichstand, C nur richtig bzw. nur falsch, K = 2;
  - W/E bitgleich zu M für Inductive passend, Inductive Vollmodell, Cross
    Vollmodell und `calibrate_workflow()`; Ablehnung von Cross passend und
    `pairwise`;
  - T: je ein Lauf `joint` (Klassenmetrik) und `two_stage`;
  - P: tailor multinomial im Holdout;
  - G: Smoke- und Bildvergleich für `class` und `by_class`.
- **Abstention:**
  - M: Inductive bitgleich zu `predict()`; Cross-Paar gegen eine
    unabhängige Formel (Randfälle `p1_k = 0`, `p0_k = 1`, K = 2…10);
    `width == max_width` wird angenommen;
  - Top-Label gegen das Orakel aus Ticket 13; Abbruch bei OvO/OvR und
    Regression;
  - W/E bitgleich zu M;
  - G: beide Stufen, `par()` wiederhergestellt.
- **Schwellen:**
  - M bitgleich zum Orakel `venn_abers()` auf dem abgeleiteten Problem,
    Cross zu `cross_venn_abers()`;
  - Monotonie als Eigenschaftstest mit Gleichständen;
  - Randfälle `y == t`, `t` außerhalb der Labels, ungültige `t`,
    `loss = "brier"`;
  - N: Hauptreferenz innerhalb der Standardtoleranzen, Skript und Fixture
    unter `tools/`;
  - W/E bitgleich zu M.
- **K04:**
  - Auf Scores in [0, 1] sind beide Einstellungen bitgleich.
  - Ohne `precision` ist `"real"` bitgleich zu `venn_abers()` auf einer
    streng monotonen Abbildung der Scores nach [0, 1], Gleichstände
    erhalten.
  - Nicht endliche Scores brechen ab. Kombinationen mit Multiclass bzw.
    `top_label` werden abgelehnt.
- **Releasetreue:** Archivvergleich gegen 1.2 inkl. gespeicherter
  Objektfelder (mit C als neuem Feld).
- **Messfall** (informativ, ohne Schwellwert): Schwellen mit `n_C = 1e5`,
  1e5 neuen Zeilen und 100 Schwellen gegen den einmaligen IVAR-Fit; dazu die
  RDS-Größe der Regressionsobjekte mit gespeichertem C. Bestehende
  Klassifikations- und Regressionsfälle der berührten Wege gegen 1.2.

Quellen: [Vertrag für Top-Label-VA festlegen][toplabel],
[Vertrag für die Abstention über die VA-Breite festlegen][abstention],
[Vertrag für VA-Schwellenereignisse festlegen][threshold], [Synthese, Runde 1
(K04)][synthesis].

## 7. 1.4 — Beschränkte Regression und Intervalle

### Ziel und Umfang

1. **Beschränkter IVAR** (ADR 0009, Begriff **Ergebnisbereich**):
   - Argument `outcome_range = c(C_*, C^*)` an `venn_abers_regression()`,
     `cross_venn_abers_regression()`, `calibrated_workflow()`,
     `calibrate_workflow()` und `adjust_venn_abers_numeric()`;
   - exklusiv zu `m`/`epsilon`, nicht tunebar, nie aus den Daten;
   - Labels außerhalb brechen beim Fit ab, in Workflows auf der ganzen
     Ergebnisspalte; kein Clipping;
   - Punkt nach Formel (6), Ausgabe unverändert, `print()` zeigt den
     Bereich;
   - Cross ohne Gültigkeitsaussage.
2. **SC-CP-Vorhersageintervall** (ADR 0010, Begriff **Vorhersageintervall**):
   - Generic `venn_abers_interval(object, new_data, level = 0.9, ...)`, nur
     Inductive mit `outcome_range` (manuell, Workflows, eingefroren);
   - exakt nach Ticket 19, ohne Gitter, bei der Vorhersage gerechnet;
   - Schwelle ist der `⌈level · N⌉`-kleinste Score der Niveaumenge samt Test;
   - Ausgabe nur die Spannweite (`.pred_lower`/`.pred_upper`, dazu `.pred`
     und das VA-Paar); keine Rückfallregel. Eine leere Menge ist ein
     interner Fehler;
   - Cross, fehlender Bereich und Klassifikation brechen ab.
3. **Gemeinsame Quantil-Hilfsfunktion** mit `quantile(type = 1)`-Semantik
   samt Fuzz. Sie dient SC-CP jetzt und der Quantil-VA in 1.5.
4. **`coverage_plot(truth, lower, upper, prediction, level = NULL, bins =
   10, ...)`** als Bewertungsgrafik: Abdeckung je Quantilbin von
   `prediction` mit Linie bei `level`, darunter die mittlere Breite je Bin.

### Release-Grenze

Ohne `outcome_range` bleiben IVAR, CVAR, `print()` und
`venn_abers_details()` bitgleich. `predict()` gibt kein Intervall aus; kein
Tuning und keine Interop für `venn_abers_interval()`. Die N-Aussage des
beschränkten IVAR hängt an der Vorabprüfung (Schritt 1).

### Geordnete Umsetzung

1. Vorabprüfung: Die binäre Komponente der Hauptreferenz auf `(y − C_*)/(C^*
   − C_*)` mit gebrochenen Labels wird numerisch gegen den Kern belegt.
   Gelingt das, gibt es eine PARITY-Zeile mit Pin; sonst nur Orakel.
2. `outcome_range` in Kernen, Workflows, eingefrorenen Workflows und
   `adjust_venn_abers_numeric()`, mit Labelprüfung und `print()`.
3. Gleichheitstest: `venn_abers_threshold()` arbeitet unverändert auf
   beschränkten Objekten.
4. Gemeinsame Quantil-Hilfsfunktion.
5. `venn_abers_interval()` auf dem in 1.3 gespeicherten C.
6. `coverage_plot()`.
7. Gegenvergleich SelfCalibratingConformal, PARITY-Abschnitt,
   Minor-Prüfpunkt, Abnahme.

### Berührte Wege

M, W, E, T, P, G. Im Einzelnen:

- beschränkter IVAR: M, W, E, T, P, G nur Smoke;
- SC-CP: M, W, E, G, P als gezielter Fall.

### Überprüfbare Abnahme

- **Beschränkter IVAR:**
  - M: Orakel gegen `venn_abers()` bei 0/1-Labels mit `c(0, 1)` und gegen
    die Max-Min-Charakterisierung;
  - Randfälle `k = 1, 2`, Gleichstände, Labels auf den Grenzen, konstante
    Labels, Skalen `1e-12`/`1e120`/Verschiebung `1e5`;
  - Abbrüche wie im Vertrag; CVAR gleich dem Mittel der Fold-Kerne;
  - N nach der Vorabprüfung;
  - W/E bitgleich zum Kern; T Grid und Bayes je ein Fall, Abbruch bei
    `tune()` neben `outcome_range`;
  - P: tailor linear und isoton, je Inductive und Cross;
    `adjust_venn_abers_numeric(outcome_range =)` bitgleich;
  - G: Smoke der Fit-Diagnose mit Referenzlinien.
- **SC-CP:**
  - M (bindend): Brute-Force-Orakel nach Alg. 2 über endliches 𝒴;
  - Eigenschaften: nie leer, Spannweite ⊇ Menge, VA-Endpunkte bitgleich zum
    beschränkten IVAR, monoton in `level`;
  - Randfälle und Abbrüche wie im Vertrag;
  - W/E bitgleich zum Kern, `saveRDS()`-Rundlauf;
  - P: Inductive mit tailor-Postprocessor;
  - G: `coverage_plot()`-Smoke und Bin-Werte gegen Handrechnung;
  - Gegenvergleich SelfCalibratingConformal @ `fa2a1eb` ohne Toleranzzusage,
    Skript unter `tools/`.
- **Releasetreue:** Archivvergleich gegen 1.3; ohne Bereich alles bitgleich.
- **Leistung:** kein CI-Messfall. Das Umsetzungsticket bestätigt einmal die
  Laufzeit aus Ticket 19 (`n_test = 1e4`: 0,11/0,38/0,69 s bei `n_cal` =
  1e3/1e4/1e5). Bestehende Regressionsfälle gegen 1.3.

Quellen: [Vertrag für den beschränkten IVAR festlegen][bounded],
[Vertrag für das SC-CP-Vorhersageintervall festlegen][sccp],
[SC-CP-Rechenweg in reinem R prototypisch messen][sccp-proto],
[VA-Regression nach van der Laan/Alaa und Venn-Multikalibrierung
zuschneiden][family].

## 8. 1.5 — Quantile und Multikalibrierung

### Ziel und Umfang

Zwei unabhängige Stränge.

1. **VA-Quantilkalibrierung** (ADR 0012, Begriff **Zentrum**):
   - nur der manuelle Kern `venn_abers_quantile(truth, center, prediction,
     level = 0.9)`, nur Inductive. Der Nutzer liefert Zentrum `µ` und
     Score-Quantilmodell `f`;
   - Score fest `|y − µ(x)|`, Bindungen gepoolt;
   - exakt nach Ticket 23, alle `2m + 1` Positionen beim Fit vorberechnet,
     kein C im Objekt;
   - `level` beim Fit fest; `venn_abers_interval()` lehnt ein abweichendes
     ab, `predict()` bricht ab;
   - Ausgabe `center`, `threshold_lower`/`_upper`, `interval_lower`/`_upper`
     = exakt `µ ± s_max`; `±Inf` zulässig, die Regel
     `r < level/(1 − level)` steht in der Hilfe;
   - `coverage_plot()` mit Behandlung unendlicher Intervalle. Das gilt auch
     für SC-CP: Die Abdeckung zählt sie mit; das Breitenpanel mittelt
     endliche Breiten und vermerkt den Anteil unendlicher.
2. **Venn-Multikalibrierung** (ADR 0011, Begriff **Venn-Multikalibrierung**):
   - reines Alg. 3 auf der rohen Quellmodell-Vorhersage, eigenes Verfahren
     neben dem IVAR;
   - unbestrafte KQ mit Konstante, `outcome_range` zwingend, nur Inductive
     und Regression;
   - exakt geschlossen über den Hebelwert;
   - `G` manuell als Matrix `basis`, in Workflows als Formel
     `multicalibration = ~ …` über Rohspalten, auf B gelernt, in
     `calibrate_workflow()` auf C mit Hinweis;
   - `venn_multicalibration()` mit Grenzen in `.pred_va_lower`/`_upper`;
   - Vignette mit Mittelresiduen je Gruppe in Base-R.

### Release-Grenze

- Quantil-VA: keine Workflows, keine Interop, kein Tuning, keine
  Punktschwelle, kein Ergebnisbereich.
- Multikalibrierung: keine Grafik, keine Interop, kein Tuning über die
  Formel; kein Vorhersageintervall.
- Beide: kein Cross.

### Geordnete Umsetzung

1. `venn_abers_quantile()` auf der gemeinsamen Hilfsfunktion, mit
   Orakeltests der eigenen Ableitung.
2. `coverage_plot()` für `±Inf`.
3. Unabhängig davon: `venn_multicalibration()` manuell mit Orakel gegen
   `lm()`, dann Workflows mit `multicalibration = ~ …`, eingefroren, ein
   gezielter P-Fall.
4. Gegenvergleich SelfCalibratingConformal für die Quantil-VA, PARITY,
   Vignette, Minor-Prüfpunkt, Abnahme.

### Berührte Wege

- Quantil-VA: M, G;
- Multikalibrierung: M, W, E, P als gezielter Fall.

### Überprüfbare Abnahme

- **Quantil-VA:**
  - M: Orakel gegen Rangintervall und Brute Force; Bindungen, oberste und
    unterste Position, `level` nahe 0 und 1;
  - Blockindex an ganzzahligem `level · N` für `level` ∈ {0.5, 0.8, 0.9,
    0.95, 0.99} und `N` bis 1000;
  - vorberechnet gegen vorhersagezeitlich bitgleich; `saveRDS()`-Rundlauf;
  - Abbrüche wie im Vertrag;
  - G: `coverage_plot()` mit unendlichen Intervallen, Bin-Werte gegen
    Handrechnung;
  - Gegenvergleich SelfCalibratingConformal @ `fa2a1eb` ohne
    Toleranzzusage.
- **Multikalibrierung:**
  - M: `lm()` auf C ∪ {(x, y)} an beiden Grenzen und der Punkt gegen
    `predict(lm())` auf C, geklemmt, in der Regressionstoleranz;
  - Eigenschaften `λ ∈ [0, 1]`, `λ = 1` außerhalb des Zeilenraums,
    Fixpunkt, Invarianz der Spannweite; Abbrüche wie im Vertrag;
  - W/E bitgleich zum Kern auf derselben Vorhersage und Basis;
    `saveRDS()`-Rundlauf;
  - P: ein Fall mit tailor-Postprocessor vor dem Kalibrator.
- **Releasetreue:** Archivvergleich gegen 1.4; ohne `multicalibration`
  bitgleich.
- **Messfall:** Quantil-VA mit `n_cal` = 1e3/1e4/1e5 und `n_test = 1e4`, mit
  dem Prototyp aus Ticket 23 als Vergleichswert. Der Fit darf nicht
  langsamer sein (Prototyp 0,07/0,93/10,8 s), eine harte Zeitzusage gibt es
  nicht. Für die Multikalibrierung kein Messfall.

Quellen: [Vertrag für die VA-Quantilkalibrierung festlegen][quantile],
[Rechenweg der VA-Quantilkalibrierung in reinem R prototypisch
messen][quantile-proto], [Vertrag für die Venn-Multikalibrierung
festlegen][multical].

## 9. Wiederkehrende Prüfpunkte

### 9.1 Minor-Prüfpunkt

Ein fester Schritt vor jedem Minor-Releasekandidaten, protokolliert im
Release-Prüfprotokoll; die Checkliste steht auch in `tools/RELEASE.md`.

1. **Referenzen sichten (blockierend nur die Dokumentation):** neue Releases
   der Hauptreferenz und jeder Verfahrensreferenz.
   - Jede neue Fähigkeit wird übernommen, dann als neues Ticket und nie im
     laufenden Minor, oder ausdrücklich nicht übernommen.
   - Geänderte Werte führen zu einem D-Eintrag und einem 2.0-Kandidaten; der
     Pin bleibt.
2. **Gegenvergleiche neu ausführen** (nicht blockierend): MAPIE,
   calibrated-explanations, reliabilitydiag, `ptocca/VennABERS` und ab 1.4
   SelfCalibratingConformal, gegen die aktuellen Releases bzw. Commits;
   notfalls „zuletzt geprüft mit Version X“.
3. **Preprint-Aussagen nachprüfen** (nicht blockierend): derzeit Petej/Vovk
   2026, Thm. 2 (beschränkter IVAR). Bei Begutachtung wird die Kennzeichnung
   in Hilfe und PARITY angepasst.
4. **tidymodels-`main`-Lauf auswerten** (ab 1.2, nicht blockierend): Brüche
   der abgegrenzten Interna als Ticket festhalten.

### 9.2 CRAN-Prüfpunkt

- **Zeitpunkt:** sechs Monate nach der CRAN-Annahme von 1.0 oder nach dem
  Release von 1.2, je nachdem, was später liegt; danach jährlich.
- **Belege:** GitHub-Issues und -Diskussionen, cranlogs-Downloads,
  Rückabhängigkeiten, Nutzerkontakte.
- **Befugnis:**
  - die Reihenfolge noch nicht begonnener Milestones ändern, unter Erhalt
    der Kanten aus Abschnitt 1;
  - jede Wiedervorlage aus Abschnitt 10 entscheiden: neues Ticket, bleibt
    zurückgestellt oder außerhalb;
  - die Auslöser für kompilierten Code prüfen (ADR 0002). Das ist entweder
    ein realer Nutzerfall, der trotz verbessertem R-Kern und `precision`
    untragbar ist, oder ein Vertragsticket, das untragbaren Kernaufwand für
    ein neues Verfahren misst.
- **Grenze:** Ein begonnener Milestone wird nicht umgebaut.

## 10. Wiedervorlageliste

Alles hier liegt im Ziel, hat aber keinen Milestone. Entschieden wird am
CRAN-Prüfpunkt.

**Zurückgestellte Lücken (Lückenkatalog):**

- bis eine Quelle vorliegt: K16 Fallgewichte im Kalibrator, K18
  gruppenbewusste lokale Aufteilungen, K19 Mondrian- bzw. gruppenbedingte VA;
- schwellenfähig, ohne Milestone: K01 Venn-Prädiktoren mit freier Taxonomie,
  K02 voller VA, K03 IVAP über teilgeordnete Scores, K05 CVAP-GM-Intervall
  als allgemeine Ausgabe, K10 IVAPD, K12 VA für Mengenereignisse, K14 exakter
  IVAR-Punkt nach Gl. (5), K15 Conformal IDR, K25 Venn-PDMS-Entscheidungsregeln.

**Aus den Verträgen:**

| Vertrag | Wiedervorlagen |
|---|---|
| Top-Label-VA | klassenbedingte Top-Label-VA; Cross mit passenden Fold-Modellen; Top-Label-Metrik für yardstick; Top-Label in den tailor-/probably-Bausteinen |
| VA-Abstention | Breiten für OvO/OvR; Regression; Wahl bzw. Tuning von β; tailor-Adjustment bzw. `.pred_va_width`; Literatur mit Gültigkeitsaussage für eine Breitenregel |
| Schwellenwahrscheinlichkeiten | zeilenweise Schwellen; Intervallereignisse `a < y ≤ b`; frei übergebene Scores bzw. Schwierigkeitsnormierung; Kurvengrafik je Zeile; tailor-Adjustment |
| Beschränkter IVAR | naiver IVAR mit Grenzen aus den Daten; einseitige Grenzen; Formel (5) (K14); weitere Regressionsfamilien bzw. Fallgewichte im Kalibrator (K16); Literatur zu beschränktem CVAR bzw. begutachtetes Thm. 2 |
| VA-Regressionsfamilie | allgemeine Verluste mit frei übergebbarem ℓ; Quantil-Multikalibrierung; Multikalibrierung für Klassifikation; Cross-Varianten |
| SC-CP | Cross-/CV-Varianten; Ergebnisbereich aus den Daten; Punkt nach Gl. (4); Stücke bzw. Stückzahl; `predict(type = "pred_int")`; mehrere Niveaus; Scores „debiased“/„original“; Numerik (kompakte Vorberechnung, rationales Orakel) |
| Quantil-VA | Workflows mit Zentrum (zuerst eingefrorene Workflow-Paare, dann W/E/T); wählbare oder asymmetrische Scores; wahlweiser Ergebnisbereich; Punktschwelle nach Gl. (4) bei Quelle; Nachprüfung der eigenen Ableitung gegen eine Quelle |
| Venn-Multikalibrierung | Quantil-Multikalibrierung (Gibbs-CP); Klassifikation; Cross; bestrafte bzw. Ridge-Varianten; Grafik je Gruppe; Interop-Spalten; K18/K19 bzw. Mondrian |
| Interop | upstream-Delegation von probably an `vennabers` mit Extraktor (optional, ohne Milestone) |

## 11. 2.0-Kandidaten

Nur gesammelt, nicht geplant. Neue Kandidaten kommen am Minor- oder
CRAN-Prüfpunkt hinzu.

- Abstention als eigene Stufe der Klassenentscheidung; das bricht den
  Faktor-Vertrag.
- Werte einer neueren Referenzversion, die ausgelieferte Werte ändern
  (Releasetreue vor Referenztreue).

## 12. Außerhalb dieser Roadmap

- Umsetzung, CRAN-Einreichungen und Software-Artikel (JOSS/R Journal):
  getrennte Spur.
- Meldung der im Gegenvergleich gefundenen Defekte an MAPIE und
  calibrated-explanations: Sache des Maintainers.
- Planung von Breaking Changes bzw. 2.0.
- Allgemeine Zeitreihenverfahren jenseits der Referenzaufteilungen.
- OOF-Postprocessing mit Engine-Refit, Tailor-Schrittfolgen, weitere
  Postprocessing-Methoden und fremde Engines jenseits von `model_adapter()`.
- Allgemeine Conformal-Verfahren ohne Venn-/VA-Kern; Online-Verfahren (auch
  VATE, K26).
- Schwellenwahl bzw. Equivocal Zone (K21) sowie allgemeine
  Kalibrierungskennzahlen und -tests (K22). Diese decken probably, tailor und
  yardstick ab.
- Kompilierter Code, bis ein Auslöser nach Abschnitt 9.2 ein neues
  Entscheidungsticket begründet.

## 13. Übergabe an die Umsetzung

Jetzt wird nur 1.1 mit `/to-issues` in Umsetzungstickets geschnitten. Jedes
weitere Minor wird geschnitten, sobald sein Vorgänger bei CRAN eingereicht
ist. Bis dahin darf der CRAN-Prüfpunkt die Reihenfolge noch ändern. Die
Tickets erhalten die geordnete Umsetzung, die Quellenverträge und die
Abnahme ihres Kapitels. Weicht eine Umsetzung von einem Vertrag ab, wird
genau diese Abweichung gesondert entschieden.

Messwerte, Runnerstände, ermittelte Mindestversionen und bestandene
Prüfungen sind Umsetzungsnachweise. Sie werden nicht vorweggenommen.

## 14. Entscheidungsquellen

**Karte und Synthese:** [Roadmap für vennabers nach 1.0][map];
[1.x-Milestones zuschneiden und die Roadmap festhalten][synthesis].

**Recherchen und Messungen:**

- [Kerntheorie der Venn- und Venn-Abers-Prädiktoren katalogisieren][core]
- [Angewandte und ML-Erweiterungen von Venn-Abers katalogisieren][applied]
- [Venn-Abers- und Kalibrierungssoftware mit vennabers vergleichen][software]
- [Erweiterbarkeit von probably und tailor für Venn-Abers klären][tailor]
- [Leistung der VA-Kerne gegen den Workflow-Aufwand messen][perf]
- [Weitere VA-Software numerisch gegen vennabers abgleichen][numeric]
- [Vektorisierte CVAR-Mittelung prototypisch messen][cvar]
- [SC-CP-Rechenweg in reinem R prototypisch messen][sccp-proto]
- [Rechenweg der VA-Quantilkalibrierung in reinem R prototypisch messen][quantile-proto]

**Entscheidungen und Verträge:**

- [Lückenkatalog zusammenführen und priorisieren][gaps]
- [Über kompilierten Code für die VA-Kerne entscheiden][compiled] (ADR 0002)
- [Den Weg zur probably-/tailor-Interop entscheiden][interop] (ADR 0003)
- [Paritätsvergleiche mit weiterer VA-Software festlegen][parity] (ADR 0004)
- [Vertrag für Fallgewichte im Quellmodell-Fit festlegen][weights] (ADR 0005)
- [Vertrag für Top-Label-VA festlegen][toplabel] (ADR 0006)
- [Vertrag für die Abstention über die VA-Breite festlegen][abstention] (ADR 0007)
- [Vertrag für VA-Schwellenereignisse festlegen][threshold] (ADR 0008)
- [Vertrag für den beschränkten IVAR festlegen][bounded] (ADR 0009)
- [VA-Regression nach van der Laan/Alaa und Venn-Multikalibrierung zuschneiden][family]
- [Vertrag für das SC-CP-Vorhersageintervall festlegen][sccp] (ADR 0010)
- [Vertrag für die Venn-Multikalibrierung festlegen][multical] (ADR 0011)
- [Vertrag für die VA-Quantilkalibrierung festlegen][quantile] (ADR 0012)

**Literatur:**

- Vovk, V., Petej, I., Fedorova, V. (2015). Large-scale probabilistic
  predictors with and without guarantees of validity. *NeurIPS 28*.
- Johansson, U. et al. (2021). Calibrating multi-class models. *PMLR 152*
  (COPA).
- Petej, I., Vovk, V. (2026). Inductive Venn–Abers and related regressors.
  arXiv:2605.06646. Preprint.
- van der Laan, L., Alaa, A. M. (2024). Self-calibrating conformal
  prediction. *NeurIPS 37*. arXiv:2402.07307.
- van der Laan, L., Alaa, A. (2025). Generalized Venn and Venn-Abers
  calibration with applications in conformal prediction. *Proc. ICML 2025*,
  PMLR 267. arXiv:2502.05676.

[map]: .scratch/post-1.0-roadmap/map.md
[synthesis]: .scratch/post-1.0-roadmap/issues/09-roadmap-synthese.md
[core]: .scratch/post-1.0-roadmap/issues/01-kerntheorie-katalogisieren.md
[applied]: .scratch/post-1.0-roadmap/issues/02-angewandte-erweiterungen-katalogisieren.md
[software]: .scratch/post-1.0-roadmap/issues/03-softwarevergleich.md
[tailor]: .scratch/post-1.0-roadmap/issues/04-probably-tailor-erweiterbarkeit.md
[perf]: .scratch/post-1.0-roadmap/issues/05-kernleistung-messen.md
[gaps]: .scratch/post-1.0-roadmap/issues/06-lueckenkatalog-priorisieren.md
[compiled]: .scratch/post-1.0-roadmap/issues/07-kompilierter-code-entscheiden.md
[interop]: .scratch/post-1.0-roadmap/issues/08-interop-weg-entscheiden.md
[numeric]: .scratch/post-1.0-roadmap/issues/10-va-software-numerisch-abgleichen.md
[parity]: .scratch/post-1.0-roadmap/issues/11-paritaetsvergleiche-festlegen.md
[weights]: .scratch/post-1.0-roadmap/issues/12-vertrag-fallgewichte-quellmodell.md
[toplabel]: .scratch/post-1.0-roadmap/issues/13-vertrag-top-label-va.md
[abstention]: .scratch/post-1.0-roadmap/issues/14-vertrag-abstention-va-breite.md
[threshold]: .scratch/post-1.0-roadmap/issues/15-vertrag-va-schwellenereignisse.md
[bounded]: .scratch/post-1.0-roadmap/issues/16-vertrag-beschraenkter-ivar.md
[family]: .scratch/post-1.0-roadmap/issues/17-familie-va-regression-multikalibrierung.md
[cvar]: .scratch/post-1.0-roadmap/issues/18-cvar-mittelung-prototyp.md
[sccp-proto]: .scratch/post-1.0-roadmap/issues/19-sccp-rechenweg-prototyp.md
[sccp]: .scratch/post-1.0-roadmap/issues/20-vertrag-sccp-vorhersageintervall.md
[quantile]: .scratch/post-1.0-roadmap/issues/21-vertrag-va-quantilkalibrierung.md
[multical]: .scratch/post-1.0-roadmap/issues/22-vertrag-venn-multikalibrierung.md
[quantile-proto]: .scratch/post-1.0-roadmap/issues/23-quantil-va-rechenweg-prototyp.md
