// Where a media item's processed files live, derived from its original's
// path -- one definition for complete-upload (dispatching the job) and
// media-processed-callback (handing a long-running video worker fresh
// upload tokens at the end, see there).
export function processedPaths(mediaType: string, storagePathOriginal: string) {
  const extMatch = storagePathOriginal.match(/\.[^./]+$/);
  const originalExt = extMatch ? extMatch[0] : "";
  const basePath = storagePathOriginal.slice(0, storagePathOriginal.length - originalExt.length);
  const isVideo = mediaType === "video";
  return {
    // Videos become a 720p MP4; photos keep their format.
    displayPath: `${basePath}_display${isVideo ? ".mp4" : originalExt || ".jpg"}`,
    // Photos get a small copy, videos a poster frame -- both JPEG-able images.
    thumbnailPath: `${basePath}_thumb${isVideo ? ".jpg" : originalExt || ".jpg"}`,
  };
}
