# Smile-Testsuite

Systemtests auf echten Geräten, von null an. Sie laufen gegen das eigene
Testprojekt `smile_0_2_testsuite` (`ohcrvjvhglrxxrkyrnhr`) mit der Test-App
**Smile Test** (`com.smile.smile_app.test`), die neben der echten App
installiert ist. Das Live-Projekt und die echte App werden nie berührt.

Jedes Kapitel spielt den Hauptweg und **jede Abzweigung** durch (was etwas
ändert, wird gleich wieder zurückgenommen). Daraus entstehen das Tutorial
(Schritt, Bild, Anleitung, erwartetes Ergebnis) und die **Abdeckungskarte**:
jeder antippbare Knopf jeder Seite ist grün (geprüft), gelb (folgt in einem
späteren Kapitel) oder rot (übersehen). Am Ende darf nichts Rotes bleiben,
und alle automatischen Prüfungen müssen grün sein.

## Werkzeuge

| Datei | Zweck |
|---|---|
| `env.sh` | lädt URL und Schlüssel des Testprojekts (`source`); verweigert das Live-Projekt |
| `reset.sh` | setzt das Testprojekt auf null: alle User, Daten, Dateien |
| `reset.sql` | Datenbank-Teil davon; bricht ab, sobald es einen User ohne `@example.com` gibt |
| `reset_storage.ts` | löscht alle Dateien in allen Buckets |
| `build_app.sh [debug\|release]` | baut Smile Test nach `smile-app/build/smile-test-<mode>.apk` |
| `otp.ts <email>` | erzeugt den 6-stelligen Anmeldecode einer Testperson |
| `person.ts` | legt eine Testperson ohne Gerät an (Profil, optional Smile-Name) |
| `make_portraits.js` | zeichnet die 6 Profilbilder (Frau/Mann, jung/mittel/alt) nach `fixtures/profiles/` |
| `make_media.js` | zeichnet 45 Testbilder und 5 Testvideos nach `fixtures/media/` (nicht im Git, jederzeit gleich neu erzeugt) |
| `dev.sh` | Geräte-Helfer (`source`, `DEV=<adb-serial>`): `clear_app`, `tips_off`, `push_fixtures`, `demo_mode`, `login`, `tap_el`, `tap_last`, `tap_at`, `wait_el`, `go_back`, `type_text`, `shot` |
| `chapter.sh` | Kapitel-Rekorder: `begin_chapter`, `screen`, `step`, `check`, `snap`, `mask_id`, `sql_value`, `screen_color_near`; Gerätesperre |
| `chNN.sh` | ein Kapitel, von seinem Startzustand an; schreibt `out/chNN/` |
| `coverage.json` | was ein Kapitel sieht, aber ein späteres prüft (gelb), und feste Namen für wechselnde Beschriftungen |
| `coverage.js` | baut die Abdeckungskarte aus allen Kapiteln |
| `findings.json` | die Funde mit Status |
| `build_site.sh` | baut die Tutorial-Web-App nach `out/site` (`site/index.html` + Kapitel + Abdeckung + Funde) |

Einmalig: `npm install` (ffmpeg für die Testvideos), dann `node make_media.js`.

## Die Test-App

Gebaut mit `--dart-define=SMILE_TEST=true`:

- Kennung `com.smile.smile_app.test`, Name „Smile Test“ bzw. „Frame Test“
  (`smile-app/android/app/build.gradle.kts`).
- Verschickt keine Anmelde-Mail; den Code liefert `otp.ts`
  (`lib/screens/login_screen.dart`).
- Statt Galerie und Kamera eine eigene Auswahl
  (`lib/services/test_media.dart`) aus dem Ordner
  `Android/data/com.smile.smile_app.test/files/fixtures/` (`push_fixtures`):
  gezeichnete Bilder, Videos und Profilbilder, nichts Echtes. So kommt nie
  ein privates Foto in einen Test oder ins Tutorial.

## Datenschutz in den Bildern

Die Statusleiste zeigt keine Benachrichtigungen (`demo_mode`). Das
Teilen-Menü von Android zeigt echte Kontakte: dieser Bereich wird im Bild
geschwärzt (`mask_id android:id/resolver_list`).

## Testpersonen

Nur Adressen `@example.com` (Supabase verschickt dorthin nichts).

| Person | E-Mail | Profilbild | Gerät |
|---|---|---|---|
| Anna Berger | anna.berger@example.com | Frau, mittleres Alter | S26 |
| Paul Berger | paul.berger@example.com (Smile-Name paul.berger) | Mann, mittleres Alter | ohne Gerät |
| Oma Hilde | (ab Kapitel 6) | Frau, älter | Frame auf dem X200 |
| Lukas | (ab Kapitel 8) | Mann, jung | ohne Gerät |

## Ein Kapitel laufen lassen

```sh
DEV_S26=192.168.0.107:40549 ./ch01.sh   # Startzustand herstellen, durchspielen, aufnehmen
./build_site.sh                          # Web-App aufbereiten, dann veröffentlichen
```

Jedes Kapitel stellt seinen Startzustand selbst her (Reset und Vorbereitung),
läuft also beliebig oft und unabhängig. Das ist zugleich das Zurücksetzen.
Pro Gerät läuft immer nur ein Kapitel (Sperre `out/.lock_*`); fehlt ein
Knopf, bricht das Kapitel sofort ab statt blind weiterzutippen. Die Tipps
sind in den Läufen aus, sie haben ein eigenes Kapitel. Die Bestätigungen
(Passt / Passt nicht) liegen in der Datenbank der Web-App, Sammlung
`reviews`, Dokument `chNN-SS`.
