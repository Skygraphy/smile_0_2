// Loads the test pictures and videos (Wikimedia Commons, free licenses)
// into fixtures/media/ -- always the same 50 files: every 10th a video,
// shortened to 12 s. The files stay out of git; this list is the record.
//   cd tools/testsuite && npm install && node fetch_media.js
const fs = require("fs"), path = require("path"), { execFileSync } = require("child_process");
const ffmpeg = process.env.FFMPEG || require("ffmpeg-static");
const OUT = path.join(__dirname, "fixtures", "media");
const UA = { "User-Agent": "SmileTestsuite/1.0 (ernst.schiener@skygraphy.com)" };
const MEDIA = [["File:Havelock Island, Mangrove tree on the beach, Andaman Islands.jpg","Strand"],
  ["File:Gurudongmar Lake Sikkim, India (edit).jpg","Bergsee"],
  ["File:Reflection Lake, Lassen Volcanic National Park, in June 2022-6049.jpg","Waldsee"],
  ["File:DSC09611a Search and Rescue Dog, Austrian Red Cross Perchtoldsdorf, 2024-10.jpg","Hund"],
  ["File:Felis catus-cat on snow.jpg","Katze im Schnee"],
  ["File:Birthday Cake in Bhopal 011 (2).jpg","Torte"],
  ["File:Pizza Tradición Napolitana.jpg","Pizza"],
  ["File:Easter breakfast in Serbia (close-up).jpg","Frühstück"],
  ["File:Field of Iceland poppies in the flower garden near Cheomseongdae Observatory in Gyeongju South Korea.jpg","Mohnfeld"],
  ["File:Water waves in Herzliya beach.webm","Wellen"],
  ["File:Dülmen, Börnste, Waldweg -- 2015 -- 4649.jpg","Herbstallee"],
  ["File:Angelus Hut in the winter, Nelson Lakes National Park, New Zealand.jpg","Schneehütte"],
  ["File:Kitesurfer at sunset, Workum, may 2017.jpg","Sonnenuntergang"],
  ["File:Parked bicycle with graffitied building facade and doors in Amsterdam.jpg","Fahrrad"],
  ["File:Haltern am See, Sythen, Weg am Silbersee III -- 2019 -- 2995.jpg","Christbaum"],
  ["File:A cup of coffee in Mohk.jpg","Cappuccino"],
  ["File:Horse grazing at a meadow in Churdhar WS, Himachal Pradesh, India.jpg","Pferd"],
  ["File:Landscape with rainbow and the Old Bridge over the Nam Khan river in Luang Prabang Laos.jpg","Regenbogen"],
  ["File:Organic-strawberries Canada.jpg","Erdbeeren"],
  ["File:Cat Plays.webm","Katze spielt"],
  ["File:Three giraffes 01.jpg","Giraffen"],
  ["File:Banana, ice cream and toffee sauce on waffle at The Queen's Head, Boreham, Essex, England.jpg","Waffeln"],
  ["File:Cucurbita 2011 G1.jpg","Kürbisse"],
  ["File:Leuchtturm in Westerheversand crop.jpg","Leuchtturm"],
  ["File:Sailing boat at sunset, Ionian Sea, Albania.jpg","Segelboot"],
  ["File:Waterfall in Russian Gulch State Park.jpg","Wasserfall"],
  ["File:Peacock butterfly (Aglais io) 2.jpg","Schmetterling"],
  ["File:European robin Créteil 2.jpg","Rotkehlchen"],
  ["File:Richardson's red squirrel (Tamiasciurus hudsonicus richardsoni) Moraine Lake.jpg","Eichhörnchen"],
  ["File:Kamakura underwater fireworks 2.webm","Feuerwerk"],
  ["File:Domestic duck bathing and splashing in a pond at golden hour in Don Det Laos - side view.jpg","Ente"],
  ["File:Arkaia - Girasoles -BT- 04.jpg","Sonnenblumenfeld"],
  ["File:Apple-tree blossoms 2017 G3.jpg","Apfelblüte"],
  ["File:Breads of Russia.jpg","Brot"],
  ["File:At Sardinia 2024 048.jpg","Spaghetti"],
  ["File:Eldostburgare June 2020 01.jpg","Burger"],
  ["File:Potato Bean Tomato Veg Stall Ooty Market Nilgiris Aug25 A7CR 07103.jpg","Gemüsemarkt"],
  ["File:FraxernVlbg1.JPG","Dorf"],
  ["File:Schloss Neuschwanstein 2013.jpg","Schloss"],
  ["File:Puppy playing.webm","Welpe"],
  ["File:Cow (Fleckvieh breed) Oeschinensee Slaunger 2009-07-07.jpg","Kuh"],
  ["File:Stubai - Tiroler Bergschaf -BT- 01.jpg","Schaf"],
  ["File:Bunny in a small zoo.jpg","Hase"],
  ["File:Tulipa suaveolens floriade to Canberra.jpg","Tulpen"],
  ["File:Манастир Моштаница-капела за паљење свећа (Moštanica Monastery, chapel for lighting candles).jpg","Kerzen"],
  ["File:Autumn leaves Все краски осени Листья клена 21.jpg","Herbstlaub"],
  ["File:2023 Pluszowy miś.jpg","Teddy"],
  ["File:Jules and Gabriel flying a kite at Alameda Afonso Henriques, Lisbon, Portugal (PPL3-Altered) julesvernex2.jpg","Drachensteigen"],
  ["File:Hot-air balloon in Tambov - 02.jpg","Heißluftballon"],
  ["File:A group of ducks swimming in a small rural pond.webm","Enten"]];
const slug = s => s.toLowerCase().replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss").replace(/[^a-z0-9]+/g, "_");
async function info(title, width) {
  const u = "https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url|extmetadata"
    + (width ? "&iiurlwidth=" + width : "") + "&titles=" + encodeURIComponent(title);
  const p = Object.values((await (await fetch(u, { headers: UA })).json()).query.pages)[0];
  const i = p.imageinfo[0], m = i.extmetadata ?? {};
  return { url: i.url, thumb: i.thumburl, lic: m.LicenseShortName?.value ?? "?", page: i.descriptionurl,
    artist: (m.Artist?.value ?? "").replace(/<[^>]+>/g, "").replace(/\s+/g, " ").replace(/\|/g, "/").trim() };
}
async function get(url, file) { fs.writeFileSync(file, Buffer.from(await (await fetch(url, { headers: UA })).arrayBuffer())); }
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const labels = {};
  const lic = ["# Testbilder und Testvideos", "", "Von Wikimedia Commons, freie Lizenzen; nur für Tests und das Tutorial der Test-App.", "",
    "| Datei | Motiv | Urheber | Lizenz | Quelle |", "|---|---|---|---|---|"];
  for (const [n, [title, label]] of MEDIA.entries()) {
    const video = /\.(webm|ogv|ogg)$/i.test(title);
    const file = String(n + 1).padStart(2, "0") + "_" + slug(label) + (video ? ".mp4" : ".jpg");
    const inf = await info(title, video ? 0 : 1600);
    if (!fs.existsSync(path.join(OUT, file))) {
      if (video) {
        const tmp = path.join(OUT, "tmp.webm");
        await get(inf.url, tmp);
        execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-i", tmp, "-t", "12",
          "-vf", "scale='if(gt(iw,ih),min(1280,iw),-2)':'if(gt(iw,ih),-2,min(1280,ih))'",
          "-c:v", "libx264", "-preset", "medium", "-crf", "26", "-pix_fmt", "yuv420p",
          "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", path.join(OUT, file)]);
        fs.unlinkSync(tmp);
      } else {
        await get(inf.thumb ?? inf.url, path.join(OUT, file));
      }
    }
    lic.push("| " + file + " | " + label + (video ? " (Video)" : "") + " | " + inf.artist + " | " + inf.lic + " | " + inf.page + " |");
    labels[file] = label;
    console.log(file);
  }
  fs.writeFileSync(path.join(__dirname, "fixtures", "MEDIA_LICENSES.md"), lic.join("\n") + "\n");
  // The names the test app shows (with umlauts), next to the files.
  fs.writeFileSync(path.join(OUT, "labels.json"), JSON.stringify(labels, null, 1));
})();
