// The English notification texts (2026-11-10) -- the same keys as the German
// catalog in push-texts.ts; TypeScript reports any missing one.
import type { PushTexts } from "./push-texts.ts";

function englishDate(iso: string): string {
  const d = new Date(iso);
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${months[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
}

export const en: PushTexts = {
  someone: "Someone",

  // --- photos and videos ---
  newPhotosTitleFallback: "New photo",
  newPhotos: (p) => {
    const sender = p.sender ?? en.someone;
    const total = p.photos + p.videos;
    if (total <= 1 && p.caption) return `${sender}: ${p.caption}`;
    if (total <= 1) return `${sender} shared ${p.videos === 1 ? "a video" : "a photo"}.`;
    const kind = p.videos === 0 ? "photos" : p.photos === 0 ? "videos" : "photos and videos";
    return `${sender} shared ${total} new ${kind}.`;
  },
  photosDeleted: (p) => ({
    title: "Photo deleted",
    body: p.count === 1
      ? `${p.actor ?? en.someone} deleted your photo from ${p.album}.`
      : `${p.actor ?? en.someone} deleted ${p.count} of your photos from ${p.album}.`,
  }),
  mediaFailed: (p) => ({
    title: "Upload failed",
    body: `Your ${p.video ? "video" : "photo"} in ${p.album} couldn't be processed. Please try again.`,
  }),
  frameFavorite: (p) => ({
    title: `${p.frame ?? "A Frame"} kept your ${p.video ? "video" : "photo"} ♥`,
    body: `From the album ${p.album} – now a favorite on the Frame.`,
  }),

  // --- Frames ---
  frameShowsNewAlbum: (p) => ({
    title: "Frame shows a new album",
    body: `${p.actor ?? en.someone}: The Frame ${p.frame} now also shows ${p.album}.`,
  }),
  frameAlbumRemoved: (p) => ({
    title: "Frame no longer shows an album",
    body: `${p.actor ?? en.someone}: The Frame ${p.frame} no longer shows ${p.album}.`,
  }),
  frameCreated: (p) => ({ title: "New Frame", body: `${p.actor ?? en.someone} created the Frame ${p.frame} in ${p.space}.` }),
  frameDeleted: (p) => ({ title: "Frame deleted", body: `${p.actor ?? en.someone} deleted the Frame ${p.frame} in ${p.space}.` }),
  frameRunsAgain: (p) => ({
    title: `${p.frame} is running again`,
    body: "The tablet was restarted, e.g. after a power cut. If the Frame was pinned, please pin it again.",
  }),
  framePaired: (p) => ({ title: "Frame connected", body: `The Frame ${p.frame} in ${p.space} is now connected and showing photos.` }),
  frameRevoked: (p) => ({ title: "Frame revoked", body: `${p.actor ?? en.someone} revoked the Frame ${p.frame} in ${p.space}.` }),
  frameReactivated: (p) => ({ title: "Frame active again", body: `${p.actor ?? en.someone} reactivated the Frame ${p.frame} in ${p.space}.` }),
  frameRenamed: (p) => ({ title: "Frame renamed", body: `${p.actor ?? en.someone} renamed the Frame ${p.oldName} to ${p.newName}.` }),
  frameVideoSound: (p) => ({
    title: "Frame setting changed",
    body: `${p.actor ?? en.someone}: Videos on the Frame ${p.frame} now play ${p.on ? "with" : "without"} sound.`,
  }),
  frameAlbumSwitch: (p) => ({
    title: "Frame setting changed",
    body: `${p.actor ?? en.someone}: Switching albums on the Frame ${p.frame} is now ${p.on ? "allowed" : "off"}.`,
  }),
  frameShowsNow: (p) => ({ title: p.frame, body: `${p.actor ?? en.someone} set ${p.frame} to the album ${p.album}.` }),
  framePicture: (p) => ({
    title: "Picture changed",
    body: `${p.actor ?? en.someone} ${p.removed ? "removed" : "changed"} the picture of the Frame ${p.frame}.`,
  }),
  frameAdminInvite: (p) => ({
    title: "Invitation as Frame admin",
    body: `${p.inviter ?? en.someone} would like to make you Frame admin of ${p.frame}. Accept under Activity.`,
  }),

  // --- albums ---
  albumCreated: (p) => ({ title: "New album", body: `${p.actor ?? en.someone} created the album ${p.album} in ${p.space}.` }),
  albumRenamed: (p) => ({ title: "Album renamed", body: `${p.actor ?? en.someone} renamed the album ${p.oldName} to ${p.newName}.` }),
  albumCoverAutomatic: (p) => ({
    title: "Automatic cover",
    body: `${p.actor ?? en.someone}: ${p.album} shows the newest photo as its cover again.`,
  }),
  albumCoverNew: (p) => ({ title: "New cover", body: `${p.actor ?? en.someone} set a new cover for ${p.album}.` }),
  memberInvite: (p) => ({
    title: "Invitation to an album",
    body: `You were invited as a member of the album ${p.album}. Accept under Activity.`,
  }),
  shareInvite: (p) => ({
    title: "Album shared with you",
    body: `Your Space can now see the album ${p.album} too. Accept under Activity.`,
  }),
  memberLeft: (p) => ({ title: "Left the album", body: `${p.name ?? en.someone} left the album ${p.album}.` }),
  memberRemoved: (p) => ({ title: "No longer in the album", body: `${p.actor ?? en.someone} removed you from the album ${p.album}.` }),
  shareAudienceChanged: (p) => ({
    title: `A new person sees ${p.album}`,
    body: `${p.name ?? en.someone} is now co-admin of ${p.space} and so also sees the album ${p.album}.`,
  }),
  shareEnded: (p) => ({
    title: "No longer shared",
    body: `${p.actor ?? en.someone} no longer shares the album ${p.album} with ${p.space}.`,
  }),

  // --- invitations and requests ---
  requestCreated: (p) => ({
    title: "New request",
    body: p.share
      ? `${p.name ?? en.someone} would like to see the album ${p.album} with their own Space. Answer under Activity.`
      : `${p.name ?? en.someone} would like to become a member of the album ${p.album}. Answer under Activity.`,
  }),
  inviteDecided: (p) => {
    const verb = p.accepted ? "accepted" : "declined";
    return {
      title: "Invitation answered",
      body: p.share
        ? `${p.name ?? en.someone} ${verb} the album ${p.album} for their own Space.`
        : `${p.name ?? en.someone} ${verb} the invitation to the album ${p.album}.`,
    };
  },
  requestDecided: (p) => {
    const verb = p.accepted ? "accepted" : "declined";
    return {
      title: "Request answered",
      body: p.share
        ? `Your request to see the album ${p.album} with your Space was ${verb}.`
        : `Your request to become a member of the album ${p.album} was ${verb}.`,
    };
  },
  inviteExpired: (p) => ({
    title: "Invitation expired",
    body: `${p.name ?? en.someone} didn't answer the invitation to the album ${p.album}.`,
  }),
  shareInviteExpired: (p) => ({
    title: "Invitation expired",
    body: `${p.name ?? en.someone} didn't answer the sharing of ${p.album}.`,
  }),
  ownRequestExpired: (p) => ({
    title: "Request expired",
    body: p.share
      ? `Your request to see the album ${p.album} with your Space wasn't answered.`
      : `Your request to become a member of the album ${p.album} wasn't answered.`,
  }),

  // --- Spaces and co-admins ---
  coAdminInvite: (p) => ({
    title: "Invitation as co-admin",
    body: `You were invited to help manage the Space ${p.space} as co-admin. Accept under Activity.`,
  }),
  coAdminInviteDecided: (p) => ({
    title: "Invitation answered",
    body: `${p.name ?? en.someone} ${p.accepted ? "accepted" : "declined"} your invitation as co-admin of ${p.space}.`,
  }),
  coAdminInviteExpired: (p) => ({
    title: "Invitation expired",
    body: `${p.name ?? en.someone} didn't answer the invitation as co-admin of ${p.space}.`,
  }),
  coAdminSteppedDown: (p) => ({
    title: "Co-admin role given up",
    body: `${p.name ?? en.someone} no longer helps manage the Space ${p.space}.`,
  }),
  coAdminRemoved: (p) => ({ title: "No longer co-admin", body: `${p.actor ?? en.someone} removed you as co-admin of ${p.space}.` }),
  nowAdmin: (p) => ({ title: "You're now the admin", body: `You're now the admin of the Space ${p.space}.` }),
  nowAdminAfterAccountDeleted: (p) => ({
    title: "You're now the admin",
    body: `${p.name ?? en.someone} deleted their Smile account. You're now the admin of the Space ${p.space}.`,
  }),
  spaceGoneWithAccount: (p) => ({
    title: "Space deleted",
    body: `${p.name ?? en.someone} deleted their Smile account. The Space ${p.space} and all its albums no longer exist.`,
  }),
  spaceRenamed: (p) => ({ title: "Space renamed", body: `${p.actor ?? en.someone} renamed the Space ${p.oldName} to ${p.newName}.` }),
  spacePicture: (p) => ({
    title: "Picture changed",
    body: `${p.actor ?? en.someone} ${p.removed ? "removed" : "changed"} the picture of ${p.space}.`,
  }),

  // --- trash ---
  trashed: (p) => ({
    title: p.kind === "channel" ? "Album deleted" : "Space deleted",
    body: `${p.actor ?? en.someone} deleted ${p.kind === "channel" ? `the album ${p.name}` : `the Space ${p.name} with all its albums and Frames`}. It can be restored until ${
      p.purgeAt ? englishDate(p.purgeAt) : "30 days from now"
    }.`,
  }),
  restored: (p) => ({
    title: p.kind === "channel" ? "Album restored" : "Space restored",
    body: `${p.actor ?? en.someone} restored ${p.kind === "channel" ? `the album ${p.name}` : `the Space ${p.name} with all its albums and Frames`}.`,
  }),
};
