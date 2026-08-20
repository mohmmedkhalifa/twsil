// Twsil FCM edge function
// Sends Firebase Cloud Messaging pushes + stores notifications rows.
// Invoked server-to-server (pg_net triggers) with X-Twsil-Secret,
// or directly by admins with a valid admin JWT.
const FIREBASE_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

let cachedToken: { token: string; exp: number } | null = null;

async function getOAuthToken(): Promise<string> {
  if (cachedToken && cachedToken.exp > Date.now() + 60_000) return cachedToken.token;
  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "{}");
  if (!sa.client_email || !sa.private_key) throw new Error("FIREBASE_SERVICE_ACCOUNT missing");
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: sa.client_email,
    scope: FIREBASE_SCOPE,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const b64 = (obj: unknown) => btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signingInput = `${b64(header)}.${b64(claims)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput)));
  const jwt = `${signingInput}.${btoa(String.fromCharCode(...sig)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error("OAuth failed: " + JSON.stringify(data));
  cachedToken = { token: data.access_token, exp: Date.now() + data.expires_in * 1000 };
  return data.access_token;
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----BEGIN [^-]+-----/, "").replace(/-----END [^-]+-----/, "").replace(/\s/g, "");
  const bin = atob(body);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr.buffer;
}

async function sendFcm(token: string, payload: { title: string; body: string; data?: Record<string, string> }) {
  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "{}");
  const oauth = await getOAuthToken();
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${oauth}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: payload.title, body: payload.body },
        data: payload.data ?? {},
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error("FCM send failed: " + res.status + " " + err.slice(0, 200));
  }
  return res.json();
}

async function handle(req: Request): Promise<Response> {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, x-twsil-secret, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const secretOk = req.headers.get("x-twsil-secret") === (Deno.env.get("TW_FN_SECRET") ?? "");
  if (!secretOk) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
  }

  let body: { userIds?: string[]; title?: string; body?: string; type?: string; data?: Record<string, string> };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  const userIds = body.userIds ?? [];
  if (!userIds.length || !body.title || !body.body) {
    return new Response(JSON.stringify({ error: "userIds, title, body required" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const uidList = userIds.map((u) => `"${u}"`).join(",");

  const usersRes = await fetch(`${supabaseUrl}/rest/v1/users?select=id,"fcmToken"&id=in.(${uidList})`, {
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
  });
  const users = await usersRes.json();
  const tokens: { id: string; token: string }[] = (users ?? [])
    .filter((u: { fcmToken?: string | null }) => u.fcmToken)
    .map((u: { id: string; fcmToken: string }) => ({ id: u.id, token: u.fcmToken }));

  let sent = 0;
  const failed: string[] = [];
  for (const { id, token } of tokens) {
    try {
      await sendFcm(token, { title: body.title!, body: body.body!, data: body.data });
      sent++;
    } catch (e) {
      failed.push(id);
      console.error("send failed for", id, (e as Error).message);
    }
  }

  const notifRows = userIds.map((u) => ({
    userId: u,
    type: body.type ?? "general",
    title: body.title!,
    body: body.body!,
    data: body.data ? JSON.stringify(body.data) : null,
  }));
  if (notifRows.length) {
    await fetch(`${supabaseUrl}/rest/v1/notifications`, {
      method: "POST",
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify(notifRows),
    }).catch((e) => console.error("notif insert failed", (e as Error).message));
  }

  return new Response(JSON.stringify({ sent, failed, missing: userIds.length - tokens.length }), {
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(handle);
