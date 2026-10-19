// Removes every file from every storage bucket of the TESTSUITE project.
// Uses the live-project guard of the server test suite.
import { requireEnv } from "../../supabase/functions/_tests/helpers.ts";

const { url, serviceKey } = requireEnv();
const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" };

async function listAll(bucket: string, prefix = ""): Promise<string[]> {
  const files: string[] = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${url}/storage/v1/object/list/${bucket}`, {
      method: "POST",
      headers,
      body: JSON.stringify({ prefix, limit: 1000, offset }),
    });
    const entries = await res.json() as { name: string; id: string | null }[];
    if (!Array.isArray(entries)) throw new Error(`list ${bucket}/${prefix}: ${JSON.stringify(entries)}`);
    for (const e of entries) {
      const path = prefix ? `${prefix}/${e.name}` : e.name;
      if (e.id === null) files.push(...await listAll(bucket, path));
      else files.push(path);
    }
    if (entries.length < 1000) break;
  }
  return files;
}

const buckets = await (await fetch(`${url}/storage/v1/bucket`, { headers })).json() as { id: string }[];
for (const { id } of buckets) {
  const files = await listAll(id);
  for (let i = 0; i < files.length; i += 500) {
    const res = await fetch(`${url}/storage/v1/object/${id}`, {
      method: "DELETE",
      headers,
      body: JSON.stringify({ prefixes: files.slice(i, i + 500) }),
    });
    if (!res.ok) throw new Error(`delete in ${id}: ${res.status} ${await res.text()}`);
  }
  console.log(`${id}: ${files.length} Dateien gelöscht`);
}
