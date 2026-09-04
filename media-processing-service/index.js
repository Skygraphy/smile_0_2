// Media processing service: resizes photos and transcodes videos dispatched by
// the `complete-upload` Edge Function, then reports the result back to
// `media-processed-callback`. Real photo (sharp) / video (ffmpeg) pipelines
// land in Phase 5a; this is the Phase 0 scaffold (health check only).
import express from "express";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/process", (_req, res) => {
  res.status(501).json({ error: "not_implemented", detail: "Phase 5a" });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`media-processing-service listening on ${port}`);
});
