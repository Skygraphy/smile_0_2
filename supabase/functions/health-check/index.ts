// Monitoring of live operation, stage 1 (migrations/0065, decided
// 2026-10-07). Runs hourly (cron -> outbox -> here) and looks for problems
// nobody would otherwise notice:
//   - uploads stuck in processing for over an hour
//   - the media-processing service (AWS App Runner) not answering
//   - background jobs (outbox) stuck or failing
//   - push notifications broken (no FCM access token)
//   - a Frame offline for over 24 hours (-> also its Space's managers)
//   - stored media growing past a warning size
// Each problem is pushed once when it starts, reminded at most daily while
// it lasts, and announced as solved when it is gone (health_alerts).
//
// Called only by the database; authenticated by the shared secret.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { checkPushAccess } from "../_shared/fcm.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import type { Notice, PushTexts } from "../_shared/push-texts.ts";
import { spaceManagerIds } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncSecret = Deno.env.get("SYNC_FANOUT_SECRET") ?? "";
const processingServiceUrl = Deno.env.get("MEDIA_PROCESSING_SERVICE_URL");
const storageWarnGb = Number(Deno.env.get("HEALTH_STORAGE_WARN_GB") ?? "5");

const HOUR = 3600 * 1000;
const REMIND_AFTER = 24 * HOUR;
const FRAME_OFFLINE_AFTER = 24 * HOUR;

/** A text from the push catalog, written per recipient language (2026-11-10). */
interface CatalogNotice {
  key: string;
  params: Record<string, unknown>;
}

interface Problem {
  title: string;
  body: string;
  recipients: string[];
  data: Record<string, string>;
  solvedTitle: string;
  solvedBody: string;
  // For people who aren't Ernst (a Space's managers): their language.
  notice?: CatalogNotice;
  solvedNotice?: CatalogNotice;
}

function localized(n: CatalogNotice) {
  // deno-lint-ignore no-explicit-any
  return (t: PushTexts) => (t as any)[n.key](n.params) as Notice;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!syncSecret || req.headers.get("x-sync-secret") !== syncSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const now = Date.now();
  const { data: opsRows } = await supabaseAdmin.from("ops_alert_recipients").select("user_id");
  const ops = (opsRows ?? []).map((r) => r.user_id as string);
  const problems = new Map<string, Problem>();
  const opsProblem = (key: string, title: string, body: string, solvedBody: string) =>
    problems.set(key, {
      title,
      body,
      recipients: ops,
      data: { type: "health_alert" },
      solvedTitle: "Wieder in Ordnung",
      solvedBody,
    });

  // 1. Uploads stuck in processing
  const { count: stuck } = await supabaseAdmin
    .from("media_items")
    .select("id", { count: "exact", head: true })
    .in("processing_status", ["uploaded", "processing"])
    .lt("created_at", new Date(now - HOUR).toISOString());
  if ((stuck ?? 0) > 0) {
    opsProblem(
      "media_stuck",
      "Uploads hängen",
      `${stuck} Foto(s)/Video(s) hängen seit über einer Stunde in der Verarbeitung.`,
      "Es hängen keine Uploads mehr in der Verarbeitung.",
    );
  }

  // 2. Media-processing service reachable
  if (processingServiceUrl) {
    let ok = false;
    try {
      const res = await fetch(new URL(processingServiceUrl).origin + "/health", { signal: AbortSignal.timeout(15_000) });
      ok = res.ok;
      await res.body?.cancel();
    } catch {
      ok = false;
    }
    if (!ok) {
      opsProblem(
        "processing_service",
        "Verarbeitung nicht erreichbar",
        "Der Verarbeitungsdienst für Fotos und Videos (AWS) antwortet nicht. Neue Uploads bleiben hängen.",
        "Der Verarbeitungsdienst für Fotos und Videos antwortet wieder.",
      );
    }
  }

  // 3. Background jobs: normally done within a minute
  const { data: openCalls } = await supabaseAdmin
    .from("internal_calls")
    .select("fn")
    .is("done_at", null)
    .lt("created_at", new Date(now - 15 * 60 * 1000).toISOString())
    .limit(500);
  if ((openCalls ?? []).length > 0) {
    const fns = [...new Set((openCalls ?? []).map((c) => c.fn as string))].join(", ");
    opsProblem(
      "outbox",
      "Hintergrund-Aufträge hängen",
      `${(openCalls ?? []).length} Hintergrund-Auftrag/-Aufträge seit über 15 Minuten nicht erledigt (${fns}). Benachrichtigungen oder Aufräumen können ausbleiben.`,
      "Alle Hintergrund-Aufträge sind wieder erledigt.",
    );
  }

  // 4. Push notifications
  try {
    await checkPushAccess();
  } catch (err) {
    opsProblem(
      "push_access",
      "Push-Nachrichten gestört",
      `Der Zugang zu Firebase für Push-Nachrichten funktioniert nicht (${String(err).slice(0, 120)}). Niemand bekommt Benachrichtigungen.`,
      "Push-Nachrichten funktionieren wieder.",
    );
  }

  // 5. Frames offline for over 24 hours -> the Space's managers too
  const { data: frames } = await supabaseAdmin
    .from("frames")
    .select("id, name, space_id, last_seen_at, created_at, spaces(name, deleted_at)")
    .eq("lifecycle_state", "active");
  for (const f of frames ?? []) {
    // deno-lint-ignore no-explicit-any
    const space = f.spaces as any;
    if (!space || space.deleted_at) continue;
    const lastSeen = new Date((f.last_seen_at ?? f.created_at) as string).getTime();
    if (now - lastSeen < FRAME_OFFLINE_AFTER) continue;
    const hours = Math.floor((now - lastSeen) / HOUR);
    const managers = await spaceManagerIds(supabaseAdmin, f.space_id as string);
    problems.set(`frame_offline:${f.id}`, {
      title: "Frame offline",
      body: `Der Frame ${f.name} in ${space.name} meldet sich seit ${hours} Stunden nicht (WLAN, Strom oder Tablet aus?).`,
      recipients: [...new Set([...managers, ...ops])],
      data: { type: "frame_changed", space_id: f.space_id as string, space_name: space.name as string, frame_name: f.name as string },
      solvedTitle: "Frame wieder online",
      solvedBody: `Der Frame ${f.name} in ${space.name} ist wieder online.`,
      notice: { key: "frameOffline", params: { frame: f.name, space: space.name, hours } },
      solvedNotice: { key: "frameOnlineAgain", params: { frame: f.name, space: space.name } },
    });
  }

  // 5b. A Space's storage at 80 % of its plan or more (2026-11-11,
  // migrations/0102): its managers hear so. At 100 % create-upload refuses.
  {
    const { data: rows } = await supabaseAdmin.rpc("space_storage_levels");
    for (const r of (rows ?? []) as { space_id: string; space_name: string; used_bytes: number; limit_bytes: number }[]) {
      const limit = Number(r.limit_bytes);
      if (!limit || Number(r.used_bytes) < limit * 0.8) continue;
      const percent = Math.min(100, Math.floor((Number(r.used_bytes) / limit) * 100));
      const limitGb = Math.round(limit / 1024 ** 3);
      const managers = await spaceManagerIds(supabaseAdmin, r.space_id);
      problems.set(`space_storage:${r.space_id}`, {
        title: `${r.space_name}: ${percent} % belegt`,
        body: `Der Speicher (${limitGb} GB) wird knapp.`,
        recipients: managers,
        data: { type: "space_renamed", space_id: r.space_id, space_name: r.space_name },
        solvedTitle: `${r.space_name}: wieder genug Platz`,
        solvedBody: "Der Speicher eures Spaces hat wieder genug Platz.",
        notice: { key: "spaceStorageHigh", params: { space: r.space_name, percent, limitGb } },
        solvedNotice: { key: "spaceStorageOk", params: { space: r.space_name } },
      });
    }
  }

  // 5c. Frame plan / trial ending (2026-11-11, migrations/0102): 30 and 7
  // days before and the day after, once each, to the Space's managers.
  {
    const { data: due } = await supabaseAdmin.rpc("plan_reminders_due");
    for (const r of (due ?? []) as { space_id: string; space_name: string; kind: string; source: string; ends_at: string }[]) {
      const managers = await spaceManagerIds(supabaseAdmin, r.space_id);
      const trial = r.source === "trial";
      await pushNotificationToUsers(
        supabaseAdmin,
        managers,
        r.kind === "ended"
          ? (t: PushTexts) => t.planEnded({ space: r.space_name, trial })
          : (t: PushTexts) => t.planEndsSoon({ space: r.space_name, trial, endsAt: r.ends_at }),
        { type: "space_renamed", space_id: r.space_id, space_name: r.space_name },
      );
    }
  }

  // 6. Stored media size
  const { data: sizes } = await supabaseAdmin.from("media_items").select("file_size_bytes").limit(100000);
  const totalGb = (sizes ?? []).reduce((sum, r) => sum + Number(r.file_size_bytes ?? 0), 0) / 1024 ** 3;
  if (totalGb > storageWarnGb) {
    opsProblem(
      "storage_size",
      "Speicher wächst",
      `Fotos und Videos belegen ${totalGb.toFixed(1)} GB (Warnschwelle ${storageWarnGb} GB). Kosten und Tarif prüfen.`,
      `Der Speicher liegt wieder unter ${storageWarnGb} GB.`,
    );
  }

  // --- announce / remind / resolve ------------------------------------------
  const { data: open } = await supabaseAdmin.from("health_alerts").select("*").is("resolved_at", null);
  const openByKey = new Map((open ?? []).map((a) => [a.key as string, a]));
  let announced = 0;
  for (const [key, p] of problems) {
    const existing = openByKey.get(key);
    const nowIso = new Date(now).toISOString();
    if (!existing) {
      await supabaseAdmin.from("health_alerts").upsert({
        key,
        title: p.title,
        body: p.body,
        recipients: p.recipients,
        data: {
          ...p.data,
          solved_title: p.solvedTitle,
          solved_body: p.solvedBody,
          ...(p.solvedNotice ? { solved_notice: JSON.stringify(p.solvedNotice) } : {}),
        },
        first_seen_at: nowIso,
        last_notified_at: nowIso,
        resolved_at: null,
      });
      await pushNotificationToUsers(supabaseAdmin, p.recipients, p.notice ? localized(p.notice) : { title: p.title, body: p.body }, p.data);
      announced++;
    } else if (now - new Date(existing.last_notified_at as string).getTime() >= REMIND_AFTER) {
      await supabaseAdmin.from("health_alerts").update({ body: p.body, last_notified_at: nowIso }).eq("key", key);
      const notice = p.notice;
      await pushNotificationToUsers(
        supabaseAdmin,
        p.recipients,
        notice
          ? (t: PushTexts) => {
            const n = localized(notice)(t);
            return { title: t.stillOngoing(n.title), body: n.body };
          }
          : { title: `${p.title} (weiterhin)`, body: p.body },
        p.data,
      );
      announced++;
    }
  }
  let solved = 0;
  for (const [key, a] of openByKey) {
    if (problems.has(key)) continue;
    await supabaseAdmin.from("health_alerts").update({ resolved_at: new Date(now).toISOString() }).eq("key", key);
    const { solved_title, solved_body, solved_notice, ...data } = (a.data ?? {}) as Record<string, string>;
    await pushNotificationToUsers(
      supabaseAdmin,
      a.recipients as string[],
      solved_notice
        ? localized(JSON.parse(solved_notice) as CatalogNotice)
        : { title: solved_title ?? "Wieder in Ordnung", body: solved_body ?? `Behoben: ${a.title}` },
      data,
    );
    solved++;
  }
  return jsonResponse({ status: "ok", problems: [...problems.keys()], announced, solved });
});
