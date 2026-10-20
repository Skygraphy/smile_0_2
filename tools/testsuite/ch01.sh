#!/usr/bin/env bash
# Kapitel 1: Erster Start. Anna Berger meldet sich zum ersten Mal an,
# wählt Namen, Profilbild und Smile-Namen, öffnet ihre Karte, und jede
# Abzweigung auf diesen Seiten wird mit durchgespielt (und wieder
# zurückgenommen, wo sie etwas ändert).
# Startzustand: Testprojekt leer (reset.sh), Test-App frisch.
set -uo pipefail
cd "$(dirname "$0")"
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
clear_field() { tap_el "class:android.widget.EditText"; a shell input keyevent KEYCODE_MOVE_END; for _ in $(seq 1 30); do a shell input keyevent 67; done; }
# A picture on the internet for the "Internetadresse" branch: one of the
# portraits, put into the project's public avatars bucket.
PORTRAIT_URL="$SUPABASE_URL/storage/v1/object/public/avatars/testsuite/frau_alt.png"
put_portrait() {
  curl -s -o /dev/null -X POST "$SUPABASE_URL/storage/v1/object/avatars/testsuite/frau_alt.png" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" -H "Content-Type: image/png" -H "x-upsert: true" \
    --data-binary "@$(cygpath -w "$TESTSUITE_DIR/fixtures/profiles/frau_alt.png")"
}

# Startzustand
./reset.sh >/dev/null
person paul.berger@example.com "Paul Berger" paul.berger   # hat den Smile-Namen paul.berger schon
put_portrait
clear_app; tips_off; push_fixtures; demo_mode

begin_chapter ch01 "Erster Start" "Anna installiert Smile, meldet sich mit ihrer E-Mail-Adresse an, gibt sich einen Namen und ein Profilbild, wählt ihren Smile-Namen und öffnet ihre Karte. Jede Abzweigung auf diesen Seiten wird mitgeprüft: falscher Code, andere Adresse, leerer Name, alle drei Wege zum Profilbild, Namen ändern, Smile-Namen entfernen, Videos senden, Abmelden."

# ---------------------------------------------------------------- Anmeldung
step "Smile öffnen" "Smile zum ersten Mal öffnen." "Die Anmeldung erscheint: Smile-Logo, Feld für die E-Mail-Adresse, Code anfordern und Dieses Gerät als Frame verwenden."
start_app; screen "Anmeldung"; wait_el "Code anfordern" 20
check "Anmeldung sichtbar" wait_el "Code anfordern" 1
snap 1

step "Code anfordern ohne Adresse" "Code anfordern antippen, ohne etwas einzugeben." "Es passiert nichts, Smile bleibt auf der Anmeldung." Abzweigung
tap_el "Code anfordern"; sleep 2
check "Noch auf der Anmeldung" wait_el "Melde dich mit deiner E-Mail-Adresse an" 2
snap 1

step "E-Mail-Adresse eingeben" "Ins Feld tippen und anna.berger@example.com eingeben." "Die Adresse steht im Feld."
tap_el "class:android.widget.EditText"; type_text "$ANNA"; hide_keyboard
snap 1

step "Code anfordern" "Auf Code anfordern tippen." "Smile meldet, dass ein Code an die Adresse gesendet wurde, und zeigt sechs Kästchen für den Code."
tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
check "Code-Eingabe sichtbar" wait_el "Wir haben einen Code" 1
hide_keyboard; snap 1

step "Andere E-Mail-Adresse verwenden" "Andere E-Mail-Adresse verwenden antippen." "Zurück auf der Anmeldung, die Adresse steht noch im Feld und kann geändert werden." Abzweigung
tap_el "Andere E-Mail-Adresse"; screen "Anmeldung"; wait_el "Code anfordern" 10
check "Adresse noch im Feld" wait_el "$ANNA" 2
hide_keyboard; snap 1

step "Code noch einmal anfordern" "Code anfordern antippen." "Wieder die Code-Eingabe mit sechs Kästchen."
tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
hide_keyboard; snap 1

step "Falscher Code" "000000 eingeben." "Eine Meldung erscheint: Der Code stimmt nicht oder ist abgelaufen."  Abzweigung
tap_code_boxes; type_text "000000"; sleep 3
check "Meldung Code stimmt nicht sichtbar" wait_el "Der Code stimmt nicht" 5
snap 1

step "Bestätigen antippen" "Mit dem falschen Code noch einmal Bestätigen antippen." "Wieder die Meldung: Der Code stimmt nicht oder ist abgelaufen." Abzweigung
hide_keyboard; tap_el "Bestätigen"; sleep 3
check "Meldung Code stimmt nicht sichtbar" wait_el "Der Code stimmt nicht" 5
snap 1

step "Code eingeben" "Die Kästchen leeren und den richtigen 6-stelligen Code aus der E-Mail eingeben." "Smile fragt: Wie sollen wir dich nennen? Darunter ein Kreis mit Fragezeichen und das Namensfeld."
tap_code_boxes; for _ in 1 2 3 4 5 6; do a shell input keyevent 67; done; type_text "$(otp_for "$ANNA")"; screen "Begrüßung"; wait_el "Wie sollen wir dich nennen" 20
check "Begrüßung sichtbar" wait_el "Wie sollen wir dich nennen" 1
hide_keyboard; snap 1

# ---------------------------------------------------------------- Begrüßung
step "Weiter ohne Namen" "Gleich Weiter antippen, ohne einen Namen einzugeben." "Eine Meldung erscheint: Bitte gib deinen Namen ein." Abzweigung
tap_el "Weiter"; sleep 2; hide_keyboard
check "Meldung Bitte gib deinen Namen ein" wait_el "Bitte gib deinen Namen ein" 3
snap 1

step "Namen eingeben" "Anna Berger ins Namensfeld schreiben." "Im Kreis erscheinen sofort die Anfangsbuchstaben AB."
tap_el "class:android.widget.EditText"; type_text "Anna Berger"; hide_keyboard
check "Anfangsbuchstaben AB" wait_el "AB" 3
snap 1

step "Profilbild: Auswahl" "Auf den Kreis mit dem Kamera-Symbol tippen." "Drei Möglichkeiten: Foto aufnehmen, Vorhandenes Bild wählen, Von einer Internetadresse laden."
tap_avatar_circle; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5
check "Drei Möglichkeiten" three_options
snap 1

step "Foto aufnehmen" "Foto aufnehmen antippen und ein Bild machen. (In der Test-App: statt der Kamera die Symbolbilder, hier Frau, jung.)" "Das Bild erscheint im Kreis." Abzweigung
tap_el "Foto aufnehmen"; screen "Bildauswahl"; wait_el "Frau, jung" 20; tap_el "Frau, jung"; screen "Begrüßung"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
check "Zurück auf der Begrüßung" wait_el "Wie sollen wir dich nennen" 3
snap 2

step "Internetadresse: ungültig" "Kreis antippen, Von einer Internetadresse laden, abc eingeben und Laden antippen." "Eine Meldung erscheint: Das ist keine gültige Internetadresse." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
tap_el "class:android.widget.EditText"; type_text "abc"; tap_el "Laden"; screen "Begrüßung"; sleep 2; hide_keyboard
check "Meldung keine gültige Internetadresse" wait_el "Das ist keine gültige Internetadresse" 5
snap 1

step "Internetadresse: Datei vom Gerät" "Noch einmal Von einer Internetadresse laden wählen, file:///sdcard/bild.jpg eingeben und Laden antippen." "Eine Meldung erscheint: Das ist keine gültige Internetadresse. Dateien vom Gerät gehen hier nicht." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
tap_el "class:android.widget.EditText"; type_text "file:///sdcard/bild.jpg"; tap_el "Laden"; screen "Begrüßung"; sleep 2; hide_keyboard
check "Meldung keine gültige Internetadresse" wait_el "~keine gültige Internetadresse" 5
snap 1

step "Internetadresse: Abbrechen" "Noch einmal Von einer Internetadresse laden wählen und Abbrechen antippen." "Der Dialog schließt sich, das Bild bleibt wie es war." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
tap_el "Abbrechen"; screen "Begrüßung"; sleep 1; hide_keyboard
check "Dialog geschlossen" gone_el "Bild-URL" 3
snap 1

step "Internetadresse: Bild laden" "Von einer Internetadresse laden wählen, die Adresse eines Bildes eingeben und Laden antippen." "Das Bild von der Adresse erscheint im Kreis (hier Frau, älter)." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Von einer Internetadresse"; screen "Bild-URL"; wait_el "Laden" 5
tap_el "class:android.widget.EditText"; type_text "$PORTRAIT_URL"; tap_el "Laden"; screen "Begrüßung"; sleep 4; hide_keyboard
check "Kein Fehler" gone_el "konnte nicht" 2
snap 2

step "Bildauswahl abbrechen" "Kreis antippen, Vorhandenes Bild wählen und in der Bildauswahl Zurück antippen, ohne ein Bild zu wählen." "Wieder die Begrüßung, das Bild bleibt wie es war." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Vorhandenes Bild"; screen "Bildauswahl"; wait_el "Mann, älter" 30
tap_el "Zurück"; screen "Begrüßung"; sleep 2; hide_keyboard
check "Zurück auf der Begrüßung" wait_el "Wie sollen wir dich nennen" 3
snap 1

step "Profilbild-Auswahl wegwischen" "Kreis antippen und die Auswahl nach unten wegwischen." "Die Auswahl schließt sich." Abzweigung
tap_avatar_circle; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5
a shell input swipe 540 1620 540 2300 300; log_tap "Schließen"; screen "Begrüßung"; sleep 1; hide_keyboard
check "Auswahl geschlossen" gone_el "Foto aufnehmen" 3
snap 1

step "Vorhandenes Bild wählen" "Kreis antippen und Vorhandenes Bild wählen." "Die Bildauswahl öffnet sich. (In der Test-App: sechs Symbolbilder statt der Galerie.)"
tap_avatar_circle; screen "Profilbild-Auswahl"; tap_el "Vorhandenes Bild"; screen "Bildauswahl"; wait_el "Mann, älter" 30
snap 1

step "Bild aussuchen" "Das Bild Frau, mittleres Alter antippen." "Das Bild erscheint im Kreis über dem Namen."
tap_el "Frau, mittleres Alter"; screen "Begrüßung"; gone_el "Testporträts" 10; sleep 2; hide_keyboard
snap 2

step "Weiter" "Auf Weiter tippen." "Willkommen bei Smile: die leere Alben-Liste mit zwei Wegen, Ich wurde eingeladen und Ich richte Smile ein."
tap_el "Weiter"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 20
check "Name gespeichert: Anna Berger" anna_is display_name "Anna Berger"
check "Profilbild gespeichert: Frau, mittleres Alter" anna_picture_is frau_mittel
check "Nur eine Profilbild-Datei, keine Überbleibsel" anna_picture_files_are 1
snap 1

# ---------------------------------------------------------------- Menü
step "Menü öffnen" "Oben rechts auf die drei Punkte tippen." "Das Menü zeigt Code scannen und Einstellungen."
tap_el "Weitere Optionen"; screen "Menü"; wait_el "Einstellungen" 5
snap 1

step "Menü schließen" "Neben das Menü tippen." "Das Menü schließt sich." Abzweigung
tap_el "Menü schließen"; screen "Startseite (leer)"; sleep 1
check "Menü zu" gone_el "Code scannen" 3
snap 1

step "Einstellungen" "Drei Punkte, dann Einstellungen antippen." "Oben Annas Profilbild und ihr Name, darunter Smile-Name, Meine Karte, Videos senden, Tipps und Konto."
tap_el "Weitere Optionen"; screen "Menü"; tap_el "Einstellungen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 10; sleep 3
check "Oben das zuletzt gewählte Bild (Frau, mittleres Alter, lila)" screen_color_near 380 470 "#c9b6e4"
snap 1

# ---------------------------------------------------------------- Einstellungen: Profil
step "Profilbild ansehen" "Auf Annas Profilbild tippen." "Das Bild erscheint groß." Abzweigung
tap_el "Profilbild ansehen"; screen "Profilbild groß"; sleep 2
snap 1

step "Profilbild schließen" "Schließen antippen." "Wieder die Einstellungen." Abzweigung
tap_el "Schließen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 5
snap 1

step "Profilbild ändern: abbrechen" "Auf das Kamera-Symbol am Bild tippen und dann oben neben die Auswahl tippen." "Die Auswahl schließt sich, das Bild bleibt." Abzweigung
tap_el "Profilbild ändern"; screen "Profilbild-Auswahl"; wait_el "Vorhandenes Bild" 5; tap_at 540 400 "Gitter"; screen "Einstellungen"; sleep 1
check "Auswahl geschlossen" gone_el "Foto aufnehmen" 3
snap 1

step "Name ändern: abbrechen" "Auf den Namen tippen und im Dialog Abbrechen wählen." "Der Dialog schließt sich, der Name bleibt Anna Berger." Abzweigung
tap_el "Anna Berger"; screen "Name ändern"; wait_el "Speichern" 5; tap_el "Abbrechen"; screen "Einstellungen"; sleep 1; hide_keyboard
check "Name unverändert" anna_is display_name "Anna Berger"
snap 1

step "Name ändern" "Auf den Namen tippen, Anna Maria Berger eingeben und Speichern antippen." "Oben steht jetzt Anna Maria Berger." Abzweigung
tap_el "Anna Berger"; screen "Name ändern"; wait_el "Speichern" 5; clear_field; type_text "Anna Maria Berger"; tap_el "Speichern"; screen "Einstellungen"; sleep 2; hide_keyboard
check "Name geändert" anna_is display_name "Anna Maria Berger"
snap 1

step "Name zurück ändern" "Noch einmal auf den Namen tippen, Anna Berger eingeben, Speichern." "Oben steht wieder Anna Berger." Abzweigung
tap_el "Anna Maria Berger"; screen "Name ändern"; wait_el "Speichern" 5; clear_field; type_text "Anna Berger"; tap_el "Speichern"; screen "Einstellungen"; sleep 2; hide_keyboard
check "Name wieder Anna Berger" anna_is display_name "Anna Berger"
snap 1

# ---------------------------------------------------------------- Smile-Name
step "Smile-Namen wählen" "Smile-Namen wählen antippen." "Ein Vorschlag aus der E-Mail-Adresse steht schon da: @anna.berger, darunter Frei."
tap_el "Smile-Namen wählen"; screen "Smile-Name"; wait_el "Speichern" 10
check "Vorschlag anna.berger" wait_el "anna.berger" 3
check "Frei" wait_el "Frei" 5
hide_keyboard; snap 1

step "Zu kurzer Name" "Den Vorschlag löschen und nur ab eingeben." "Darunter steht: Nur a–z, 0–9, Punkt und Unterstrich, 3 bis 24 Zeichen." Abzweigung
clear_field; type_text "ab"; hide_keyboard
check "Hinweis zu den Regeln" wait_el "Nur a–z" 5
hide_keyboard; snap 1

step "Vergebener Name" "Stattdessen paul.berger eingeben (den hat Paul schon)." "Darunter steht: Schon vergeben. Speichern ist ausgegraut." Abzweigung
clear_field; type_text "paul.berger"; hide_keyboard
check "Schon vergeben" wait_el "Schon vergeben" 8
hide_keyboard; snap 1

step "Smile-Name: Zurück ohne Speichern" "Zurück antippen, ohne zu speichern." "Wieder die Einstellungen, dort steht weiter Smile-Namen wählen." Abzweigung
tap_el "Zurück"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 8
check "Nichts gespeichert" anna_is handle ""
snap 1

step "Smile-Namen speichern" "Smile-Namen wählen antippen, anna.berger eingeben und Speichern antippen." "Zurück in den Einstellungen steht unter Smile-Name jetzt @anna.berger."
tap_el "Smile-Namen wählen"; screen "Smile-Name"; wait_el "Speichern" 10
clear_field; type_text "anna.berger"; wait_el "Frei" 8; tap_el "Speichern"; screen "Einstellungen"
wait_el "@anna.berger" 10
check "Smile-Name gespeichert" anna_is handle anna.berger
snap 1

step "Meine Karte" "Meine Karte antippen." "Annas Karte: Bild, Name, @anna.berger, ein QR-Code und darunter smileapp.app/@anna.berger. Unten der Knopf Meine Karte teilen."
tap_el "Meine Karte"; screen "Meine Karte"; wait_el "Meine Karte teilen" 10
check "Link auf der Karte" wait_el "smileapp.app/@anna.berger" 3
snap 2

step "Meine Karte teilen" "Meine Karte teilen antippen." "Das Teilen-Menü von Android zeigt den Text: Lade mich in Smile ein: https://smileapp.app/@anna.berger. (Die Kontakte darunter sind geschwärzt.)" Abzweigung
tap_el "Meine Karte teilen"; screen "Teilen (Android)"; sleep 3; mask_id "android:id/resolver_list"
check "Einladungstext mit Link" wait_el "Lade mich in Smile ein" 5
snap 1

step "Teilen abbrechen" "Zurück antippen." "Wieder Annas Karte." Abzweigung
go_back; screen "Meine Karte"; wait_el "Meine Karte teilen" 5
snap 1

step "Smile-Namen entfernen" "Zurück zu den Einstellungen, @anna.berger antippen und Smile-Namen entfernen wählen." "In den Einstellungen steht wieder Smile-Namen wählen." Abzweigung
tap_el "Zurück"; screen "Einstellungen"; wait_el "@anna.berger" 5; tap_el "@anna.berger"; screen "Smile-Name"; wait_el "Smile-Namen entfernen" 5; hide_keyboard
tap_el "Smile-Namen entfernen"; screen "Einstellungen"; wait_el "Smile-Namen wählen" 10
check "Smile-Name entfernt" anna_is handle ""
snap 1

step "Meine Karte ohne Smile-Namen" "Meine Karte antippen." "Statt der Karte steht: Wähle zuerst einen Smile-Namen. Darunter der Knopf Smile-Namen wählen." Abzweigung
tap_el "Meine Karte"; screen "Meine Karte (ohne Smile-Name)"; wait_el "Wähle zuerst einen Smile-Namen" 10
snap 1

step "Karte ohne Smile-Namen: Zurück" "Zurück antippen und Meine Karte noch einmal öffnen." "Wieder: Wähle zuerst einen Smile-Namen." Abzweigung
tap_el "Zurück"; screen "Einstellungen"; wait_el "Meine Karte" 5; tap_el "Meine Karte"; screen "Meine Karte (ohne Smile-Name)"; wait_el "Wähle zuerst einen Smile-Namen" 10
snap 1

step "Smile-Namen von der Karte aus wählen" "Smile-Namen wählen antippen, anna.berger übernehmen und Speichern." "Die Karte mit QR-Code erscheint." Abzweigung
tap_last "Smile-Namen wählen"; screen "Smile-Name"; wait_el "Frei" 10; tap_el "Speichern"; screen "Meine Karte"; sleep 3
check "Smile-Name wieder da" anna_is handle anna.berger
snap 2

# ---------------------------------------------------------------- Videos senden
step "Videos senden: Hoch" "Zurück zu den Einstellungen und bei Videos senden Hoch antippen." "Darunter steht: 720p, sehr scharf, rund 24 MB pro Minute Video." Abzweigung
tap_el "Zurück"; screen "Einstellungen"; wait_el "Hoch" 8; tap_el "Hoch"; sleep 1
check "Hinweis 720p" wait_el "~720p, sehr scharf" 3
snap 1

step "Videos senden: Niedrig" "Niedrig antippen." "Darunter steht: 360p, für kleine Bildschirme, rund 6 MB pro Minute." Abzweigung
tap_el "Niedrig"; sleep 1
check "Hinweis 360p" wait_el "~360p" 3
snap 1

step "Videos senden: Mittel" "Mittel antippen (so war es eingestellt)." "Darunter steht wieder: Genau wie WhatsApp (480p)." Abzweigung
tap_el "Mittel"; sleep 1
check "Hinweis 480p" wait_el "~Genau wie WhatsApp" 3
snap 1

# ---------------------------------------------------------------- Abmelden
step "Abmelden: Frage" "Nach unten wischen und Abmelden antippen." "Smile fragt: Möchtest du dich wirklich abmelden?" Abzweigung
a shell input swipe 540 1800 540 600 300; sleep 1; tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5
snap 1

step "Abmelden: Abbrechen" "Abbrechen antippen." "Die Frage verschwindet, Anna bleibt angemeldet." Abzweigung
tap_el "Abbrechen"; screen "Einstellungen"; sleep 1
check "Noch in den Einstellungen" wait_el "Konto löschen" 3
snap 1

step "Abmelden: daneben tippen" "Noch einmal Abmelden antippen und dann neben die Frage tippen." "Die Frage verschwindet, Anna bleibt angemeldet." Abzweigung
tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5; tap_at 540 300 "Schließen"; screen "Einstellungen"; sleep 1
check "Noch in den Einstellungen" wait_el "Konto löschen" 3
snap 1

step "Abmelden" "Abmelden antippen und in der Frage Abmelden bestätigen." "Die Anmeldung erscheint wieder." Abzweigung
tap_el "Abmelden"; screen "Abmelden-Frage"; wait_el "Möchtest du dich wirklich abmelden" 5; tap_last "Abmelden"; screen "Anmeldung"; wait_el "Code anfordern" 10
check "Anmeldung sichtbar" wait_el "Code anfordern" 2
hide_keyboard; snap 1

step "Wieder anmelden" "E-Mail-Adresse eingeben, Code anfordern und den Code eingeben." "Smile öffnet direkt die Startseite. Name, Bild und Smile-Name sind noch da, die Begrüßung kommt nicht noch einmal." Abzweigung
tap_el "class:android.widget.EditText"; clear_field; type_text "$ANNA"; tap_el "Code anfordern"; screen "Code-Eingabe"; wait_el "Bestätigen" 10
type_text "$(otp_for "$ANNA")"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 20
check "Startseite ohne Begrüßung" wait_el "Willkommen bei Smile" 2
check "Smile-Name noch da" anna_is handle anna.berger
snap 2

step "Einstellungen verlassen" "Drei Punkte, Einstellungen, dann oben links Zurück antippen." "Wieder die Startseite." Abzweigung
tap_el "Weitere Optionen"; screen "Menü"; tap_el "Einstellungen"; screen "Einstellungen"; wait_el "Smile-Name" 10
tap_el "Zurück"; screen "Startseite (leer)"; wait_el "Willkommen bei Smile" 10
check "Startseite" wait_el "Willkommen bei Smile" 2
snap 1

echo "Kapitel 1 fertig: $CH_DIR"
