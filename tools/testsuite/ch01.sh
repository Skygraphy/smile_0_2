#!/usr/bin/env bash
# Kapitel 1: Erster Start. Anna Berger meldet sich zum ersten Mal an,
# wählt Namen, Profilbild und Smile-Namen und öffnet ihre Karte.
# Startzustand: Testprojekt leer (reset.sh), Test-App frisch.
set -uo pipefail
cd "$(dirname "$0")"
source ./env.sh; source ./dev.sh; source ./chapter.sh
DEV="${DEV_S26:?DEV_S26 setzen, z.B. 192.168.0.107:40549}"
ANNA=anna.berger@example.com
person() { deno run --node-modules-dir=none --allow-net --allow-env "$(cygpath -w "$TESTSUITE_DIR/person.ts")" "$@" >/dev/null; }
three_options() { wait_el "Foto aufnehmen" 1 && wait_el "Von einer Internetadresse" 1; }
anna_is() { [ "$(anna_profile "$1")" = "$2" ]; }
anna_profile() { sql_value "select coalesce(p.$1::text,'') from public.profiles p join auth.users u on u.id=p.user_id where u.email='$ANNA'"; }

# Startzustand
./reset.sh >/dev/null
person paul.berger@example.com "Paul Berger" paul.berger   # hat den Smile-Namen paul.berger schon
clear_app; tips_off; push_fixtures; demo_mode

begin_chapter ch01 "Erster Start" "Anna installiert Smile, meldet sich mit ihrer E-Mail-Adresse an, gibt sich einen Namen und ein Profilbild, wählt ihren Smile-Namen und öffnet ihre Karte mit QR-Code."

step "Smile öffnen" "Smile zum ersten Mal öffnen." "Die Anmeldung erscheint: Smile-Logo, Feld für die E-Mail-Adresse, Code anfordern und Dieses Gerät als Frame verwenden."
start_app; wait_el "Code anfordern" 20
check "Anmeldung sichtbar" wait_el "Code anfordern" 1
snap 1

step "E-Mail-Adresse eingeben" "Ins Feld tippen und anna.berger@example.com eingeben." "Die Adresse steht im Feld."
tap_el "class:android.widget.EditText"; type_text "$ANNA"; hide_keyboard
snap 1

step "Code anfordern" "Auf Code anfordern tippen." "Smile meldet, dass ein Code an die Adresse gesendet wurde, und zeigt sechs Kästchen für den Code."
tap_el "Code anfordern"; wait_el "Bestätigen" 10
check "Code-Eingabe sichtbar" wait_el "Wir haben einen Code" 1
hide_keyboard; snap 1

step "Code eingeben" "Den 6-stelligen Code aus der E-Mail eingeben." "Smile fragt: Wie sollen wir dich nennen? Darunter ein Kreis mit Fragezeichen und das Namensfeld."
type_text "$(otp_for "$ANNA")"; wait_el "Wie sollen wir dich nennen" 20
check "Begrüßung sichtbar" wait_el "Wie sollen wir dich nennen" 1
hide_keyboard; snap 1

step "Namen eingeben" "Anna Berger ins Namensfeld schreiben." "Im Kreis erscheinen sofort die Anfangsbuchstaben AB."
tap_el "class:android.widget.EditText"; type_text "Anna Berger"; hide_keyboard
check "Anfangsbuchstaben AB" wait_el "AB" 3
snap 1

step "Profilbild: Auswahl" "Auf den Kreis mit dem Kamera-Symbol tippen." "Drei Möglichkeiten: Foto aufnehmen, Vorhandenes Bild wählen, Von einer Internetadresse laden."
tap_el "AB"; wait_el "Vorhandenes Bild" 5
check "Drei Möglichkeiten" three_options
snap 1

step "Vorhandenes Bild wählen" "Vorhandenes Bild wählen antippen." "Die Bildauswahl öffnet sich. (In der Test-App: sechs Symbolbilder statt der Galerie.)"
tap_el "Vorhandenes Bild"; wait_el "Mann, älter" 30
snap 1

step "Bild aussuchen" "Das Bild Frau, mittleres Alter antippen." "Das Bild erscheint im Kreis über dem Namen."
tap_el "Frau, mittleres Alter"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
snap 3

step "Weiter" "Auf Weiter tippen." "Willkommen bei Smile: die leere Alben-Liste mit zwei Wegen, Ich wurde eingeladen und Ich richte Smile ein."
tap_el "Weiter"; wait_el "Willkommen bei Smile" 20
check "Name gespeichert: Anna Berger" anna_is display_name "Anna Berger"
check "Profilbild gespeichert" anna_is avatar_path "users/$(sql_value "select id from auth.users where email='$ANNA'")"
snap 1

step "Menü öffnen" "Oben rechts auf die drei Punkte tippen." "Das Menü zeigt Code scannen und Einstellungen."
tap_el "Weitere Optionen"; wait_el "Einstellungen" 5
snap 1

step "Einstellungen" "Einstellungen antippen." "Oben Annas Profilbild und ihr Name, darunter Smile-Name mit Smile-Namen wählen und Meine Karte."
tap_el "Einstellungen"; wait_el "Smile-Namen wählen" 10
snap 3

step "Smile-Namen wählen" "Smile-Namen wählen antippen." "Ein Vorschlag aus der E-Mail-Adresse steht schon da: @anna.berger, darunter Frei."
tap_el "Smile-Namen wählen"; wait_el "Speichern" 10
check "Vorschlag anna.berger" wait_el "anna.berger" 3
check "Frei" wait_el "Frei" 5
hide_keyboard; snap 1

step "Zu kurzer Name" "Den Vorschlag löschen und nur ab eingeben." "Darunter steht: Nur a–z, 0–9, Punkt und Unterstrich, 3 bis 24 Zeichen."
tap_el "class:android.widget.EditText"; for _ in $(seq 1 15); do a shell input keyevent 67; done; type_text "ab"; hide_keyboard
check "Hinweis zu den Regeln" wait_el "Nur a–z" 5
hide_keyboard; snap 1

step "Vergebener Name" "Stattdessen paul.berger eingeben (den hat Paul schon)." "Darunter steht: Schon vergeben."
tap_el "class:android.widget.EditText"; for _ in 1 2 3; do a shell input keyevent 67; done; type_text "paul.berger"; hide_keyboard
check "Schon vergeben" wait_el "Schon vergeben" 8
hide_keyboard; snap 1

step "Smile-Namen speichern" "anna.berger eingeben und Speichern antippen." "Zurück in den Einstellungen steht unter Smile-Name jetzt @anna.berger."
tap_el "class:android.widget.EditText"; for _ in $(seq 1 12); do a shell input keyevent 67; done; type_text "anna.berger"; wait_el "Frei" 8; tap_el "Speichern"
wait_el "@anna.berger" 10
check "Smile-Name gespeichert" anna_is handle anna.berger
snap 1

step "Meine Karte" "Meine Karte antippen." "Annas Karte: Bild, Name, @anna.berger, ein QR-Code und darunter smileapp.app/@anna.berger. Unten der Knopf Meine Karte teilen."
tap_el "Meine Karte"; wait_el "Meine Karte teilen" 10
check "Link auf der Karte" wait_el "smileapp.app/@anna.berger" 3
snap 2

echo "Kapitel 1 fertig: $CH_DIR"
