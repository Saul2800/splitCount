import { Hono } from 'hono';
import { cors } from 'hono/cors';

export interface Env {
  DB: D1Database;
  APK_BUCKET: R2Bucket;
  MASTER_PASSWORD?: string;
  ENVIRONMENT?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use('*', cors());

// Health check endpoint
app.get('/', (c) => {
  return c.json({
    status: 'ok',
    service: 'SplitCount Cloudflare Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Password-protected APK download page
app.get('/download', (c) => {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SplitCount — Download APK</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #0f172a; color: #f8fafc; }
    .card { background: #1e293b; padding: 2rem; border-radius: 1rem; box-shadow: 0 10px 25px rgba(0,0,0,0.5); width: 100%; max-width: 400px; text-align: center; }
    h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: #38bdf8; }
    p { font-size: 0.9rem; color: #94a3b8; margin-bottom: 1.5rem; }
    input { width: 100%; padding: 0.75rem; border: 1px solid #334155; border-radius: 0.5rem; background: #0f172a; color: #fff; margin-bottom: 1rem; box-sizing: border-box; }
    button { width: 100%; padding: 0.75rem; background: #0284c7; border: none; border-radius: 0.5rem; color: #fff; font-weight: 600; cursor: pointer; transition: background 0.2s; }
    button:hover { background: #0369a1; }
  </style>
</head>
<body>
  <div class="card">
    <h1>SplitCount</h1>
    <p>Private build download. Enter master password:</p>
    <form method="POST" action="/api/download">
      <input type="password" name="password" placeholder="Master Password" required />
      <button type="submit">Download .apk</button>
    </form>
  </div>
</body>
</html>`;
  return c.html(html);
});

// Handle password-protected APK download
app.post('/api/download', async (c) => {
  const body = await c.req.parseBody();
  const password = body['password'];
  const masterPassword = c.env.MASTER_PASSWORD || 'splitcount2026';

  if (password !== masterPassword) {
    return c.text('Unauthorized: Invalid master password', 401);
  }

  try {
    const object = await c.env.APK_BUCKET.get('splitcount-latest.apk');
    if (!object) {
      return c.text('APK not found in R2 storage yet. Please push to GitHub or upload an APK build.', 404);
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('Content-Type', 'application/vnd.android.package-archive');
    headers.set('Content-Disposition', 'attachment; filename="splitcount-latest.apk"');

    return new Response(object.body, { headers });
  } catch (err: any) {
    return c.text('Storage error: ' + (err.message || 'Unable to fetch APK'), 500);
  }
});

// Group verification endpoint
app.get('/api/v1/groups/verify', async (c) => {
  const token = c.req.header('X-Group-Token');
  if (!token) {
    return c.json({ error: 'Missing X-Group-Token header' }, 401);
  }

  const group = await c.env.DB.prepare(
    'SELECT id, name, currency, created_at FROM groups WHERE group_token = ? AND is_deleted = 0'
  ).bind(token).first();

  if (!group) {
    return c.json({ error: 'Group not found or token invalid' }, 404);
  }

  return c.json({ success: true, group });
});

// Incremental sync pull endpoint
app.post('/api/v1/sync/pull', async (c) => {
  const token = c.req.header('X-Group-Token');
  if (!token) return c.json({ error: 'Missing X-Group-Token' }, 401);

  const body = await c.req.json<{ group_id: string; since_timestamp: number }>();
  const { group_id, since_timestamp = 0 } = body;

  const expenses = await c.env.DB.prepare(
    'SELECT * FROM expenses WHERE group_id = ? AND updated_at > ?'
  ).bind(group_id, since_timestamp).all();

  const members = await c.env.DB.prepare(
    'SELECT * FROM group_members WHERE group_id = ? AND updated_at > ?'
  ).bind(group_id, since_timestamp).all();

  const settlements = await c.env.DB.prepare(
    'SELECT * FROM settlements WHERE group_id = ? AND updated_at > ?'
  ).bind(group_id, since_timestamp).all();

  const auditLogs = await c.env.DB.prepare(
    'SELECT * FROM audit_logs WHERE group_id = ? AND timestamp > ?'
  ).bind(group_id, since_timestamp).all();

  return c.json({
    timestamp: Date.now(),
    data: {
      expenses: expenses.results,
      members: members.results,
      settlements: settlements.results,
      audit_logs: auditLogs.results,
    },
  });
});

export default app;
