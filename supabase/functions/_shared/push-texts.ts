// Every notification text in one place, per language (Mehrsprachigkeit,
// 2026-11-10). pushNotificationToUsers() writes each person's notification in
// the language of their app (profiles.language); a new language is one more
// catalog below with the same keys -- TypeScript checks that none is missing.

export type Notice = { title: string; body: string };
type Who = string | null;

function germanDate(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getUTCDate()).padStart(2, "0")}.${String(d.getUTCMonth() + 1).padStart(2, "0")}.${d.getUTCFullYear()}`;
}

const de = {
  someone: "Jemand",

  // --- photos and videos ---
  newPhotosTitleFallback: "Neues Foto",
  newPhotos: (p: { sender: Who; photos: number; videos: number; caption?: string | null }): string => {
    const sender = p.sender ?? de.someone;
    const total = p.photos + p.videos;
    // One photo with a title: the title is the message (2026-10-17).
    if (total <= 1 && p.caption) return `${sender}: ${p.caption}`;
    if (total <= 1) return `${sender} hat ${p.videos === 1 ? "ein Video" : "ein Foto"} geteilt.`;
    const kind = p.videos === 0 ? "Fotos" : p.photos === 0 ? "Videos" : "Fotos und Videos";
    return `${sender} hat ${total} neue ${kind} geteilt.`;
  },
  photosDeleted: (p: { actor: Who; count: number; album: string }): Notice => ({
    title: "Foto gelöscht",
    body: p.count === 1
      ? `${p.actor ?? de.someone} hat dein Foto aus ${p.album} gelöscht.`
      : `${p.actor ?? de.someone} hat ${p.count} deiner Fotos aus ${p.album} gelöscht.`,
  }),
  mediaFailed: (p: { video: boolean; album: string }): Notice => ({
    title: "Hochladen fehlgeschlagen",
    body: `Dein ${p.video ? "Video" : "Foto"} in ${p.album} konnte nicht verarbeitet werden. Bitte versuche es noch einmal.`,
  }),
  frameFavorite: (p: { frame: string | null; video: boolean; album: string }): Notice => ({
    title: `${p.frame ?? "Ein Frame"} hat ${p.video ? "dein Video" : "dein Foto"} gemerkt ♥`,
    body: `Aus dem Album ${p.album} – jetzt ein Lieblingsbild am Frame.`,
  }),

  // --- Frames ---
  frameShowsNewAlbum: (p: { actor: Who; frame: string; album: string }): Notice => ({
    title: "Frame zeigt neues Album",
    body: `${p.actor ?? de.someone}: Der Frame ${p.frame} zeigt jetzt auch ${p.album}.`,
  }),
  frameAlbumRemoved: (p: { actor: Who; frame: string; album: string }): Notice => ({
    title: "Frame zeigt Album nicht mehr",
    body: `${p.actor ?? de.someone}: Der Frame ${p.frame} zeigt ${p.album} nicht mehr.`,
  }),
  frameCreated: (p: { actor: Who; frame: string; space: string }): Notice => ({
    title: "Neuer Frame",
    body: `${p.actor ?? de.someone} hat den Frame ${p.frame} in ${p.space} angelegt.`,
  }),
  frameDeleted: (p: { actor: Who; frame: string; space: string }): Notice => ({
    title: "Frame gelöscht",
    body: `${p.actor ?? de.someone} hat den Frame ${p.frame} in ${p.space} gelöscht.`,
  }),
  frameRunsAgain: (p: { frame: string }): Notice => ({
    title: `${p.frame} läuft wieder`,
    body: "Das Tablet wurde neu gestartet, z. B. nach einem Stromausfall. War der Frame angeheftet, bitte neu anheften.",
  }),
  framePaired: (p: { frame: string; space: string }): Notice => ({
    title: "Frame verbunden",
    body: `Der Frame ${p.frame} in ${p.space} ist jetzt verbunden und zeigt Fotos.`,
  }),
  frameRevoked: (p: { actor: Who; frame: string; space: string }): Notice => ({
    title: "Frame widerrufen",
    body: `${p.actor ?? de.someone} hat den Frame ${p.frame} in ${p.space} widerrufen.`,
  }),
  frameReactivated: (p: { actor: Who; frame: string; space: string }): Notice => ({
    title: "Frame wieder aktiv",
    body: `${p.actor ?? de.someone} hat den Frame ${p.frame} in ${p.space} wieder aktiviert.`,
  }),
  frameRenamed: (p: { actor: Who; oldName: string; newName: string }): Notice => ({
    title: "Frame umbenannt",
    body: `${p.actor ?? de.someone} hat den Frame ${p.oldName} in ${p.newName} umbenannt.`,
  }),
  frameVideoSound: (p: { actor: Who; frame: string; on: boolean }): Notice => ({
    title: "Frame-Einstellung geändert",
    body: `${p.actor ?? de.someone}: Am Frame ${p.frame} laufen Videos jetzt ${p.on ? "mit" : "ohne"} Ton.`,
  }),
  frameAlbumSwitch: (p: { actor: Who; frame: string; on: boolean }): Notice => ({
    title: "Frame-Einstellung geändert",
    body: `${p.actor ?? de.someone}: Am Frame ${p.frame} ist der Album-Wechsel jetzt ${p.on ? "erlaubt" : "aus"}.`,
  }),
  frameShowsNow: (p: { actor: Who; frame: string; album: string }): Notice => ({
    title: p.frame,
    body: `${p.actor ?? de.someone} hat ${p.frame} auf das Album ${p.album} gestellt.`,
  }),
  framePicture: (p: { actor: Who; frame: string; removed: boolean }): Notice => ({
    title: "Bild geändert",
    body: `${p.actor ?? de.someone} hat das Bild des Frames ${p.frame} ${p.removed ? "entfernt" : "geändert"}.`,
  }),
  frameAdminInvite: (p: { inviter: Who; frame: string }): Notice => ({
    title: "Einladung als Frame-Admin",
    body: `${p.inviter ?? de.someone} möchte dich zum Frame-Admin von ${p.frame} machen. Annehmen unter Neuigkeiten.`,
  }),

  // --- albums ---
  albumCreated: (p: { actor: Who; album: string; space: string }): Notice => ({
    title: "Neues Album",
    body: `${p.actor ?? de.someone} hat das Album ${p.album} in ${p.space} angelegt.`,
  }),
  albumRenamed: (p: { actor: Who; oldName: string; newName: string }): Notice => ({
    title: "Album umbenannt",
    body: `${p.actor ?? de.someone} hat das Album ${p.oldName} in ${p.newName} umbenannt.`,
  }),
  albumCoverAutomatic: (p: { actor: Who; album: string }): Notice => ({
    title: "Titelbild automatisch",
    body: `${p.actor ?? de.someone}: ${p.album} zeigt wieder automatisch das neueste Foto.`,
  }),
  albumCoverNew: (p: { actor: Who; album: string }): Notice => ({
    title: "Neues Titelbild",
    body: `${p.actor ?? de.someone} hat ein neues Titelbild für ${p.album} festgelegt.`,
  }),
  memberInvite: (p: { album: string }): Notice => ({
    title: "Einladung ins Album",
    body: `Du wurdest als Member ins Album ${p.album} eingeladen. Annehmen unter Neuigkeiten.`,
  }),
  shareInvite: (p: { album: string }): Notice => ({
    title: "Album mit dir geteilt",
    body: `Das Album ${p.album} kann jetzt auch dein Space sehen. Annehmen unter Neuigkeiten.`,
  }),
  memberLeft: (p: { name: Who; album: string }): Notice => ({
    title: "Album verlassen",
    body: `${p.name ?? de.someone} hat das Album ${p.album} verlassen.`,
  }),
  memberRemoved: (p: { actor: Who; album: string }): Notice => ({
    title: "Nicht mehr im Album",
    body: `${p.actor ?? de.someone} hat dich aus dem Album ${p.album} entfernt.`,
  }),
  shareAudienceChanged: (p: { name: Who; space: string; album: string }): Notice => ({
    title: `Neue Person sieht ${p.album}`,
    body: `${p.name ?? de.someone} ist jetzt Co-Admin von ${p.space} und sieht damit auch das Album ${p.album}.`,
  }),
  shareEnded: (p: { actor: Who; album: string; space: string }): Notice => ({
    title: "Nicht mehr geteilt",
    body: `${p.actor ?? de.someone} teilt das Album ${p.album} nicht mehr mit ${p.space}.`,
  }),

  // --- invitations and requests ---
  requestCreated: (p: { name: Who; album: string; share: boolean }): Notice => ({
    title: "Neue Anfrage",
    body: p.share
      ? `${p.name ?? de.someone} möchte das Album ${p.album} mit dem eigenen Space sehen. Antworten unter Neuigkeiten.`
      : `${p.name ?? de.someone} möchte Member im Album ${p.album} werden. Antworten unter Neuigkeiten.`,
  }),
  inviteDecided: (p: { name: Who; album: string; share: boolean; accepted: boolean }): Notice => {
    const verb = p.accepted ? "angenommen" : "abgelehnt";
    return {
      title: "Einladung beantwortet",
      body: p.share
        ? `${p.name ?? de.someone} hat das Album ${p.album} für den eigenen Space ${verb}.`
        : `${p.name ?? de.someone} hat die Einladung ins Album ${p.album} ${verb}.`,
    };
  },
  requestDecided: (p: { album: string; share: boolean; accepted: boolean }): Notice => {
    const verb = p.accepted ? "angenommen" : "abgelehnt";
    return {
      title: "Anfrage beantwortet",
      body: p.share
        ? `Deine Anfrage, das Album ${p.album} mit deinem Space zu sehen, wurde ${verb}.`
        : `Deine Anfrage, Member im Album ${p.album} zu werden, wurde ${verb}.`,
    };
  },
  inviteExpired: (p: { name: Who; album: string }): Notice => ({
    title: "Einladung abgelaufen",
    body: `${p.name ?? de.someone} hat die Einladung ins Album ${p.album} nicht beantwortet.`,
  }),
  shareInviteExpired: (p: { name: Who; album: string }): Notice => ({
    title: "Einladung abgelaufen",
    body: `${p.name ?? de.someone} hat das Teilen von ${p.album} nicht beantwortet.`,
  }),
  ownRequestExpired: (p: { album: string; share: boolean }): Notice => ({
    title: "Anfrage abgelaufen",
    body: p.share
      ? `Deine Anfrage, das Album ${p.album} mit deinem Space zu sehen, wurde nicht beantwortet.`
      : `Deine Anfrage, Member im Album ${p.album} zu werden, wurde nicht beantwortet.`,
  }),

  // --- Spaces and Co-Admins ---
  coAdminInvite: (p: { space: string }): Notice => ({
    title: "Einladung als Co-Admin",
    body: `Du wurdest eingeladen, den Space ${p.space} als Co-Admin mitzuverwalten. Annehmen unter Neuigkeiten.`,
  }),
  coAdminInviteDecided: (p: { name: Who; space: string; accepted: boolean }): Notice => ({
    title: "Einladung beantwortet",
    body: `${p.name ?? de.someone} hat deine Einladung als Co-Admin von ${p.space} ${p.accepted ? "angenommen" : "abgelehnt"}.`,
  }),
  coAdminInviteExpired: (p: { name: Who; space: string }): Notice => ({
    title: "Einladung abgelaufen",
    body: `${p.name ?? de.someone} hat die Einladung als Co-Admin von ${p.space} nicht beantwortet.`,
  }),
  coAdminSteppedDown: (p: { name: Who; space: string }): Notice => ({
    title: "Co-Admin-Rolle abgegeben",
    body: `${p.name ?? de.someone} verwaltet den Space ${p.space} nicht mehr mit.`,
  }),
  coAdminRemoved: (p: { actor: Who; space: string }): Notice => ({
    title: "Nicht mehr Co-Admin",
    body: `${p.actor ?? de.someone} hat dich als Co-Admin von ${p.space} entfernt.`,
  }),
  nowAdmin: (p: { space: string }): Notice => ({
    title: "Du bist jetzt Admin",
    body: `Du bist jetzt Admin des Space ${p.space}.`,
  }),
  nowAdminAfterAccountDeleted: (p: { name: Who; space: string }): Notice => ({
    title: "Du bist jetzt Admin",
    body: `${p.name ?? de.someone} hat das Smile-Konto gelöscht. Du bist jetzt Admin des Space ${p.space}.`,
  }),
  spaceGoneWithAccount: (p: { name: Who; space: string }): Notice => ({
    title: "Space gelöscht",
    body: `${p.name ?? de.someone} hat das Smile-Konto gelöscht. Den Space ${p.space} mit allen Alben gibt es nicht mehr.`,
  }),
  spaceRenamed: (p: { actor: Who; oldName: string; newName: string }): Notice => ({
    title: "Space umbenannt",
    body: `${p.actor ?? de.someone} hat den Space ${p.oldName} in ${p.newName} umbenannt.`,
  }),
  spacePicture: (p: { actor: Who; space: string; removed: boolean }): Notice => ({
    title: "Bild geändert",
    body: `${p.actor ?? de.someone} hat das Bild von ${p.space} ${p.removed ? "entfernt" : "geändert"}.`,
  }),

  // --- trash ---
  trashed: (p: { actor: Who; kind: "channel" | "space"; name: string; purgeAt: string | null }): Notice => ({
    title: p.kind === "channel" ? "Album gelöscht" : "Space gelöscht",
    body: `${p.actor ?? de.someone} hat ${p.kind === "channel" ? `das Album ${p.name}` : `den Space ${p.name} mit allen Alben und Frames`} gelöscht. Bis ${
      p.purgeAt ? germanDate(p.purgeAt) : "in 30 Tagen"
    } kann das noch rückgängig gemacht werden.`,
  }),
  restored: (p: { actor: Who; kind: "channel" | "space"; name: string }): Notice => ({
    title: p.kind === "channel" ? "Album wiederhergestellt" : "Space wiederhergestellt",
    body: `${p.actor ?? de.someone} hat ${p.kind === "channel" ? `das Album ${p.name}` : `den Space ${p.name} mit allen Alben und Frames`} wiederhergestellt.`,
  }),
};

export type PushTexts = typeof de;

/** A notification written in the recipient's language. */
export type Localized = (t: PushTexts) => Notice;

const catalogs: Record<string, PushTexts> = { de };

/** The catalog for a language; German for an unknown or missing one. */
export function pushTexts(language?: string | null): PushTexts {
  return catalogs[language ?? "de"] ?? de;
}
