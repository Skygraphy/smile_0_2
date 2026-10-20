# Smile: Versionen

Jede Version, die getestet wird, bekommt eine eigene Nummer (0.0.1, 0.0.2 …),
ein Tutorial (Testsuite, `tools/testsuite`) und einen festen Stand im Git
(Tag `v0.0.1` …). Eine neue Version entsteht mit `tools/testsuite/release.sh`.

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
