-- The Space owner has no way to tell which physical device a Frame record
-- is actually bound to -- the record is created first (named like "Küche")
-- and any hardware can later claim it via the pairing code, so nothing
-- about the row itself ever named the device. Store the Android model
-- string the Frame itself reports on every heartbeat, purely informational
-- (like battery_level/current_app_version), so frame_settings_screen.dart
-- can show it.

alter table frames add column device_model text;
