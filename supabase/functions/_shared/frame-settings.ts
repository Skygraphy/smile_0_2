// A Frame's settings as it receives them -- the same shape in the answer of
// get-media-batch and in sync-fanout's push (2026-10-27: the push carries
// them along, so a change from the app shows on the Frame at once instead
// of after a whole sync).
export const FRAME_SETTING_COLUMNS =
  "display_mode, slideshow_interval_seconds, channel_switch_enabled, video_sound, max_local_cache_gb, control_level, " +
  "controls, content_mode, recent_count, play_order, end_behavior, show_new_immediately, show_clock, show_sender, " +
  "quiet_from, quiet_to, video_length, fill_mode, slow_zoom, rotate_with_device, show_captions, unlock_code_hash, new_sound, new_sound_reminder, new_hint";

// deno-lint-ignore no-explicit-any
export function frameSettings(frame: Record<string, any>) {
  return {
    display_mode: frame.display_mode,
    slideshow_interval_seconds: frame.slideshow_interval_seconds,
    channel_switch_enabled: frame.channel_switch_enabled,
    video_sound: frame.video_sound,
    max_local_cache_gb: frame.max_local_cache_gb,
    control_level: frame.control_level,
    controls: frame.controls,
    content_mode: frame.content_mode,
    recent_count: frame.recent_count,
    play_order: frame.play_order,
    end_behavior: frame.end_behavior,
    show_new_immediately: frame.show_new_immediately,
    show_clock: frame.show_clock,
    show_sender: frame.show_sender,
    quiet_from: frame.quiet_from,
    quiet_to: frame.quiet_to,
    video_length: frame.video_length,
    fill_mode: frame.fill_mode,
    slow_zoom: frame.slow_zoom,
    rotate_with_device: frame.rotate_with_device,
    show_captions: frame.show_captions,
    // Kindersperre (migrations/0089): unlocks every button on the Frame.
    unlock_code_hash: frame.unlock_code_hash ?? null,
    // Noticing new photos (migrations/0093).
    new_sound: frame.new_sound ?? true,
    new_sound_reminder: frame.new_sound_reminder ?? true,
    new_hint: frame.new_hint ?? true,
  };
}
