# Smile: Versionen

Jede Version, die getestet wird, bekommt eine eigene Nummer (0.0.1, 0.0.2 …),
ein Tutorial (Testsuite, `tools/testsuite`) und einen festen Stand im Git
(Tag `v0.0.1` …). Eine neue Version entsteht mit `tools/testsuite/release.sh`.

## 0.0.10 (2026-10-25)

Neues Kapitel 6: Frame verbinden.

Behoben:

- 30: Frame verbinden am Tablet: Knopf unter der Tastatur

## 0.0.9 (2026-10-22)

Neues Kapitel 5: Leute einladen.

Behoben:

- 28: Buchstabenleiste in den Kontakten lief über
- 29: Album-Seite nach dem Verlassen meldete einen Fehler

## 0.0.8 (2026-10-22)

Gewählte Optionen coral.

Behoben:

- 27: Gewählte Option sah grau und gesperrt aus

## 0.0.7 (2026-10-21)

Kapitel 4 (Im Album) dazu.

Behoben:

- 25: Zurück-Geste verließ das Album statt Auswahl oder Ausgeblendete zu schließen
- 26: Diashow: Fehler, wenn die Einstellungen ein ladendes Video ersetzen

## 0.0.6 (2026-10-21)

Datumsmarke und lange Namen.

Behoben:

- 23: Datumsmarke Heute verdeckte den Titel des obersten Fotos
- 24: Lange Namen wurden gleich abgeschnitten

## 0.0.5 (2026-10-21)

Kapitel 3 (Fotos und Videos senden) dazu.

Behoben:

- 22: Senden an: mit offener Tastatur unten abgeschnitten

## 0.0.4 (2026-10-21)

Anfangsbuchstaben wie bei Personen.

Behoben:

- 21: Space aus mehreren Wörtern: Anfangsbuchstaben wie bei Personen

## 0.0.3 (2026-10-21)

Kapitel 2 (Space und Alben) dazu, vier Verbesserungen daraus.

Behoben:

- 17: Bild entfernen fehlte gleich nach dem Wählen eines Bildes
- 18: Beispieltext im Namensfeld abgeschnitten
- 19: Anlegen ohne Namen schloss das Fenster stumm
- 20: Titelbild: Automatisch zeigte noch einige Sekunden das alte Bild

## 0.0.2 (2026-10-20)

Sechs Verbesserungen aus der Durchsicht von Kapitel 1.

Behoben:

- 11: Tastatur verdeckt Bestätigen und Andere E-Mail-Adresse
- 12: Startseite nannte nur die E-Mail-Adresse als Weg zur Einladung
- 13: Smile-Name: Meldung zählte alle Regeln auf statt des einen Fehlers
- 14: Profilbild in der Begrüßung: das gewählte Bild steht sofort im Kreis, keine Anfangsbuchstaben dazwischen.
- 15: Smile-Name: Noch zu kurz. Mindestens 3 Zeichen. (ohne die Regeln zu wiederholen)
- 16: Smile-Name: Leerzeichen, Umlaute und Sonderzeichen kommen nicht ins Feld, ein grauer Hinweis sagt warum und was stattdessen geht.

## 0.0.1 (2026-10-20)

Erste Version mit Testsuite und Tutorial. Kapitel 1 (Erster Start) ist mit
allen Abzweigungen durchgespielt.

Behoben (Funde aus Kapitel 1):

- 1, 3: Fehlermeldungen der Anmeldung stehen direkt unter dem Feld statt verdeckt unter der Tastatur.
- 2: Das Profilbild aus der Begrüßung ging verloren.
- 4: Ein geändertes Profilbild zeigte auf Handys weiter das alte (eigene Datei je Bild, Migration 0086).
- 5: Bild von einer Internetadresse: der Dialog bleibt offen, bis das Bild geladen ist, und meldet Fehler unter dem Feld.
- 6: Bitte gib deinen Namen ein verschwindet beim Tippen.
- 7, 8: Leeres Feld und falsch geschriebene E-Mail-Adresse werden gemeldet.
- 9: Smile-Name: frei in Grün, vergeben oder ungültig in Rot mit genauem Grund, dazu freie Vorschläge.
- 10: Meine Karte ohne Smile-Namen zeigt die Karte als Vorschau, Vorschlag mit einem Tipp übernehmen.

Neu: gezeichnete Testbilder, Testvideos und Profilbilder für die Test-App.
