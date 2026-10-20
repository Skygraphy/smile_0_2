# Smile-Testsuite

Systemtests auf echten Geräten, von null an. Sie laufen gegen das eigene
Testprojekt `smile_0_2_testsuite` (`ohcrvjvhglrxxrkyrnhr`) mit der Test-App
**Smile Test** (`com.smile.smile_app.test`), die neben der echten App
installiert ist. Das Live-Projekt und die echte App werden nie berührt.

## Werkzeuge

| Datei | Zweck |
|---|---|
| `env.sh` | lädt URL und Schlüssel des Testprojekts (`source`); verweigert das Live-Projekt |
| `reset.sh` | setzt das Testprojekt auf null: alle User, Daten, Dateien |
| `reset.sql` | Datenbank-Teil davon; bricht ab, sobald es einen User ohne `@example.com` gibt |
| `reset_storage.ts` | löscht alle Dateien in allen Buckets |
| `build_app.sh [debug\|release]` | baut Smile Test nach `smile-app/build/smile-test-<mode>.apk` |
| `otp.ts <email>` | erzeugt den 6-stelligen Anmeldecode einer Testperson |
| `dev.sh` | Geräte-Helfer (`source`, `DEV=<adb-serial>`): `clear_app`, `tips_off`, `demo_mode`, `login`, `tap_el`, `wait_el`, `type_text`, `shot` |
| `person.ts` | legt eine Testperson ohne Gerät an (Profil, optional Smile-Name) |
| `chapter.sh` | Kapitel-Rekorder: `begin_chapter`, `step`, `check`, `snap`, `sql_value` |
| `chNN.sh` | ein Kapitel, von seinem Startzustand an; schreibt `out/chNN/` |
| `findings.json` | die Funde mit Status |
| `build_site.sh` | baut die Tutorial-Web-App nach `out/site` (`site/index.html` + Kapitel + Funde) |

## Die Test-App

Gebaut mit `--dart-define=SMILE_TEST=true`:

- Kennung `com.smile.smile_app.test`, Name „Smile Test“ bzw. „Frame Test“
  (`smile-app/android/app/build.gradle.kts`).
- Verschickt keine Anmelde-Mail; den Code liefert `otp.ts`
  (`lib/screens/login_screen.dart`).
- Statt Galerie und Kamera: 12 erfundene Testbilder, jedes dritte hochkant,
  dazu Testvideos aus `Android/data/com.smile.smile_app.test/files/fixtures/`
  (`lib/services/test_media.dart`). So kommt nie ein privates Foto in einen
  Test oder ins Tutorial.

## Testpersonen

Nur Adressen `@example.com` (Supabase verschickt dorthin nichts).

| Person | E-Mail | Gerät |
|---|---|---|
| Anna Berger | anna.berger@example.com | S26 |
| Paul Berger | paul.berger@example.com (Smile-Name paul.berger) | ohne Gerät |

## Ein Kapitel laufen lassen

```sh
DEV_S26=192.168.0.107:40549 ./ch01.sh   # Startzustand herstellen, durchspielen, aufnehmen
./build_site.sh                          # Web-App aufbereiten, dann veröffentlichen
```

Jedes Kapitel stellt seinen Startzustand selbst her (Reset und Vorbereitung),
läuft also beliebig oft und unabhängig. Das ist zugleich das Zurücksetzen.
Die Tipps sind in den Läufen aus, sie haben ein eigenes Kapitel. Die
Bestätigungen (Passt / Passt nicht) liegen in der Datenbank der Web-App,
Sammlung `reviews`, Dokument `chNN-SS`.

## Beispiel: von null an anmelden

```sh
cd tools/testsuite
./reset.sh
source ./env.sh; DEV=192.168.0.107:36387; source ./dev.sh
clear_app; login anna.berger@example.com
wait_el "Wie sollen wir dich nennen"
```
