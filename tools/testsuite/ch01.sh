#!/usr/bin/env bash
# Kapitel 1: Erster Start. Anna Berger meldet sich zum ersten Mal an,
# wählt Namen, Profilbild und Smile-Namen, öffnet ihre Karte, und jede
# Abzweigung auf diesen Seiten wird mit durchgespielt (und wieder
# zurückgenommen, wo sie etwas ändert).
# Startzustand: Testprojekt leer (reset.sh), Test-App frisch.
set -uo pipefail
cd "$(dirname "$0")"
# Runs from a copy: bash reads a script while running it, so editing the
# chapter during a run would break that run.
if [ -z "${SMILE_RUN_COPY:-}" ]; then cp "$0" ".run_$(basename "$0")"; SMILE_RUN_COPY=1 exec bash ".run_$(basename "$0")" "$@"; fi
source ./env.sh; source ./dev.sh; source ./chapter.sh
DEV="${DEV_S26:?DEV_S26 setzen, z.B. 192.168.0.107:40549}"
lock_device
ANNA=anna.berger@example.com
person() { deno run --node-modules-dir=none --allow-net --allow-env "$(cygpath -w "$TESTSUITE_DIR/person.ts")" "$@" >/dev/null; }
anna_profile() { sql_value "select coalesce(p.$1::text,'') from public.profiles p join auth.users u on u.id=p.user_id where u.email='$ANNA'"; }
# The stored picture is that portrait (same size as its file).
anna_picture_is() { [ "$(sql_value "select o.metadata->>'size' from storage.objects o join public.profiles p on o.bucket_id='avatars' and o.name=p.avatar_path join auth.users u on u.id=p.user_id where u.email='$ANNA'")" = "$(stat -c %s "$TESTSUITE_DIR/fixtures/profiles/$1.png")" ]; }
anna_picture_files_are() { [ "$(sql_value "select count(*) from storage.objects o join auth.users u on o.name like 'users/'||u.id||'%' where o.bucket_id='avatars' and u.email='$ANNA'")" = "$1" ]; }
anna_is() { [ "$(anna_profile "$1")" = "$2" ]; }
# The picture circle on the Begrüßung page (it has no name of its own).
tap_avatar_circle() { hide_keyboard; sleep 1; tap_at 540 645 "Profilbild-Kreis"; }
# The six code boxes (drawn, no text field of their own).
tap_code_boxes() { tap_at 540 888 "Code-Kästchen"; sleep 1; }
three_options() { wait_el "Foto aufnehmen" 1 && wait_el "Von einer Internetadresse" 1; }
# A picture on the internet for the "Internetadresse" branch: one of the
# portraits, put into the project's public avatars bucket.
PORTRAIT_URL="$SUPABASE_URL/storage/v1/object/public/avatars/testsuite/frau_alt.png"
TEXT_URL="$SUPABASE_URL/storage/v1/object/public/avatars/testsuite/notiz.txt"     # a text, no picture
MISSING_URL="$SUPABASE_URL/storage/v1/object/public/avatars/testsuite/fehlt.png"  # nothing there
put_portrait() {
  curl -s -o /dev/null -X POST "$SUPABASE_URL/storage/v1/object/avatars/testsuite/frau_alt.png" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" -H "Content-Type: image/png" -H "x-upsert: true" \
    --data-binary "@$(cygpath -w "$TESTSUITE_DIR/fixtures/profiles/frau_alt.png")"
  printf 'Das ist kein Bild.' | curl -s -o /dev/null -X POST "$SUPABASE_URL/storage/v1/object/avatars/testsuite/notiz.txt" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" -H "Content-Type: text/plain" -H "x-upsert: true" --data-binary @-
}

# Startzustand
./reset.sh >/dev/null
person paul.berger@example.com "Paul Berger" paul.berger   # hat den Smile-Namen paul.berger schon
put_portrait
clear_app; tips_off; push_fixtures; demo_mode

begin_chapter ch01 "Erster Start" "Anna installiert Smile, meldet sich mit ihrer E-Mail-Adresse an, gibt sich einen Namen und ein Profilbild, wählt ihren Smile-Namen und öffnet ihre Karte. Jede Abzweigung auf diesen Seiten wird mitgeprüft: falscher Code, andere Adresse, leerer Name, alle drei Wege zum Profilbild, Namen ändern, Smile-Namen entfernen, Videos senden, Abmelden."

# ---------------------------------------------------------------- Anmeldung
step "Smile öffnen" "Smile zum ersten Mal öffnen." "Die Anmeldung erscheint: Smile-Logo, Feld für die E-Mail-Adresse, Code anfordern und Dieses Gerät als Frame verwenden."
explain "Smile startet ohne Anmeldung. Weil noch niemand angemeldet ist, zeigt die App die Anmeldung. Gespeichert ist auf dem Handy noch nichts."
start_app; screen "Anmeldung"; wait_el "Code anfordern" 20
check "Anmeldung sichtbar" wait_el "Code anfordern" 1
snap 1

step "Code anfordern ohne Adresse" "Code anfordern antippen, ohne etwas einzugeben." "Unter dem Feld steht: Bitte gib deine E-Mail-Adresse ein." Abzweigung
explain "Die App prüft das Feld, bevor sie den Server fragt. Ist es leer, wird gar nichts verschickt, nur der Hinweis erscheint."
tap_el "Code anfordern"; sleep 2
check "Meldung Bitte gib deine E-Mail-Adresse ein" wait_el "~Bitte gib deine E-Mail-Adresse ein" 3
check "Noch auf der Anmeldung" wait_el "Melde dich mit deiner E-Mail-Adresse an" 2
hide_keyboard; snap 1

step "Falsch geschriebene Adresse" "anna.berger@ eingeben und Code anfordern antippen." "Unter dem Feld steht: Das ist keine gültige E-Mail-Adresse. Bitte prüfe sie." Abzweigung
explain "Die App prüft die Schreibweise (etwas@etwas.endung). Eine unvollständige Adresse wird gemeldet, bevor eine Mail verschickt wird. Ob ein Postfach wirklich existiert, kann nur die Mail selbst zeigen."
type_into "E-Mail-Adresse" "anna.berger@"; tap_el "Code anfordern"; sleep 2
check "Meldung keine gültige E-Mail-Adresse" wait_el "~keine gültige E-Mail-Adresse" 3
hide_keyboard; snap 1

step "E-Mail-Adresse eingeben" "Die Adresse zu anna.berger@example.com vervollständigen." "Die Adresse steht im Feld, die Meldung ist verschwunden."
explain "Beim Weitertippen verschwindet der Hinweis von selbst. Noch ist nichts verschickt."
type_into "E-Mail-Adresse" "$ANNA"; hide_keyboard
check "Meldung verschwunden" gone_el "~keine gültige E-Mail-Adresse" 3
snap 1

step "Code anfordern" "Auf Code anfordern tippen (hier absichtlich zweimal schnell)." "Smile meldet, dass ein Code an die Adresse gesendet wurde, und zeigt sechs Kästchen für den Code."
explain "Der Server erzeugt einen 6-stelligen Code und schickt ihn per Mail. Gibt es zu der Adresse noch kein Konto, wird es dabei angelegt. (Die Test-App verschickt keine Mail, den Code liefert die Testsuite.)"
double_tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
check "Code-Eingabe sichtbar" wait_el "Wir haben einen Code" 1
check "Genau ein Konto für Anna, nichts doppelt" sql_is "select count(*) from auth.users where email='$ANNA'" "1"
hide_keyboard; snap 1

step "Andere E-Mail-Adresse verwenden" "Andere E-Mail-Adresse verwenden antippen." "Zurück auf der Anmeldung, die Adresse steht noch im Feld und kann geändert werden." Abzweigung
explain "Zurück zur Adresse, falls man sich vertippt hat. Der schon verschickte Code verfällt einfach."
tap_el "Andere E-Mail-Adresse"; screen "Anmeldung"; wait_el "Code anfordern" 10
check "Adresse noch im Feld" wait_el "$ANNA" 2
hide_keyboard; snap 1

step "Code noch einmal anfordern" "Code anfordern antippen." "Wieder die Code-Eingabe mit sechs Kästchen."
explain "Ein neuer Code wird erzeugt; der vorige gilt nicht mehr."
tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
hide_keyboard; snap 1

step "Falscher Code" "000000 eingeben." "Eine Meldung erscheint: Der Code stimmt nicht oder ist abgelaufen."  Abzweigung
explain "Nach der sechsten Ziffer prüft der Server den Code sofort. Er passt nicht, also bleibt man auf dieser Seite und sieht den Grund direkt unter den Kästchen."
tap_code_boxes; type_text "000000"; sleep 3
check "Meldung Code stimmt nicht sichtbar" wait_el "Der Code stimmt nicht" 5
snap 1

step "Bestätigen antippen" "Mit dem falschen Code noch einmal Bestätigen antippen." "Wieder die Meldung: Der Code stimmt nicht oder ist abgelaufen." Abzweigung
explain "Bestätigen schickt denselben Code noch einmal zur Prüfung; das Ergebnis ist gleich."
hide_keyboard; tap_el "Bestätigen"; sleep 3
check "Meldung Code stimmt nicht sichtbar" wait_el "Der Code stimmt nicht" 5
snap 1

step "Code eingeben" "Die Kästchen leeren und den richtigen 6-stelligen Code aus der E-Mail eingeben." "Smile fragt: Wie sollen wir dich nennen? Darunter ein Kreis mit Fragezeichen und das Namensfeld."
explain "Der richtige Code meldet Anna an. Weil es noch kein Profil gibt, fragt Smile zuerst nach dem Namen."
tap_code_boxes; for _ in 1 2 3 4 5 6; do a shell input keyevent 67; done; type_text "$(otp_for "$ANNA")"; screen "Begrüßung"; wait_el "Wie sollen wir dich nennen" 20
check "Begrüßung sichtbar" wait_el "Wie sollen wir dich nennen" 1
hide_keyboard; snap 1

# ---------------------------------------------------------------- Begrüßung
step "Weiter ohne Namen" "Gleich Weiter antippen, ohne einen Namen einzugeben." "Eine Meldung erscheint: Bitte gib deinen Namen ein." Abzweigung
explain "Ohne Namen wird nichts gespeichert. Der Hinweis steht unter dem Feld."
tap_el "Weiter"; sleep 2; hide_keyboard
check "Meldung Bitte gib deinen Namen ein" wait_el "Bitte gib deinen Namen ein" 3
snap 1

step "Namen eingeben" "Anna Berger ins Namensfeld schreiben." "Im Kreis erscheinen sofort die Anfangsbuchstaben AB, die Meldung von vorhin ist weg."
explain "Aus dem Namen entstehen sofort die Anfangsbuchstaben im Kreis. Gespeichert wird erst mit Weiter."
type_into "Name" "Anna Berger"; hide_keyboard
check "Anfangsbuchstaben AB" wait_el "AB" 3
check "Meldung ist beim Tippen verschwunden" gone_el "Bitte gib deinen Namen ein" 3
snap 1

step "Profilbild: Auswahl" "Auf den Kreis mit dem Kamera-Symbol tippen." "Drei Möglichkeiten: Foto aufnehmen, Vorhandenes Bild wählen, Von einer Internetadresse laden."
explain "Drei Wege zum Profilbild: Kamera, ein Bild vom Handy oder eines aus dem Internet."
tap_avatar_circle; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5
check "Drei Möglichkeiten" three_options
snap 1

step "Foto aufnehmen" "Foto aufnehmen antippen und ein Bild machen. (In der Test-App: statt der Kamera die Symbolbilder, hier Frau, jung.)" "Das Bild erscheint im Kreis." Abzweigung
explain "Das Bild wird hochgeladen und erscheint im Kreis. Ins Profil eingetragen wird es erst mit Weiter, weil das Profil noch nicht existiert."
tap_el "Foto aufnehmen"; screen "Bildauswahl"; wait_el "Frau, jung" 20; tap_el "Frau, jung"; screen "Begrüßung"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
check "Zurück auf der Begrüßung" wait_el "Wie sollen wir dich nennen" 3
snap 2

step "Internetadresse: ungültig" "Kreis antippen, Von einer Internetadresse laden, abc eingeben und Laden antippen." "Der Dialog bleibt offen, unter dem Feld steht: Das ist keine gültige Internetadresse. abc steht noch im Feld." Abzweigung
explain "Die App erkennt, dass abc keine Internetadresse ist. Der Dialog bleibt offen, damit man korrigieren kann."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
type_into "https://" "abc"; tap_el "Laden"; sleep 2
check "Meldung im Dialog" wait_el "~keine gültige Internetadresse" 5
check "Dialog noch offen" wait_el "Laden" 2
snap 1

step "Internetadresse: Datei vom Gerät" "Die Eingabe durch file:///sdcard/bild.jpg ersetzen und Laden antippen." "Unter dem Feld steht: Das ist keine gültige Internetadresse. Dateien vom Gerät gehen hier nicht." Abzweigung
explain "file:// zeigt auf eine Datei im Handy, nicht ins Internet. Dafür gibt es Vorhandenes Bild wählen; hier wird es abgelehnt."
type_into "https://" "file:///sdcard/bild.jpg"; tap_el "Laden"; sleep 2
check "Meldung im Dialog" wait_el "~keine gültige Internetadresse" 5
snap 1

step "Internetadresse: kein Bild" "Eine Adresse eingeben, unter der eine Textdatei liegt, und Laden antippen." "Unter dem Feld steht: Die Adresse zeigt auf kein Bild." Abzweigung
explain "Die App lädt die Adresse, merkt aber, dass dort Text liegt statt eines Bildes."
type_into "https://" "$TEXT_URL"; tap_el "Laden"; sleep 4
check "Meldung kein Bild" wait_el "~zeigt auf kein Bild" 8
snap 1

step "Internetadresse: nichts da" "Eine Adresse eingeben, unter der nichts liegt, und Laden antippen." "Unter dem Feld steht: Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse." Abzweigung
explain "Unter der Adresse liegt nichts. Die App meldet das, statt still zu scheitern."
type_into "https://" "$MISSING_URL"; tap_el "Laden"; sleep 4
check "Meldung konnte nicht geladen werden" wait_el "~konnte nicht geladen werden" 8
snap 1

step "Internetadresse: Abbrechen" "Abbrechen antippen." "Der Dialog schließt sich, das Bild bleibt wie es war." Abzweigung
explain "Der Dialog geht zu, nichts wird geladen oder geändert."
tap_el "Abbrechen"; screen "Begrüßung"; sleep 1; hide_keyboard
check "Dialog geschlossen" gone_el "Bild-URL" 3
snap 1

step "Internetadresse: daneben tippen" "Noch einmal Von einer Internetadresse laden wählen und oben neben den Dialog tippen." "Der Dialog schließt sich, das Bild bleibt wie es war." Abzweigung
explain "Ein Tipp neben den Dialog wirkt wie Abbrechen."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
tap_at 540 250 "Schließen"; screen "Begrüßung"; sleep 1; hide_keyboard
check "Dialog geschlossen" gone_el "Laden" 3
snap 1

step "Internetadresse: Bild laden" "Von einer Internetadresse laden wählen, die Adresse eines Bildes eingeben und Laden antippen." "Der Dialog zeigt kurz, dass geladen wird, und schließt sich. Das Bild von der Adresse steht im Kreis (hier Frau, älter)." Abzweigung
explain "Die App lädt das Bild im Dialog herunter und prüft es. Erst wenn es wirklich ein Bild ist, schließt sich der Dialog und das Bild wird hochgeladen. Das zuvor gewählte Bild wird gleich wieder gelöscht, damit nichts übrig bleibt."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
type_into "https://" "$PORTRAIT_URL"; tap_el "Laden"; screen "Begrüßung"; sleep 4; hide_keyboard
check "Dialog geschlossen" gone_el "Bild-URL" 5
check "Bild im Kreis (Frau, älter: gelb)" screen_color_near 445 655 "#f1c98b"
snap 2

step "Bildauswahl abbrechen" "Kreis antippen, Vorhandenes Bild wählen und in der Bildauswahl Zurück antippen, ohne ein Bild zu wählen." "Wieder die Begrüßung, das Bild bleibt wie es war." Abzweigung
explain "Wer die Auswahl ohne Bild verlässt, ändert nichts."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Vorhandenes Bild"; screen "Bildauswahl"; wait_el "Mann, älter" 30
tap_el "Zurück"; screen "Begrüßung"; sleep 2; hide_keyboard
check "Zurück auf der Begrüßung" wait_el "Wie sollen wir dich nennen" 3
snap 1

step "Profilbild-Auswahl wegwischen" "Kreis antippen und die Auswahl nach unten wegwischen." "Die Auswahl schließt sich." Abzweigung
explain "Die Auswahl lässt sich auch nach unten wegwischen; nichts ändert sich."
tap_avatar_circle; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5
a shell input swipe 540 1620 540 2300 300; log_tap "Schließen"; screen "Begrüßung"; sleep 1; hide_keyboard
check "Auswahl geschlossen" gone_el "Foto aufnehmen" 3
snap 1

step "Vorhandenes Bild wählen" "Kreis antippen und Vorhandenes Bild wählen." "Die Bildauswahl öffnet sich. (In der Test-App: sechs Symbolbilder statt der Galerie.)"
explain "Normalerweise öffnet sich die Galerie des Handys. Die Test-App zeigt stattdessen ihre gezeichneten Testbilder."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Vorhandenes Bild"; screen "Bildauswahl"; wait_el "Mann, älter" 30
snap 1

step "Bild aussuchen" "Das Bild Frau, mittleres Alter antippen." "Das Bild erscheint im Kreis über dem Namen."
explain "Das gewählte Bild wird hochgeladen und ersetzt das vorige."
tap_el "Frau, mittleres Alter"; screen "Begrüßung"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
snap 2

step "Dasselbe Bild noch einmal" "Kreis antippen, Vorhandenes Bild wählen und noch einmal Frau, mittleres Alter antippen." "Nichts ändert sich sichtbar, das Bild bleibt im Kreis." Abzweigung
explain "Nachsalzen: dasselbe Bild ein zweites Mal. Es wird zwar erneut hochgeladen, aber die vorige Datei gleich gelöscht; nach Weiter darf es genau eine Bilddatei geben."
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Vorhandenes Bild"; screen "Bildauswahl"; wait_el "Mann, älter" 30
tap_el "Frau, mittleres Alter"; screen "Begrüßung"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
check "Bild im Kreis (Frau, mittleres Alter: lila)" screen_color_near 445 655 "#c9b6e4"
snap 2

step "Weiter" "Auf Weiter tippen (hier absichtlich zweimal schnell hintereinander)." "Willkommen bei Smile: die leere Alben-Liste mit zwei Wegen, Ich wurde eingeladen und Ich richte Smile ein."
explain "Jetzt entsteht Annas Profil: Name und Bild werden zusammen gespeichert. Der doppelte Tipp darf nichts doppelt anlegen. Die Testsuite prüft in der Datenbank, dass es genau zwei Profile gibt (Anna und Paul), genau dieses Bild gespeichert ist und keine alten Bilddateien übrig sind."
double_tap_el "Weiter"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 20
check "Genau zwei Profile (Anna und Paul), nichts doppelt" sql_is "select count(*) from public.profiles" "2"
check "Name gespeichert: Anna Berger" anna_is display_name "Anna Berger"
check "Profilbild gespeichert: Frau, mittleres Alter" anna_picture_is frau_mittel
check "Nur eine Profilbild-Datei, keine Überbleibsel" anna_picture_files_are 1
snap 1

# ---------------------------------------------------------------- Menü
step "Menü öffnen" "Oben rechts auf die drei Punkte tippen." "Das Menü zeigt Code scannen und Einstellungen."
explain "Das Menü oben rechts gibt es auf jeder Hauptseite."
tap_el "Weitere Optionen"; screen "Menü"; wait_el "Einstellungen" 5
snap 1

step "Menü schließen" "Neben das Menü tippen." "Das Menü schließt sich." Abzweigung
explain "Ein Tipp daneben schließt das Menü ohne Aktion."
tap_el "Menü schließen"; screen "Startseite (leer)"; sleep 1
check "Menü zu" gone_el "Code scannen" 3
snap 1

step "Einstellungen" "Drei Punkte, dann Einstellungen antippen." "Oben Annas Profilbild und ihr Name, darunter Smile-Name, Meine Karte, Videos senden, Tipps und Konto."
explain "Die Einstellungen laden Annas Profil vom Server. Die Testsuite prüft am Bildschirm, dass das zuletzt gewählte Bild zu sehen ist und kein altes."
tap_el "Weitere Optionen"; screen "Menü"; tap_el "Einstellungen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 10; sleep 3
check "Oben das zuletzt gewählte Bild (Frau, mittleres Alter, lila)" screen_color_near 380 470 "#c9b6e4"
snap 1

# ---------------------------------------------------------------- Einstellungen: Profil
step "Profilbild ansehen" "Auf Annas Profilbild tippen." "Das Bild erscheint groß." Abzweigung
explain "Das Bild wird groß angezeigt, nur zum Ansehen."
tap_el "Profilbild ansehen"; screen "Profilbild groß"; sleep 2
snap 1

step "Profilbild schließen" "Schließen antippen." "Wieder die Einstellungen." Abzweigung
explain "Zurück zu den Einstellungen."
tap_el "Schließen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 5
snap 1

step "Profilbild ändern: abbrechen" "Auf das Kamera-Symbol am Bild tippen und dann oben neben die Auswahl tippen." "Die Auswahl schließt sich, das Bild bleibt." Abzweigung
explain "Die Auswahl für ein neues Bild öffnet sich und wird ohne Änderung geschlossen."
tap_el "Profilbild ändern"; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5; tap_at 540 400 "Gitter"; screen "Einstellungen"; sleep 1
check "Auswahl geschlossen" gone_el "Foto aufnehmen" 3
snap 1

step "Name ändern: abbrechen" "Auf den Namen tippen und im Dialog Abbrechen wählen." "Der Dialog schließt sich, der Name bleibt Anna Berger." Abzweigung
explain "Der Dialog zum Umbenennen wird ohne Änderung geschlossen; die Testsuite prüft, dass der Name gleich bleibt."
tap_el "Anna Berger"; screen "Name ändern"; wait_el "Speichern" 5; tap_el "Abbrechen"; screen "Einstellungen"; sleep 1; hide_keyboard
check "Name unverändert" anna_is display_name "Anna Berger"
snap 1

step "Name ändern" "Auf den Namen tippen, Anna Maria Berger eingeben und Speichern antippen." "Oben steht jetzt Anna Maria Berger." Abzweigung
explain "Der neue Name wird sofort gespeichert und erscheint überall, wo Anna vorkommt."
tap_el "Anna Berger"; screen "Name ändern"; wait_el "Speichern" 5; type_into "Name" "Anna Maria Berger"; tap_el "Speichern"; screen "Einstellungen"; sleep 2; hide_keyboard
check "Name geändert" anna_is display_name "Anna Maria Berger"
snap 1

step "Name zurück ändern" "Noch einmal auf den Namen tippen, Anna Berger eingeben, Speichern." "Oben steht wieder Anna Berger." Abzweigung
explain "Die Änderung wird zurückgenommen, damit die folgenden Schritte wieder vom gleichen Stand ausgehen."
tap_el "Anna Maria Berger"; screen "Name ändern"; wait_el "Speichern" 5; type_into "Name" "Anna Berger"; tap_el "Speichern"; screen "Einstellungen"; sleep 2; hide_keyboard
check "Name wieder Anna Berger" anna_is display_name "Anna Berger"
snap 1

step "Namen unverändert speichern" "Noch einmal auf den Namen tippen und ohne Änderung Speichern antippen." "Oben steht weiter Anna Berger, nichts ändert sich." Abzweigung
explain "Nachsalzen: derselbe Name noch einmal. Es darf nichts doppelt oder kaputt gehen."
tap_el "Anna Berger"; screen "Name ändern"; wait_el "Speichern" 5; tap_el "Speichern"; screen "Einstellungen"; sleep 2; hide_keyboard
check "Name weiter Anna Berger" anna_is display_name "Anna Berger"
check "Weiter genau zwei Profile" sql_is "select count(*) from public.profiles" "2"
snap 1

# ---------------------------------------------------------------- Smile-Name
step "Smile-Namen wählen" "Smile-Namen wählen antippen." "Ein Vorschlag aus dem Namen steht schon da: @anna.berger. Das Feld hat einen grünen Rahmen und ein Häkchen, darunter grün: @anna.berger ist frei."
explain "Smile schlägt einen Namen aus Annas Namen vor und fragt beim Server nach, ob er noch frei ist. Frei wird grün angezeigt."
tap_el "Smile-Namen wählen"; screen "Smile-Name"; wait_el "Speichern" 10
check "Vorschlag anna.berger" wait_el "anna.berger" 3
check "Grün: ist frei" wait_el "~ist frei" 5
hide_keyboard; snap 1

step "Zu kurzer Name" "Den Vorschlag löschen und nur ab eingeben." "Roter Rahmen, darunter rot: Noch zu kurz. Mindestens 3 Zeichen." Abzweigung
explain "Die Regeln prüft die App selbst, ohne den Server zu fragen, und sagt genau, was nicht passt."
type_into "" "ab"; hide_keyboard
check "Rot: Noch zu kurz" wait_el "~Noch zu kurz" 5
hide_keyboard; snap 1

step "Name mit Punkt am Ende" "anna. eingeben." "Roter Rahmen, darunter rot, was nicht erlaubt ist: kein Punkt am Ende." Abzweigung
explain "Auch Zeichen an der falschen Stelle werden mit dem genauen Grund gemeldet."
type_into "" "anna."; hide_keyboard
check "Rot: Regeln erklärt" wait_el "~kein Punkt am Ende" 5
hide_keyboard; snap 1

step "Vergebener Name" "Stattdessen paul.berger eingeben (den hat Paul schon)." "Roter Rahmen, darunter rot: @paul.berger ist schon vergeben. Darunter drei freie Vorschläge, Speichern ist ausgegraut." Abzweigung
explain "Der Server meldet, dass paul.berger schon Paul gehört. Die App fragt gleich ein paar Abwandlungen nach und bietet die freien an."
type_into "" "paul.berger"; hide_keyboard
check "Rot: schon vergeben" wait_el "~ist schon vergeben" 8
check "Freie Vorschläge" wait_el "paul.berger1" 8
hide_keyboard; snap 1

step "Vorschlag antippen" "Nacheinander alle drei Vorschläge antippen: paul_berger, paul.berger2 und zuletzt paul.berger1." "Jeder Vorschlag steht nach dem Tippen im Feld und ist grün frei; am Ende paul.berger1." Abzweigung
explain "Ein Tipp übernimmt den Vorschlag ins Feld; gespeichert ist noch nichts. Alle drei Vorschläge werden geprüft, weil jeder ein eigener Knopf ist."
for s in paul_berger paul.berger2; do
  tap_el "$s"; sleep 2; hide_keyboard
  check "Grün: @$s ist frei" wait_el "~@$s ist frei" 6
  type_into "" "paul.berger"; hide_keyboard; wait_el "paul.berger1" 8
done
tap_el "paul.berger1"; sleep 2; hide_keyboard
check "Grün: @paul.berger1 ist frei" wait_el "~@paul.berger1 ist frei" 6
hide_keyboard; snap 1

step "Smile-Name: Zurück ohne Speichern" "Zurück antippen, ohne zu speichern." "Wieder die Einstellungen, dort steht weiter Smile-Namen wählen." Abzweigung
explain "Ohne Speichern bleibt alles, wie es war; die Testsuite prüft, dass kein Smile-Name gesetzt wurde."
tap_el "Zurück"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 8
check "Nichts gespeichert" anna_is handle ""
snap 1

step "Smile-Namen speichern" "Smile-Namen wählen antippen, anna.berger eingeben und Speichern antippen." "Zurück in den Einstellungen steht unter Smile-Name jetzt @anna.berger."
explain "Der Smile-Name wird gespeichert. Ab jetzt kann man Anna unter @anna.berger finden und einladen."
tap_el "Smile-Namen wählen"; screen "Smile-Name"; wait_el "Speichern" 10
type_into "" "anna.berger"; wait_el "~ist frei" 8; tap_el "Speichern"; screen "Einstellungen"
wait_el "@anna.berger" 10
check "Smile-Name gespeichert" anna_is handle anna.berger
snap 1

step "Smile-Namen noch einmal öffnen" "@anna.berger antippen, nichts ändern." "@anna.berger steht im Feld, Speichern ist ausgegraut, denn es gibt nichts zu speichern. Mit Zurück wieder in die Einstellungen." Abzweigung
explain "Nachsalzen: derselbe Smile-Name lässt sich nicht noch einmal speichern; Speichern wird erst aktiv, wenn sich etwas ändert."
tap_el "@anna.berger"; screen "Smile-Name"; wait_el "Speichern" 10; hide_keyboard
check "Speichern ausgegraut" is_disabled "Speichern"
snap 1
tap_el "Zurück"; screen "Einstellungen"; wait_el "@anna.berger" 8

step "Meine Karte" "Meine Karte antippen." "Annas Karte: Bild, Name, @anna.berger, ein QR-Code und darunter smileapp.app/@anna.berger. Unten der Knopf Meine Karte teilen."
explain "Aus dem Smile-Namen entsteht ein Link (smileapp.app/@anna.berger) und daraus der QR-Code."
tap_el "Meine Karte"; screen "Meine Karte"; wait_el "Meine Karte teilen" 10
check "Link auf der Karte" wait_el "smileapp.app/@anna.berger" 3
snap 2

step "Meine Karte teilen" "Meine Karte teilen antippen." "Das Teilen-Menü von Android zeigt den Text: Lade mich in Smile ein: https://smileapp.app/@anna.berger. (Die Kontakte darunter sind geschwärzt.)" Abzweigung
explain "Android teilt den Einladungstext mit dem Link. Im Bild sind die echten Kontakte des Testhandys geschwärzt."
tap_el "Meine Karte teilen"; screen "Teilen (Android)"; sleep 3; mask_id "android:id/resolver_list"
check "Einladungstext mit Link" wait_el "Lade mich in Smile ein" 5
snap 1

step "Teilen abbrechen" "Zurück antippen." "Wieder Annas Karte." Abzweigung
explain "Nichts wurde verschickt."
go_back; screen "Meine Karte"; wait_el "Meine Karte teilen" 5
snap 1

step "Smile-Namen entfernen" "Zurück zu den Einstellungen, @anna.berger antippen und Smile-Namen entfernen wählen." "In den Einstellungen steht wieder Smile-Namen wählen." Abzweigung
explain "Der Smile-Name wird gelöscht. Wer den alten Link hat, findet Anna nicht mehr."
tap_el "Zurück"; screen "Einstellungen"; wait_el "@anna.berger" 5; tap_el "@anna.berger"; screen "Smile-Name"; wait_el "Smile-Namen entfernen" 5; hide_keyboard
tap_el "Smile-Namen entfernen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 10
check "Smile-Name entfernt" anna_is handle ""
snap 1

step "Meine Karte ohne Smile-Namen" "Meine Karte antippen." "Die ganze Karte als Vorschau: Bild und Name, statt Smile-Name und QR-Code gestrichelte Platzhalter. Darunter @anna.berger übernehmen und Anderen Namen wählen." Abzweigung
explain "Ohne Smile-Namen gibt es keinen Link und keinen QR-Code. Die Karte zeigt Platzhalter, und Smile prüft, ob der Vorschlag @anna.berger frei ist."
tap_el "Meine Karte"; screen "Meine Karte (ohne Smile-Name)"; wait_el "~Hier erscheint dein QR-Code" 10
check "Platzhalter für den QR-Code" wait_el "~Hier erscheint dein QR-Code" 2
check "Vorschlag zum Übernehmen" wait_el "@anna.berger übernehmen" 8
snap 1

step "Karte ohne Smile-Namen: Zurück" "Zurück antippen und Meine Karte noch einmal öffnen." "Wieder die Karte mit Platzhaltern." Abzweigung
explain "Zurück und wieder hinein: die Karte sieht gleich aus."
tap_el "Zurück"; screen "Einstellungen"; wait_el "Meine Karte" 5; tap_el "Meine Karte"; screen "Meine Karte (ohne Smile-Name)"; wait_el "@anna.berger übernehmen" 10
snap 1

step "Anderen Namen wählen" "Anderen Namen wählen antippen und ohne Speichern mit Zurück wieder verlassen." "Wieder die Karte mit Platzhaltern, nichts wurde gespeichert." Abzweigung
explain "Öffnet die Auswahl des Smile-Namens; ohne Speichern ändert sich nichts."
tap_el "Anderen Namen wählen"; screen "Smile-Name"; wait_el "Speichern" 10; hide_keyboard
tap_el "Zurück"; screen "Meine Karte (ohne Smile-Name)"; wait_el "@anna.berger übernehmen" 10
check "Nichts gespeichert" anna_is handle ""
snap 1

step "Vorschlag übernehmen" "@anna.berger übernehmen antippen (hier absichtlich zweimal schnell)." "An derselben Stelle wird die Karte fertig: @anna.berger, der QR-Code und smileapp.app/@anna.berger. Keine Fehlermeldung." Abzweigung
explain "Ein Tipp speichert den freien Vorschlag. Die Karte wird an derselben Stelle fertig, mit Link und QR-Code. Der doppelte Tipp darf weder einen Fehler noch den Wechsel zur Namenswahl auslösen."
double_tap_el "@anna.berger übernehmen"; screen "Meine Karte"; wait_el "Meine Karte teilen" 10
check "Keine Namenswahl geöffnet" gone_el "Speichern" 3
check "Smile-Name gespeichert" anna_is handle anna.berger
check "QR-Code da" wait_el "smileapp.app/@anna.berger" 3
snap 2

# ---------------------------------------------------------------- Videos senden
step "Videos senden: Hoch" "Zurück zu den Einstellungen und bei Videos senden Hoch antippen." "Darunter steht: 720p, sehr scharf, rund 24 MB pro Minute Video." Abzweigung
explain "Bestimmt, wie stark Videos vor dem Senden verkleinert werden. Die Einstellung gilt nur für dieses Handy."
tap_el "Zurück"; screen "Einstellungen"; wait_el "Hoch" 8; tap_el "Hoch"; sleep 1
check "Hinweis 720p" wait_el "~720p, sehr scharf" 3
snap 1

step "Videos senden: Niedrig" "Niedrig antippen." "Darunter steht: 360p, für kleine Bildschirme, rund 6 MB pro Minute." Abzweigung
explain "Kleinste Dateien, am schnellsten gesendet."
tap_el "Niedrig"; sleep 1
check "Hinweis 360p" wait_el "~360p" 3
snap 1

step "Videos senden: Mittel" "Mittel antippen (so war es eingestellt)." "Darunter steht wieder: Genau wie WhatsApp (480p)." Abzweigung
explain "Zurück auf den Standard, damit die folgenden Kapitel vom gleichen Stand ausgehen."
tap_el "Mittel"; sleep 1
check "Hinweis 480p" wait_el "~Genau wie WhatsApp" 3
snap 1

# ---------------------------------------------------------------- Abmelden
step "Abmelden: Frage" "Nach unten wischen und Abmelden antippen." "Smile fragt: Möchtest du dich wirklich abmelden?" Abzweigung
explain "Smile fragt vorher nach, damit man sich nicht aus Versehen abmeldet."
a shell input swipe 540 1800 540 600 300; sleep 1; tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5
snap 1

step "Abmelden: Abbrechen" "Abbrechen antippen." "Die Frage verschwindet, Anna bleibt angemeldet." Abzweigung
explain "Nichts passiert, Anna bleibt angemeldet."
tap_el "Abbrechen"; screen "Einstellungen"; sleep 1
check "Noch in den Einstellungen" wait_el "Konto löschen" 3
snap 1

step "Abmelden: daneben tippen" "Noch einmal Abmelden antippen und dann neben die Frage tippen." "Die Frage verschwindet, Anna bleibt angemeldet." Abzweigung
explain "Auch ein Tipp neben die Frage bricht ab."
tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5; tap_at 540 300 "Schließen"; screen "Einstellungen"; sleep 1
check "Noch in den Einstellungen" wait_el "Konto löschen" 3
snap 1

step "Abmelden" "Abmelden antippen und in der Frage Abmelden bestätigen." "Die Anmeldung erscheint wieder." Abzweigung
explain "Die Anmeldung auf diesem Handy wird beendet. Annas Konto, Profil und Smile-Name bleiben auf dem Server."
tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5; tap_last "Abmelden"; screen "Anmeldung"; wait_el "Code anfordern" 10
check "Anmeldung sichtbar" wait_el "Code anfordern" 2
hide_keyboard; snap 1

step "Wieder anmelden" "E-Mail-Adresse eingeben, Code anfordern und den Code eingeben." "Smile öffnet direkt die Startseite. Name, Bild und Smile-Name sind noch da, die Begrüßung kommt nicht noch einmal." Abzweigung
explain "Mit neuem Code ist Anna wieder da. Weil ihr Profil schon existiert, kommt die Begrüßung nicht noch einmal."
type_into "E-Mail-Adresse" "$ANNA"; tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
type_text "$(otp_for "$ANNA")"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 20
check "Startseite ohne Begrüßung" wait_el "Willkommen bei Smile" 2
check "Smile-Name noch da" anna_is handle anna.berger
snap 2

step "Einstellungen verlassen" "Drei Punkte, Einstellungen, dann oben links Zurück antippen." "Wieder die Startseite." Abzweigung
explain "Der Pfeil oben links führt zurück zur Startseite."
tap_el "Weitere Optionen"; screen "Menü"; tap_el "Einstellungen"; screen "Einstellungen"; wait_el "Smile-Name" 10
tap_el "Zurück"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 10
check "Startseite" wait_el "Willkommen bei Smile" 2
snap 1

echo "Kapitel 1 fertig: $CH_DIR"
