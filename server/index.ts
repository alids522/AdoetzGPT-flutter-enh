import dotenv from 'dotenv';
import express from 'express';
import bcrypt from 'bcryptjs';
import fs from 'node:fs/promises';
import jwt from 'jsonwebtoken';
import path from 'node:path';
import pg from 'pg';
import crypto, { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, '..');
const dataDir = path.join(root, 'data');
const dbPath = process.env.APP_DB_PATH
  ? path.resolve(root, process.env.APP_DB_PATH)
  : path.join(dataDir, 'app-state.json');

const app = express();
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';
const jwtSecret = process.env.AUTH_SECRET || 'adoetzgpt-local-dev-secret-change-me';
const { Client } = pg;

app.use(express.json({ limit: '50mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', req.header('origin') || '*');
  res.header('Vary', 'Origin');
  res.header('Access-Control-Allow-Headers', req.header('access-control-request-headers') || 'Authorization, Content-Type, X-AdoetzGPT-Schema, x-target-url, x-user-id, *');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
  res.header('Access-Control-Allow-Credentials', 'true');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use('/api/proxy', async (req, res) => {
  const targetUrl = req.header('x-target-url');
  if (!targetUrl) return res.status(400).json({ error: 'x-target-url header missing' });

  try {
    const headers: any = {};
    for (const [key, value] of Object.entries(req.headers)) {
      if (key !== 'host' && key !== 'x-target-url' && key !== 'origin' && key !== 'referer' && key !== 'connection' && key !== 'keep-alive') {
        headers[key] = value;
      }
    }

    const fetchOptions: any = {
      method: req.method,
      headers: headers,
    };

    if (req.method !== 'GET' && req.method !== 'HEAD') {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const response = await fetch(targetUrl, fetchOptions);

    res.status(response.status);
    for (const [key, value] of response.headers.entries()) {
      if (key !== 'content-encoding' && key !== 'transfer-encoding') {
        res.setHeader(key, value);
      }
    }

    if (response.body) {
      // @ts-ignore
      const reader = response.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
      res.end();
    } else {
      res.end();
    }
  } catch (err: any) {
    console.error('Proxy error:', err);
    res.status(500).json({ error: err.message });
  }
});

function schemaNameFromConfig(dbConfig: any) {
  const requested = String(dbConfig?.schemaName || process.env.POSTGRES_SCHEMA || 'adoetzgpt');
  if (!/^[A-Za-z_][A-Za-z0-9_]{0,62}$/.test(requested)) {
    throw new Error('Invalid Postgres schema name.');
  }
  return requested;
}

function quoteIdent(identifier: string) {
  return `"${identifier.replace(/"/g, '""')}"`;
}

function clientConfigFromRequest(req: express.Request) {
  const dbConfig = req.body?.dbConfig || {};
  const databaseUrl = String(dbConfig.databaseUrl || '').trim();
  const database = String(dbConfig.database || '').trim();
  const user = String(dbConfig.user || '').trim();
  const password = String(dbConfig.password || '');
  const portValue = String(dbConfig.port || '').trim();
  const schemaName = schemaNameFromConfig(dbConfig);

  if (databaseUrl.startsWith('postgres://') || databaseUrl.startsWith('postgresql://')) {
    const url = new URL(databaseUrl);
    if (database) url.pathname = `/${database}`;
    if (user) url.username = user;
    if (password) url.password = password;
    if (portValue) url.port = portValue;
    
    const config: any = { connectionString: url.toString() };
    if (
      databaseUrl.includes('supabase') || 
      databaseUrl.includes('neon.tech') || 
      databaseUrl.includes('render.com') || 
      databaseUrl.includes('sslmode=require')
    ) {
      config.ssl = { rejectUnauthorized: false };
    }
    
    return { schemaName, clientConfig: config };
  }

  if (databaseUrl && database && user) {
    const config: any = {
      host: databaseUrl,
      database,
      user,
      password,
      port: portValue ? Number(portValue) : 5432,
    };
    
    if (
      databaseUrl.includes('supabase') || 
      databaseUrl.includes('neon.tech') || 
      databaseUrl.includes('render.com')
    ) {
      config.ssl = { rejectUnauthorized: false };
    }

    return {
      schemaName,
      clientConfig: config,
    };
  }

  if (process.env.DATABASE_URL) {
    return { schemaName, clientConfig: { connectionString: process.env.DATABASE_URL } };
  }

  throw new Error('Postgres settings are required.');
}

async function withPostgres<T>(req: express.Request, callback: (client: pg.Client, schemaName: string) => Promise<T>) {
  const { schemaName, clientConfig } = clientConfigFromRequest(req);
  const client = new Client(clientConfig);
  await client.connect();
  try {
    return await callback(client, schemaName);
  } finally {
    await client.end().catch(() => undefined);
  }
}

async function ensurePostgres(client: pg.Client, schemaName: string) {
  const schema = quoteIdent(schemaName);
  await client.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${schema}.users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT UNIQUE,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${schema}.user_settings (
      user_id TEXT PRIMARY KEY REFERENCES ${schema}.users(id) ON DELETE CASCADE,
      state JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${schema}.chat_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT REFERENCES ${schema}.users(id) ON DELETE CASCADE,
      session JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${schema}.user_oauth_tokens (
      user_id TEXT NOT NULL,
      provider TEXT NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT,
      token_expiry TIMESTAMPTZ,
      scopes TEXT,
      account_email TEXT,
      account_name TEXT,
      account_avatar TEXT,
      raw_profile JSONB DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, provider)
    )
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${schema}.user_oauth_configs (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      provider TEXT NOT NULL,
      client_id TEXT NOT NULL,
      client_secret TEXT NOT NULL,
      enabled BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

function publicUser(row: any) {
  const username = row.username || row.email || 'user';
  return {
    id: row.id,
    username,
    email: row.email || undefined,
    displayName: row.display_name || username,
  };
}

function signToken(userId: string, schemaName: string) {
  return jwt.sign({ sub: userId, schemaName }, jwtSecret, { expiresIn: '365d' });
}

async function authUser(client: pg.Client, req: express.Request, schemaName: string) {
  const authHeader = req.header('authorization') || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!token) throw new Error('Missing auth token.');
  const payload = jwt.verify(token, jwtSecret) as any;
  await ensurePostgres(client, schemaName);
  const schema = quoteIdent(schemaName);
  const result = await client.query(`SELECT * FROM ${schema}.users WHERE id = $1`, [payload.sub]);
  if (result.rowCount === 0) throw new Error('User not found.');
  return { user: result.rows[0], schemaName };
}

async function readState() {
  try {
    const raw = await fs.readFile(dbPath, 'utf8');
    return JSON.parse(raw);
  } catch (error: any) {
    if (error?.code === 'ENOENT') return null;
    throw error;
  }
}

async function writeState(state: unknown) {
  await fs.mkdir(path.dirname(dbPath), { recursive: true });
  const payload = {
    ...(typeof state === 'object' && state !== null ? state : {}),
    savedAt: Date.now(),
  };
  await fs.writeFile(dbPath, JSON.stringify(payload, null, 2));
  return payload;
}

app.get('/api/app-state', async (_req, res, next) => {
  try {
    res.json({ state: await readState() });
  } catch (error) {
    next(error);
  }
});

app.put('/api/app-state', async (req, res, next) => {
  try {
    res.json({ state: await writeState(req.body) });
  } catch (error) {
    next(error);
  }
});

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, dbPath, postgres: Boolean(process.env.DATABASE_URL) });
});

app.get('/api/postgres/schema.sql', (req, res) => {
  const schemaName = schemaNameFromConfig({ schemaName: req.query.schema || process.env.POSTGRES_SCHEMA });
  const schema = quoteIdent(schemaName);
  res.type('text/plain').send(`CREATE SCHEMA IF NOT EXISTS ${schema};

CREATE TABLE IF NOT EXISTS ${schema}.users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ${schema}.user_settings (
  user_id TEXT PRIMARY KEY REFERENCES ${schema}.users(id) ON DELETE CASCADE,
  state JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ${schema}.chat_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES ${schema}.users(id) ON DELETE CASCADE,
  session JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ${schema}.user_oauth_tokens (
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expiry TIMESTAMPTZ,
  scopes TEXT,
  account_email TEXT,
  account_name TEXT,
  account_avatar TEXT,
  raw_profile JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, provider)
);

CREATE TABLE IF NOT EXISTS ${schema}.user_oauth_configs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  provider TEXT NOT NULL,
  client_id TEXT NOT NULL,
  client_secret TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);`);
});

app.post('/api/auth/signup', async (req, res) => {
  try {
    await withPostgres(req, async (client, schemaName) => {
      await ensurePostgres(client, schemaName);
      const schema = quoteIdent(schemaName);
      const username = String(req.body.username || '').trim().toLowerCase();
      const password = String(req.body.password || '');
      if (!/^[a-z0-9._-]{3,64}$/.test(username)) {
        return res.status(400).json({ error: 'Username must be 3-64 characters using letters, numbers, dot, dash, or underscore.' });
      }
      if (password.length < 8) return res.status(400).json({ error: 'Password must be at least 8 characters.' });

      const id = randomUUID();
      const passwordHash = await bcrypt.hash(password, 12);
      const result = await client.query(
        `INSERT INTO ${schema}.users (id, username, display_name, password_hash) VALUES ($1, $2, $3, $4) RETURNING *`,
        [id, username, username, passwordHash],
      );
      await client.query(`INSERT INTO ${schema}.user_settings (user_id, state) VALUES ($1, '{}'::jsonb)`, [id]);
      const user = publicUser(result.rows[0]);
      res.json({ user, token: signToken(user.id, schemaName), state: null });
    });
  } catch (error: any) {
    const message = error?.code === '23505' ? 'Username is already registered.' : error.message || 'Unable to sign up.';
    res.status(400).json({ error: message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    await withPostgres(req, async (client, schemaName) => {
      await ensurePostgres(client, schemaName);
      const schema = quoteIdent(schemaName);
      const username = String(req.body.username || '').trim().toLowerCase();
      const password = String(req.body.password || '');
      const result = await client.query(`SELECT * FROM ${schema}.users WHERE username = $1`, [username]);
      if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid username or password.' });
      const userRow = result.rows[0];
      const isValid = await bcrypt.compare(password, userRow.password_hash);
      if (!isValid) return res.status(401).json({ error: 'Invalid username or password.' });
      const stateResult = await client.query(`SELECT state FROM ${schema}.user_settings WHERE user_id = $1`, [userRow.id]);
      const user = publicUser(userRow);
      res.json({ user, token: signToken(user.id, schemaName), state: stateResult.rows[0]?.state || null });
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Unable to log in.' });
  }
});

app.get('/api/sync/pull', async (req, res) => {
  try {
    await withPostgres(req, async (client, schemaName) => {
      const { user } = await authUser(client, req, schemaName);
      const schema = quoteIdent(schemaName);
      const settingsResult = await client.query(`SELECT state FROM ${schema}.user_settings WHERE user_id = $1`, [user.id]);
      const sessionsResult = await client.query(`SELECT id, session FROM ${schema}.chat_sessions WHERE user_id = $1`, [user.id]);
      
      res.json({ 
        settings: settingsResult.rows[0]?.state || null,
        sessions: sessionsResult.rows.map(r => ({ id: r.id, session: r.session }))
      });
    });
  } catch (error: any) {
    res.status(401).json({ error: error.message || 'Unable to pull sync state.' });
  }
});

app.post('/api/sync/pull', async (req, res) => {
  try {
    await withPostgres(req, async (client, schemaName) => {
      const { user } = await authUser(client, req, schemaName);
      const schema = quoteIdent(schemaName);
      const settingsResult = await client.query(`SELECT state FROM ${schema}.user_settings WHERE user_id = $1`, [user.id]);
      const sessionsResult = await client.query(`SELECT id, session FROM ${schema}.chat_sessions WHERE user_id = $1`, [user.id]);
      
      res.json({ 
        settings: settingsResult.rows[0]?.state || null,
        sessions: sessionsResult.rows.map(r => ({ id: r.id, session: r.session }))
      });
    });
  } catch (error: any) {
    res.status(401).json({ error: error.message || 'Unable to pull sync state.' });
  }
});

app.put('/api/sync/push', async (req, res) => {
  try {
    await withPostgres(req, async (client, schemaName) => {
      const { user } = await authUser(client, req, schemaName);
      const schema = quoteIdent(schemaName);
      const { settings, sessions } = req.body;
      
      await client.query('BEGIN');
      
      if (settings) {
        await client.query(
          `INSERT INTO ${schema}.user_settings (user_id, state, updated_at)
           VALUES ($1, $2::jsonb, NOW())
           ON CONFLICT (user_id) DO UPDATE SET state = EXCLUDED.state, updated_at = NOW()`,
          [user.id, JSON.stringify(settings)],
        );
      }
      
      if (Array.isArray(sessions)) {
        for (const s of sessions) {
          if (!s.id || !s.session) continue;
          await client.query(
            `INSERT INTO ${schema}.chat_sessions (id, user_id, session, updated_at)
             VALUES ($1, $2, $3::jsonb, NOW())
             ON CONFLICT (id) DO UPDATE SET session = EXCLUDED.session, updated_at = NOW()`,
            [s.id, user.id, JSON.stringify(s.session)],
          );
        }
      }
      
      await client.query('COMMIT');
      res.json({ ok: true });
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Unable to save sync state.' });
  }
});

app.put('/api/sync/backup', async (req, res) => {
  try {
    const { primaryDbConfig, backupDbConfig, state } = req.body;
    if (!primaryDbConfig || !backupDbConfig || !state) {
      return res.status(400).json({ error: 'Missing required fields for backup.' });
    }

    let userRow: any;

    const originalDbConfig = req.body.dbConfig;
    
    try {
      req.body.dbConfig = primaryDbConfig;
      await withPostgres(req, async (primaryClient, primarySchemaName) => {
        const authUserResult = await authUser(primaryClient, req, primarySchemaName);
        userRow = authUserResult.user;
      });

      if (!userRow) throw new Error('Could not fetch user from primary database.');

      req.body.dbConfig = backupDbConfig;
      await withPostgres(req, async (backupClient, backupSchemaName) => {
      await ensurePostgres(backupClient, backupSchemaName);
      const schema = quoteIdent(backupSchemaName);
      
      await backupClient.query(
        `INSERT INTO ${schema}.users (id, username, email, display_name, password_hash)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (id) DO UPDATE SET 
           username = EXCLUDED.username,
           email = EXCLUDED.email,
           display_name = EXCLUDED.display_name,
           password_hash = EXCLUDED.password_hash,
           updated_at = NOW()`,
        [userRow.id, userRow.username, userRow.email, userRow.display_name, userRow.password_hash]
      );

      await backupClient.query(
        `INSERT INTO ${schema}.user_settings (user_id, state, updated_at)
         VALUES ($1, $2::jsonb, NOW())
         ON CONFLICT (user_id) DO UPDATE SET state = EXCLUDED.state, updated_at = NOW()`,
        [userRow.id, JSON.stringify(state)],
      );
      
      res.json({ ok: true });
    });
    } finally {
      req.body.dbConfig = originalDbConfig;
    }
  } catch (error: any) {
    console.error('Backup error:', error);
    res.status(400).json({ error: error.message || 'Unable to save backup state.' });
  }
});

// ============================================================================
// OAuth 2.0 & Plugins Integration Gateway
// ============================================================================

const ENCRYPTION_KEY = crypto.scryptSync(jwtSecret, 'adoetzgpt-token-salt-v1', 32);

function encryptToken(plainText: string): string {
  if (!plainText) return '';
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
  let encrypted = cipher.update(plainText, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

function decryptToken(cipherText: string): string {
  if (!cipherText) return '';
  const parts = cipherText.split(':');
  if (parts.length !== 3) return cipherText;
  const [ivHex, authTagHex, encrypted] = parts;
  try {
    const decipher = crypto.createDecipheriv('aes-256-gcm', ENCRYPTION_KEY, Buffer.from(ivHex, 'hex'));
    decipher.setAuthTag(Buffer.from(authTagHex, 'hex'));
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    console.error('Failed to decrypt token:', err);
    return cipherText;
  }
}

function getUserIdFromReq(req: express.Request): string {
  const authHeader = req.header('authorization') || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (token) {
    try {
      const payload = jwt.verify(token, jwtSecret) as any;
      if (payload?.sub) return String(payload.sub);
    } catch (_) {
      try {
        const decoded = jwt.decode(token) as any;
        if (decoded?.sub) return String(decoded.sub);
      } catch (_) {}
    }
  }
  const queryToken = String(req.query.token || '');
  if (queryToken) {
    try {
      const payload = jwt.verify(queryToken, jwtSecret) as any;
      if (payload?.sub) return String(payload.sub);
    } catch (_) {
      try {
        const decoded = jwt.decode(queryToken) as any;
        if (decoded?.sub) return String(decoded.sub);
      } catch (_) {}
    }
  }
  const queryUser = String(req.query.userId || req.body?.userId || req.header('x-user-id') || '').trim();
  if (queryUser) return queryUser;
  return 'default-user';
}

interface StoredOAuthToken {
  userId: string;
  provider: string;
  accessToken: string;
  refreshToken?: string;
  tokenExpiry?: number;
  scopes?: string;
  accountEmail?: string;
  accountName?: string;
  accountAvatar?: string;
  rawProfile?: any;
  updatedAt: number;
}

async function getStoredToken(userId: string, provider: string): Promise<StoredOAuthToken | null> {
  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        let res = await client.query(
          `SELECT * FROM ${schema}.user_oauth_tokens WHERE user_id = $1 AND provider = $2`,
          [userId, provider]
        );
        if (res.rows.length === 0) {
          res = await client.query(
            `SELECT * FROM ${schema}.user_oauth_tokens WHERE provider = $1 ORDER BY updated_at DESC LIMIT 1`,
            [provider]
          );
        }
        if (res.rows.length > 0) {
          const r = res.rows[0];
          return {
            userId: r.user_id,
            provider: r.provider,
            accessToken: r.access_token,
            refreshToken: r.refresh_token,
            tokenExpiry: r.token_expiry ? new Date(r.token_expiry).getTime() : undefined,
            scopes: r.scopes,
            accountEmail: r.account_email,
            accountName: r.account_name,
            accountAvatar: r.account_avatar,
            rawProfile: r.raw_profile,
            updatedAt: r.updated_at ? new Date(r.updated_at).getTime() : Date.now(),
          };
        }
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres getStoredToken failed, checking local file state:', e);
    }
  }

  const state = (await readState()) || {};
  let tokens = state._oauthTokens?.[userId]?.[provider];
  if (!tokens && state._oauthTokens) {
    // Fallback: search across all users for this provider
    for (const [uid, userTokens] of Object.entries(state._oauthTokens as Record<string, any>)) {
      if (userTokens?.[provider]) {
        tokens = userTokens[provider];
        break;
      }
    }
  }
  if (!tokens) return null;
  return tokens;
}

async function saveStoredToken(tokenData: StoredOAuthToken): Promise<void> {
  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        await client.query(
          `INSERT INTO ${schema}.user_oauth_tokens
           (user_id, provider, access_token, refresh_token, token_expiry, scopes, account_email, account_name, account_avatar, raw_profile, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
           ON CONFLICT (user_id, provider) DO UPDATE SET
             access_token = EXCLUDED.access_token,
             refresh_token = COALESCE(EXCLUDED.refresh_token, ${schema}.user_oauth_tokens.refresh_token),
             token_expiry = EXCLUDED.token_expiry,
             scopes = EXCLUDED.scopes,
             account_email = EXCLUDED.account_email,
             account_name = EXCLUDED.account_name,
             account_avatar = EXCLUDED.account_avatar,
             raw_profile = EXCLUDED.raw_profile,
             updated_at = NOW()`,
          [
            tokenData.userId,
            tokenData.provider,
            tokenData.accessToken,
            tokenData.refreshToken || null,
            tokenData.tokenExpiry ? new Date(tokenData.tokenExpiry) : null,
            tokenData.scopes || null,
            tokenData.accountEmail || null,
            tokenData.accountName || null,
            tokenData.accountAvatar || null,
            JSON.stringify(tokenData.rawProfile || {}),
          ]
        );
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres saveStoredToken failed, saving to local file state:', e);
    }
  }

  const state = (await readState()) || {};
  if (!state._oauthTokens) state._oauthTokens = {};
  if (!state._oauthTokens[tokenData.userId]) state._oauthTokens[tokenData.userId] = {};
  state._oauthTokens[tokenData.userId][tokenData.provider] = tokenData;
  await writeState(state);
}

async function deleteStoredToken(userId: string, provider: string): Promise<void> {
  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        await client.query(
          `DELETE FROM ${schema}.user_oauth_tokens WHERE user_id = $1 AND provider = $2`,
          [userId, provider]
        );
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres deleteStoredToken failed:', e);
    }
  }

  const state = (await readState()) || {};
  if (state._oauthTokens?.[userId]?.[provider]) {
    delete state._oauthTokens[userId][provider];
    await writeState(state);
  }
}

async function listStoredTokens(userId: string): Promise<Record<string, any>> {
  const result: Record<string, any> = {
    google: { connected: false },
    github: { connected: false },
  };

  for (const provider of ['google', 'github']) {
    const token = await getStoredToken(userId, provider);
    if (token && token.accessToken) {
      result[provider] = {
        connected: true,
        email: token.accountEmail,
        name: token.accountName,
        username: token.accountName,
        avatarUrl: token.accountAvatar,
        expiresAt: token.tokenExpiry,
        scopes: token.scopes,
      };
    }
  }
  return result;
}

interface StoredOAuthConfig {
  id: string;
  userId: string;
  name: string;
  provider: string;
  clientId: string;
  clientSecret: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}

function maskSecret(secret: string): string {
  if (!secret) return '';
  const decrypted = decryptToken(secret);
  if (!decrypted) return '';
  if (decrypted.length <= 8) return '••••••••';
  return decrypted.slice(0, 4) + '••••••••' + decrypted.slice(-4);
}

async function getOAuthConfigs(userId: string): Promise<StoredOAuthConfig[]> {
  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        const res = await client.query(
          `SELECT * FROM ${schema}.user_oauth_configs WHERE user_id = $1 ORDER BY created_at ASC`,
          [userId]
        );
        return res.rows.map((r: any) => ({
          id: r.id,
          userId: r.user_id,
          name: r.name,
          provider: r.provider,
          clientId: r.client_id,
          clientSecret: r.client_secret,
          enabled: Boolean(r.enabled),
          createdAt: r.created_at ? new Date(r.created_at).getTime() : Date.now(),
          updatedAt: r.updated_at ? new Date(r.updated_at).getTime() : Date.now(),
        }));
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres getOAuthConfigs failed, falling back to local state:', e);
    }
  }

  const state = (await readState()) || {};
  const list: StoredOAuthConfig[] = state._oauthConfigs?.[userId] || [];
  return list;
}

async function saveOAuthConfig(
  userId: string,
  data: { id?: string; name: string; provider: string; clientId: string; clientSecret?: string; enabled?: boolean }
): Promise<StoredOAuthConfig> {
  const existingConfigs = await getOAuthConfigs(userId);
  const id = data.id || randomUUID();
  const existing = existingConfigs.find((c) => c.id === id);

  let encryptedSecret = existing?.clientSecret || '';
  if (data.clientSecret && !data.clientSecret.includes('••••')) {
    encryptedSecret = encryptToken(data.clientSecret);
  }

  const isEnabled = data.enabled !== undefined ? Boolean(data.enabled) : (existing ? existing.enabled : true);

  const config: StoredOAuthConfig = {
    id,
    userId,
    name: data.name.trim(),
    provider: data.provider.toLowerCase().trim(),
    clientId: data.clientId.trim(),
    clientSecret: encryptedSecret,
    enabled: isEnabled,
    createdAt: existing?.createdAt || Date.now(),
    updatedAt: Date.now(),
  };

  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        if (config.enabled) {
          await client.query(
            `UPDATE ${schema}.user_oauth_configs SET enabled = false WHERE user_id = $1 AND provider = $2`,
            [userId, config.provider]
          );
        }
        await client.query(
          `INSERT INTO ${schema}.user_oauth_configs (id, user_id, name, provider, client_id, client_secret, enabled, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
           ON CONFLICT (id) DO UPDATE SET
             name = EXCLUDED.name,
             provider = EXCLUDED.provider,
             client_id = EXCLUDED.client_id,
             client_secret = CASE WHEN EXCLUDED.client_secret = '' THEN ${schema}.user_oauth_configs.client_secret ELSE EXCLUDED.client_secret END,
             enabled = EXCLUDED.enabled,
             updated_at = NOW()`,
          [
            config.id,
            config.userId,
            config.name,
            config.provider,
            config.clientId,
            config.clientSecret,
            config.enabled,
            new Date(config.createdAt),
          ]
        );
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres saveOAuthConfig failed:', e);
    }
  }

  const state = (await readState()) || {};
  if (!state._oauthConfigs) state._oauthConfigs = {};
  if (!state._oauthConfigs[userId]) state._oauthConfigs[userId] = [];

  let list: StoredOAuthConfig[] = state._oauthConfigs[userId];
  if (config.enabled) {
    list = list.map((c) => (c.provider === config.provider ? { ...c, enabled: false } : c));
  }
  const idx = list.findIndex((c) => c.id === config.id);
  if (idx >= 0) {
    list[idx] = config;
  } else {
    list.push(config);
  }
  state._oauthConfigs[userId] = list;
  await writeState(state);

  return config;
}

async function deleteOAuthConfig(userId: string, id: string): Promise<void> {
  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        await client.query(
          `DELETE FROM ${schema}.user_oauth_configs WHERE user_id = $1 AND id = $2`,
          [userId, id]
        );
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres deleteOAuthConfig failed:', e);
    }
  }

  const state = (await readState()) || {};
  if (state._oauthConfigs?.[userId]) {
    state._oauthConfigs[userId] = state._oauthConfigs[userId].filter((c: StoredOAuthConfig) => c.id !== id);
    await writeState(state);
  }
}

async function toggleOAuthConfig(userId: string, id: string): Promise<StoredOAuthConfig | null> {
  const configs = await getOAuthConfigs(userId);
  const target = configs.find((c) => c.id === id);
  if (!target) return null;

  const newEnabled = !target.enabled;

  if (process.env.DATABASE_URL) {
    try {
      const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
      });
      await client.connect();
      try {
        const schema = quoteIdent(process.env.POSTGRES_SCHEMA || 'adoetzgpt');
        if (newEnabled) {
          await client.query(
            `UPDATE ${schema}.user_oauth_configs SET enabled = false WHERE user_id = $1 AND provider = $2`,
            [userId, target.provider]
          );
        }
        await client.query(
          `UPDATE ${schema}.user_oauth_configs SET enabled = $1, updated_at = NOW() WHERE user_id = $2 AND id = $3`,
          [newEnabled, userId, id]
        );
      } finally {
        await client.end();
      }
    } catch (e) {
      console.warn('Postgres toggleOAuthConfig failed:', e);
    }
  }

  const state = (await readState()) || {};
  if (state._oauthConfigs?.[userId]) {
    state._oauthConfigs[userId] = state._oauthConfigs[userId].map((c: StoredOAuthConfig) => {
      if (newEnabled && c.provider === target.provider) {
        return { ...c, enabled: c.id === id };
      }
      if (c.id === id) {
        return { ...c, enabled: newEnabled };
      }
      return c;
    });
    await writeState(state);
  }

  return { ...target, enabled: newEnabled };
}

async function getActiveOAuthConfig(userId: string, provider: string): Promise<{ clientId: string; clientSecret: string; source: 'app' | 'env' } | null> {
  const configs = await getOAuthConfigs(userId);
  let active = configs.find((c) => c.provider.toLowerCase() === provider.toLowerCase() && c.enabled);

  if (!active) {
    const state = (await readState()) || {};
    if (state._oauthConfigs) {
      for (const [uid, userConfigs] of Object.entries(state._oauthConfigs as Record<string, any>)) {
        if (Array.isArray(userConfigs)) {
          const found = userConfigs.find((c: StoredOAuthConfig) => c.provider.toLowerCase() === provider.toLowerCase() && c.enabled);
          if (found && found.clientId) {
            active = found;
            break;
          }
        }
      }
    }
  }

  if (active && active.clientId) {
    const decryptedSecret = decryptToken(active.clientSecret);
    return {
      clientId: active.clientId,
      clientSecret: decryptedSecret,
      source: 'app',
    };
  }

  if (provider === 'google') {
    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    if (clientId && clientSecret) {
      return { clientId, clientSecret, source: 'env' };
    }
  } else if (provider === 'github') {
    const clientId = process.env.GITHUB_CLIENT_ID;
    const clientSecret = process.env.GITHUB_CLIENT_SECRET;
    if (clientId && clientSecret) {
      return { clientId, clientSecret, source: 'env' };
    }
  }

  return null;
}

async function getValidAccessToken(userId: string, provider: string): Promise<string> {
  const tokenRecord = await getStoredToken(userId, provider);
  if (!tokenRecord || !tokenRecord.accessToken) {
    throw new Error(`Provider "${provider}" is not connected. Please connect it via the Plugins menu.`);
  }

  const decryptedAccess = decryptToken(tokenRecord.accessToken);
  const now = Date.now();

  // If token has expiry and will expire within 5 minutes (300,000 ms), auto-refresh
  if (provider === 'google' && tokenRecord.tokenExpiry && tokenRecord.tokenExpiry - now < 300000) {
    if (tokenRecord.refreshToken) {
      const decryptedRefresh = decryptToken(tokenRecord.refreshToken);
      const oauthConfig = await getActiveOAuthConfig(userId, 'google');
      const clientId = oauthConfig?.clientId;
      const clientSecret = oauthConfig?.clientSecret;

      if (clientId && clientSecret) {
        try {
          const refreshRes = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
              client_id: clientId,
              client_secret: clientSecret,
              refresh_token: decryptedRefresh,
              grant_type: 'refresh_token',
            }),
          });

          if (refreshRes.ok) {
            const tokenJson = (await refreshRes.json()) as any;
            const newAccessToken = tokenJson.access_token;
            const expiresIn = Number(tokenJson.expires_in || 3600);
            tokenRecord.accessToken = encryptToken(newAccessToken);
            tokenRecord.tokenExpiry = Date.now() + expiresIn * 1000;
            if (tokenJson.refresh_token) {
              tokenRecord.refreshToken = encryptToken(tokenJson.refresh_token);
            }
            tokenRecord.updatedAt = Date.now();
            await saveStoredToken(tokenRecord);
            return newAccessToken;
          } else {
            console.error('Google token refresh failed:', await refreshRes.text());
          }
        } catch (err) {
          console.error('Error refreshing Google token:', err);
        }
      }
    }
  }

  return decryptedAccess;
}

// OAuth Authorize endpoint
app.get('/api/auth/oauth/:provider/authorize', async (req, res) => {
  const provider = req.params.provider.toLowerCase();
  const userId = getUserIdFromReq(req);

  const protocol = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.get('host');
  const redirectUri = `${protocol}://${host}/api/auth/oauth/${provider}/callback`;
  const state = jwt.sign({ userId, provider, nonce: randomUUID() }, jwtSecret, { expiresIn: '15m' });

  const oauthConfig = await getActiveOAuthConfig(userId, provider);

  if (provider === 'google') {
    const clientId = oauthConfig?.clientId;
    if (!clientId) {
      return res.status(400).send(`
        <html><body style="font-family:sans-serif;padding:30px;background:#0f172a;color:#f8fafc;">
          <h2>Google OAuth Setup Needed</h2>
          <p>Please configure a Google OAuth Client in App Settings under <b>OAuth Apps</b>, or provide <code>GOOGLE_CLIENT_ID</code> and <code>GOOGLE_CLIENT_SECRET</code> in your <code>.env</code> file.</p>
          <p>Redirect URI configured for Google Cloud Console: <code>${redirectUri}</code></p>
        </body></html>
      `);
    }

    const scopes = [
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/drive',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/tasks',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/documents',
      'openid',
      'email',
      'profile',
    ].join(' ');

    const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
    authUrl.searchParams.set('client_id', clientId);
    authUrl.searchParams.set('redirect_uri', redirectUri);
    authUrl.searchParams.set('response_type', 'code');
    authUrl.searchParams.set('scope', scopes);
    authUrl.searchParams.set('access_type', 'offline');
    authUrl.searchParams.set('prompt', 'consent');
    authUrl.searchParams.set('state', state);

    return res.redirect(authUrl.toString());
  }

  if (provider === 'github') {
    const clientId = oauthConfig?.clientId;
    if (!clientId) {
      return res.status(400).send(`
        <html><body style="font-family:sans-serif;padding:30px;background:#0f172a;color:#f8fafc;">
          <h2>GitHub OAuth Setup Needed</h2>
          <p>Please configure a GitHub OAuth App in App Settings under <b>OAuth Apps</b>, or provide <code>GITHUB_CLIENT_ID</code> and <code>GITHUB_CLIENT_SECRET</code> in your <code>.env</code> file.</p>
          <p>Callback URL configured for GitHub Developer settings: <code>${redirectUri}</code></p>
        </body></html>
      `);
    }

    const scopes = 'repo read:user user:email';
    const authUrl = new URL('https://github.com/login/oauth/authorize');
    authUrl.searchParams.set('client_id', clientId);
    authUrl.searchParams.set('redirect_uri', redirectUri);
    authUrl.searchParams.set('scope', scopes);
    authUrl.searchParams.set('state', state);

    return res.redirect(authUrl.toString());
  }

  res.status(400).json({ error: `Unsupported OAuth provider: ${provider}` });
});

// OAuth Callback endpoint
app.get('/api/auth/oauth/:provider/callback', async (req, res) => {
  const provider = req.params.provider.toLowerCase();
  const code = String(req.query.code || '');
  const stateStr = String(req.query.state || '');

  if (!code || !stateStr) {
    return res.status(400).send('Missing code or state parameter.');
  }

  let statePayload: any;
  try {
    statePayload = jwt.verify(stateStr, jwtSecret);
  } catch (err) {
    return res.status(400).send('Invalid or expired OAuth state.');
  }

  const userId = statePayload.userId || 'default-user';
  const protocol = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.get('host');
  const redirectUri = `${protocol}://${host}/api/auth/oauth/${provider}/callback`;

  const oauthConfig = await getActiveOAuthConfig(userId, provider);
  if (!oauthConfig || !oauthConfig.clientId || !oauthConfig.clientSecret) {
    return res.status(400).send(`Missing OAuth credentials for ${provider}. Please configure them in App Settings under OAuth Apps, or set them in .env.`);
  }
  const { clientId, clientSecret } = oauthConfig;

  try {
    if (provider === 'google') {
      const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          code,
          client_id: clientId,
          client_secret: clientSecret,
          redirect_uri: redirectUri,
          grant_type: 'authorization_code',
        }),
      });

      if (!tokenRes.ok) {
        const errorText = await tokenRes.text();
        return res.status(400).send(`Google OAuth token exchange failed: ${errorText}`);
      }

      const tokenJson = (await tokenRes.json()) as any;
      const accessToken = tokenJson.access_token;
      const refreshToken = tokenJson.refresh_token;
      const expiresIn = Number(tokenJson.expires_in || 3600);

      // Fetch user profile
      let profile: any = {};
      try {
        const userRes = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (userRes.ok) {
          profile = await userRes.json();
        }
      } catch (e) {
        console.warn('Could not fetch Google profile:', e);
      }

      await saveStoredToken({
        userId,
        provider: 'google',
        accessToken: encryptToken(accessToken),
        refreshToken: refreshToken ? encryptToken(refreshToken) : undefined,
        tokenExpiry: Date.now() + expiresIn * 1000,
        scopes: tokenJson.scope,
        accountEmail: profile.email,
        accountName: profile.name,
        accountAvatar: profile.picture,
        rawProfile: profile,
        updatedAt: Date.now(),
      });
    } else if (provider === 'github') {
      const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          client_id: clientId,
          client_secret: clientSecret,
          code,
          redirect_uri: redirectUri,
        }),
      });

      if (!tokenRes.ok) {
        const errorText = await tokenRes.text();
        return res.status(400).send(`GitHub OAuth token exchange failed: ${errorText}`);
      }

      const tokenJson = (await tokenRes.json()) as any;
      if (tokenJson.error) {
        return res.status(400).send(`GitHub OAuth error: ${tokenJson.error_description || tokenJson.error}`);
      }

      const accessToken = tokenJson.access_token;

      // Fetch GitHub profile
      let profile: any = {};
      try {
        const userRes = await fetch('https://api.github.com/user', {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'User-Agent': 'AdoetzGPT',
          },
        });
        if (userRes.ok) {
          profile = await userRes.json();
        }
      } catch (e) {
        console.warn('Could not fetch GitHub profile:', e);
      }

      // Fetch emails if profile email is null
      if (!profile.email) {
        try {
          const emailRes = await fetch('https://api.github.com/user/emails', {
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'User-Agent': 'AdoetzGPT',
            },
          });
          if (emailRes.ok) {
            const emails = (await emailRes.json()) as any[];
            const primary = emails.find((e) => e.primary);
            profile.email = primary?.email || emails[0]?.email;
          }
        } catch (_) {}
      }

      await saveStoredToken({
        userId,
        provider: 'github',
        accessToken: encryptToken(accessToken),
        scopes: tokenJson.scope,
        accountEmail: profile.email,
        accountName: profile.login || profile.name,
        accountAvatar: profile.avatar_url,
        rawProfile: profile,
        updatedAt: Date.now(),
      });
    }

    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>OAuth Success</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; background: #0b0f19; color: #f1f5f9; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 32px; max-width: 420px; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
          h2 { color: #38bdf8; margin-top: 0; }
          p { color: #94a3b8; font-size: 15px; line-height: 1.5; }
          .success-badge { display: inline-block; background: #10b98122; color: #10b981; border: 1px solid #10b98155; padding: 6px 16px; border-radius: 9999px; font-weight: 600; font-size: 14px; margin-bottom: 16px; }
          .close-btn { display: inline-block; margin-top: 20px; background: #38bdf8; color: #0f172a; padding: 10px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="success-badge">✓ Connected Successfully</div>
          <h2>${provider.charAt(0).toUpperCase() + provider.slice(1)} Connected</h2>
          <p>Your account is now linked with AdoetzGPT. You can close this window and continue using your AI assistant.</p>
          <a href="javascript:window.close()" class="close-btn">Close Window</a>
        </div>
        <script>
          if (window.opener) {
            try {
              window.opener.postMessage({ type: 'oauth_complete', provider: '${provider}', status: 'success' }, '*');
            } catch (e) {}
            setTimeout(() => {
              window.close();
            }, 1200);
          }
        </script>
      </body>
      </html>
    `);
  } catch (err: any) {
    console.error('OAuth callback error:', err);
    res.status(500).send(`OAuth authorization error: ${err.message || String(err)}`);
  }
});

// OAuth Status endpoint
app.get('/api/auth/oauth/status', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const statuses = await listStoredTokens(userId);
    res.json(statuses);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// OAuth Disconnect endpoint
app.post('/api/auth/oauth/:provider/disconnect', async (req, res) => {
  try {
    const provider = req.params.provider.toLowerCase();
    const userId = getUserIdFromReq(req);
    await deleteStoredToken(userId, provider);
    res.json({ ok: true, provider, connected: false });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================================
// OAuth App Configuration Management Endpoints
// ============================================================================

// List all OAuth App configs for user
app.get('/api/auth/oauth/apps', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const configs = await getOAuthConfigs(userId);
    res.json({
      configs: configs.map((c) => ({
        id: c.id,
        userId: c.userId,
        name: c.name,
        provider: c.provider,
        clientId: c.clientId,
        clientSecret: maskSecret(c.clientSecret),
        hasSecret: Boolean(c.clientSecret),
        enabled: c.enabled,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      })),
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create or update an OAuth App config
app.post('/api/auth/oauth/apps', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { id, name, provider, clientId, clientSecret, enabled } = req.body || {};
    if (!name || !provider || !clientId) {
      return res.status(400).json({ error: 'Name, provider, and clientId are required.' });
    }
    const saved = await saveOAuthConfig(userId, {
      id,
      name,
      provider,
      clientId,
      clientSecret,
      enabled: enabled !== undefined ? Boolean(enabled) : true,
    });
    res.json({
      config: {
        id: saved.id,
        userId: saved.userId,
        name: saved.name,
        provider: saved.provider,
        clientId: saved.clientId,
        clientSecret: maskSecret(saved.clientSecret),
        hasSecret: Boolean(saved.clientSecret),
        enabled: saved.enabled,
        createdAt: saved.createdAt,
        updatedAt: saved.updatedAt,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Delete an OAuth App config
app.delete('/api/auth/oauth/apps/:id', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const id = req.params.id;
    await deleteOAuthConfig(userId, id);
    res.json({ ok: true, id });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Toggle active OAuth App config
app.post('/api/auth/oauth/apps/:id/toggle', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const id = req.params.id;
    const toggled = await toggleOAuthConfig(userId, id);
    if (!toggled) {
      return res.status(404).json({ error: 'OAuth app config not found.' });
    }
    res.json({
      ok: true,
      config: {
        id: toggled.id,
        userId: toggled.userId,
        name: toggled.name,
        provider: toggled.provider,
        clientId: toggled.clientId,
        clientSecret: maskSecret(toggled.clientSecret),
        hasSecret: Boolean(toggled.clientSecret),
        enabled: toggled.enabled,
        createdAt: toggled.createdAt,
        updatedAt: toggled.updatedAt,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Batch sync OAuth App configs from app
app.post('/api/auth/oauth/sync-apps', async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { configs } = req.body || {};
    if (Array.isArray(configs)) {
      for (const item of configs) {
        if (item.name && item.provider && item.clientId) {
          await saveOAuthConfig(userId, {
            id: item.id,
            name: item.name,
            provider: item.provider,
            clientId: item.clientId,
            clientSecret: item.clientSecret,
            enabled: item.enabled,
          });
        }
      }
    }
    const current = await getOAuthConfigs(userId);
    res.json({
      ok: true,
      configs: current.map((c) => ({
        id: c.id,
        userId: c.userId,
        name: c.name,
        provider: c.provider,
        clientId: c.clientId,
        clientSecret: maskSecret(c.clientSecret),
        hasSecret: Boolean(c.clientSecret),
        enabled: c.enabled,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      })),
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================================
// Unified Plugin Tool Calling RPC Gateway
// ============================================================================

app.post('/api/integrations/execute-tool', async (req, res) => {
  const { tool, parameters } = req.body || {};
  if (!tool) {
    return res.status(400).json({ ok: false, error: 'Missing "tool" parameter in request body.' });
  }

  const userId = getUserIdFromReq(req);
  const params = parameters || {};

  try {
    // 1. Google Gmail Tools
    if (tool.startsWith('gmail_')) {
      const accessToken = await getValidAccessToken(userId, 'google');

      if (tool === 'gmail_list_messages') {
        const q = encodeURIComponent(String(params.q || ''));
        const maxResults = Math.min(Number(params.maxResults || 10), 25);
        const listUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=${maxResults}${q ? '&q=' + q : ''}`;
        const listRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!listRes.ok) throw new Error(`Gmail API error: ${await listRes.text()}`);
        const listData = (await listRes.json()) as any;

        const messages: any[] = [];
        if (listData.messages && Array.isArray(listData.messages)) {
          for (const msg of listData.messages.slice(0, 5)) {
            try {
              const msgRes = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date`, {
                headers: { Authorization: `Bearer ${accessToken}` },
              });
              if (msgRes.ok) {
                const msgData = (await msgRes.json()) as any;
                const headers = msgData.payload?.headers || [];
                messages.push({
                  id: msg.id,
                  threadId: msg.threadId,
                  snippet: msgData.snippet,
                  subject: headers.find((h: any) => h.name === 'Subject')?.value || '(No Subject)',
                  from: headers.find((h: any) => h.name === 'From')?.value || '',
                  date: headers.find((h: any) => h.name === 'Date')?.value || '',
                });
              }
            } catch (_) {}
          }
        }
        return res.json({ ok: true, tool, result: { totalEstimated: listData.resultSizeEstimate, messages } });
      }

      if (tool === 'gmail_get_message') {
        const msgId = String(params.messageId || '');
        if (!msgId) throw new Error('Missing messageId parameter.');
        const msgRes = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msgId}?format=full`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!msgRes.ok) throw new Error(`Gmail API error: ${await msgRes.text()}`);
        const data = (await msgRes.json()) as any;
        const headers = data.payload?.headers || [];

        let bodyText = data.snippet || '';
        if (data.payload?.body?.data) {
          bodyText = Buffer.from(data.payload.body.data, 'base64').toString('utf8');
        } else if (data.payload?.parts) {
          const textPart = data.payload.parts.find((p: any) => p.mimeType === 'text/plain');
          if (textPart?.body?.data) {
            bodyText = Buffer.from(textPart.body.data, 'base64').toString('utf8');
          }
        }

        return res.json({
          ok: true,
          tool,
          result: {
            id: data.id,
            threadId: data.threadId,
            snippet: data.snippet,
            subject: headers.find((h: any) => h.name === 'Subject')?.value || '',
            from: headers.find((h: any) => h.name === 'From')?.value || '',
            to: headers.find((h: any) => h.name === 'To')?.value || '',
            date: headers.find((h: any) => h.name === 'Date')?.value || '',
            body: bodyText,
          },
        });
      }

      if (tool === 'gmail_send_email') {
        const to = String(params.to || '').trim();
        const subject = String(params.subject || '').trim();
        const body = String(params.body || '');
        if (!to) throw new Error('Missing "to" recipient parameter.');

        const rfcEmail = [
          `To: ${to}`,
          `Subject: =?utf-8?B?${Buffer.from(subject).toString('base64')}?=`,
          'MIME-Version: 1.0',
          'Content-Type: text/plain; charset=utf-8',
          '',
          body,
        ].join('\r\n');

        const base64Email = Buffer.from(rfcEmail).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        const sendRes = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ raw: base64Email }),
        });

        if (!sendRes.ok) throw new Error(`Gmail send error: ${await sendRes.text()}`);
        return res.json({ ok: true, tool, result: await sendRes.json() });
      }

      if (tool === 'gmail_create_draft') {
        const to = String(params.to || '').trim();
        const subject = String(params.subject || '').trim();
        const body = String(params.body || '');

        const rfcEmail = [
          `To: ${to}`,
          `Subject: =?utf-8?B?${Buffer.from(subject).toString('base64')}?=`,
          'MIME-Version: 1.0',
          'Content-Type: text/plain; charset=utf-8',
          '',
          body,
        ].join('\r\n');

        const base64Email = Buffer.from(rfcEmail).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        const draftRes = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/drafts', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ message: { raw: base64Email } }),
        });

        if (!draftRes.ok) throw new Error(`Gmail draft error: ${await draftRes.text()}`);
        return res.json({ ok: true, tool, result: await draftRes.json() });
      }
    }

    // 2. Google Drive Tools
    if (tool.startsWith('drive_')) {
      const accessToken = await getValidAccessToken(userId, 'google');

      if (tool === 'drive_list_files') {
        const query = String(params.query || 'trashed = false');
        const pageSize = Math.min(Number(params.pageSize || 15), 30);
        const url = `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(query)}&pageSize=${pageSize}&fields=files(id,name,mimeType,modifiedTime,size,webViewLink)`;
        const driveRes = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!driveRes.ok) throw new Error(`Drive API error: ${await driveRes.text()}`);
        return res.json({ ok: true, tool, result: await driveRes.json() });
      }

      if (tool === 'drive_get_file_metadata') {
        const fileId = String(params.fileId || '');
        if (!fileId) throw new Error('Missing fileId parameter.');
        const url = `https://www.googleapis.com/drive/v3/files/${fileId}?fields=id,name,mimeType,description,starred,trashed,parents,createdTime,modifiedTime,size,webViewLink,owners`;
        const fileRes = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!fileRes.ok) throw new Error(`Drive API error: ${await fileRes.text()}`);
        return res.json({ ok: true, tool, result: await fileRes.json() });
      }

      if (tool === 'drive_read_file_content') {
        const fileId = String(params.fileId || '');
        if (!fileId) throw new Error('Missing fileId parameter.');

        // First check mimeType
        const metaRes = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?fields=mimeType,name`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!metaRes.ok) throw new Error(`Drive metadata error: ${await metaRes.text()}`);
        const meta = (await metaRes.json()) as any;

        let contentUrl = `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`;
        if (meta.mimeType === 'application/vnd.google-apps.document') {
          contentUrl = `https://www.googleapis.com/drive/v3/files/${fileId}/export?mimeType=text/plain`;
        } else if (meta.mimeType === 'application/vnd.google-apps.spreadsheet') {
          contentUrl = `https://www.googleapis.com/drive/v3/files/${fileId}/export?mimeType=text/csv`;
        }

        const contentRes = await fetch(contentUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!contentRes.ok) throw new Error(`Drive content error: ${await contentRes.text()}`);
        const text = await contentRes.text();
        return res.json({ ok: true, tool, result: { fileId, name: meta.name, mimeType: meta.mimeType, content: text.slice(0, 50000) } });
      }

      if (tool === 'drive_create_folder') {
        const name = String(params.name || 'New Folder');
        const parentId = params.parentFolderId ? String(params.parentFolderId) : undefined;
        const body: any = {
          name,
          mimeType: 'application/vnd.google-apps.folder',
        };
        if (parentId) body.parents = [parentId];

        const folderRes = await fetch('https://www.googleapis.com/drive/v3/files', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(body),
        });
        if (!folderRes.ok) throw new Error(`Drive folder creation error: ${await folderRes.text()}`);
        return res.json({ ok: true, tool, result: await folderRes.json() });
      }
    }

    // 3. Google Calendar Tools
    if (tool.startsWith('calendar_')) {
      const accessToken = await getValidAccessToken(userId, 'google');
      const calendarId = encodeURIComponent(String(params.calendarId || 'primary'));

      if (tool === 'calendar_list_events') {
        const timeMin = params.timeMin ? encodeURIComponent(String(params.timeMin)) : encodeURIComponent(new Date().toISOString());
        const timeMax = params.timeMax ? `&timeMax=${encodeURIComponent(String(params.timeMax))}` : '';
        const maxResults = Math.min(Number(params.maxResults || 15), 50);
        const url = `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events?timeMin=${timeMin}${timeMax}&maxResults=${maxResults}&singleEvents=true&orderBy=startTime`;

        const calRes = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!calRes.ok) throw new Error(`Calendar API error: ${await calRes.text()}`);
        const calData = (await calRes.json()) as any;
        const events = (calData.items || []).map((ev: any) => ({
          id: ev.id,
          summary: ev.summary,
          description: ev.description,
          location: ev.location,
          start: ev.start?.dateTime || ev.start?.date,
          end: ev.end?.dateTime || ev.end?.date,
          status: ev.status,
          htmlLink: ev.htmlLink,
        }));
        return res.json({ ok: true, tool, result: { events } });
      }

      if (tool === 'calendar_create_event') {
        const summary = String(params.summary || 'New Event');
        const description = String(params.description || '');
        const location = String(params.location || '');
        const startDateTime = String(params.startDateTime || new Date().toISOString());
        const endDateTime = String(params.endDateTime || new Date(Date.now() + 3600000).toISOString());

        const eventRes = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            summary,
            description,
            location,
            start: { dateTime: startDateTime },
            end: { dateTime: endDateTime },
          }),
        });

        if (!eventRes.ok) throw new Error(`Calendar create error: ${await eventRes.text()}`);
        return res.json({ ok: true, tool, result: await eventRes.json() });
      }

      if (tool === 'calendar_get_event') {
        const eventId = encodeURIComponent(String(params.eventId || ''));
        if (!eventId) throw new Error('Missing eventId parameter.');
        const evRes = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${eventId}`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!evRes.ok) throw new Error(`Calendar get event error: ${await evRes.text()}`);
        return res.json({ ok: true, tool, result: await evRes.json() });
      }

      if (tool === 'calendar_delete_event') {
        const eventId = encodeURIComponent(String(params.eventId || ''));
        if (!eventId) throw new Error('Missing eventId parameter.');
        const delRes = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${eventId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!delRes.ok && delRes.status !== 204) throw new Error(`Calendar delete error: ${await delRes.text()}`);
        return res.json({ ok: true, tool, result: { deleted: true, eventId } });
      }
    }

    // 4. Google Tasks Tools
    if (tool.startsWith('tasks_')) {
      const accessToken = await getValidAccessToken(userId, 'google');

      if (tool === 'tasks_list_tasklists') {
        const resList = await fetch('https://tasks.googleapis.com/tasks/v1/users/@me/lists', {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!resList.ok) throw new Error(`Tasks API error: ${await resList.text()}`);
        return res.json({ ok: true, tool, result: await resList.json() });
      }

      if (tool === 'tasks_list_tasks') {
        const tasklistId = encodeURIComponent(String(params.tasklistId || '@default'));
        const showCompleted = params.showCompleted !== false;
        const maxResults = Math.min(Number(params.maxResults || 20), 50);
        const url = `https://tasks.googleapis.com/tasks/v1/lists/${tasklistId}/tasks?showCompleted=${showCompleted}&maxResults=${maxResults}`;
        const resTasks = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!resTasks.ok) throw new Error(`Tasks API error: ${await resTasks.text()}`);
        const data = (await resTasks.json()) as any;
        const tasks = (data.items || []).map((t: any) => ({
          id: t.id,
          title: t.title,
          notes: t.notes,
          status: t.status,
          due: t.due,
          completed: t.completed,
          updated: t.updated,
        }));
        return res.json({ ok: true, tool, result: { tasks } });
      }

      if (tool === 'tasks_create_task') {
        const tasklistId = encodeURIComponent(String(params.tasklistId || '@default'));
        const title = String(params.title || 'New Task');
        const notes = String(params.notes || '');
        const due = params.due ? String(params.due) : undefined;

        const body: any = { title, notes };
        if (due) body.due = due;

        const resCreate = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${tasklistId}/tasks`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(body),
        });
        if (!resCreate.ok) throw new Error(`Tasks create error: ${await resCreate.text()}`);
        return res.json({ ok: true, tool, result: await resCreate.json() });
      }

      if (tool === 'tasks_update_task') {
        const tasklistId = encodeURIComponent(String(params.tasklistId || '@default'));
        const taskId = encodeURIComponent(String(params.taskId || ''));
        if (!taskId) throw new Error('Missing taskId parameter.');

        const body: any = {};
        if (params.title !== undefined) body.title = String(params.title);
        if (params.notes !== undefined) body.notes = String(params.notes);
        if (params.status !== undefined) body.status = String(params.status); // 'completed' | 'needsAction'
        if (params.due !== undefined) body.due = String(params.due);

        const resPatch = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${tasklistId}/tasks/${taskId}`, {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(body),
        });
        if (!resPatch.ok) throw new Error(`Tasks update error: ${await resPatch.text()}`);
        return res.json({ ok: true, tool, result: await resPatch.json() });
      }
    }

    // 5. Google Sheets Tools
    if (tool.startsWith('sheets_')) {
      const accessToken = await getValidAccessToken(userId, 'google');
      const spreadsheetId = encodeURIComponent(String(params.spreadsheetId || ''));
      if (!spreadsheetId) throw new Error('Missing spreadsheetId parameter.');

      if (tool === 'sheets_get_spreadsheet') {
        const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}?includeGridData=false`;
        const sheetRes = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!sheetRes.ok) throw new Error(`Sheets API error: ${await sheetRes.text()}`);
        return res.json({ ok: true, tool, result: await sheetRes.json() });
      }

      if (tool === 'sheets_read_range') {
        const range = encodeURIComponent(String(params.range || 'Sheet1!A1:Z100'));
        const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}`;
        const sheetRes = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
        if (!sheetRes.ok) throw new Error(`Sheets API error: ${await sheetRes.text()}`);
        return res.json({ ok: true, tool, result: await sheetRes.json() });
      }

      if (tool === 'sheets_append_rows') {
        const range = encodeURIComponent(String(params.range || 'Sheet1!A1'));
        const values = Array.isArray(params.values) ? params.values : [];
        const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}:append?valueInputOption=USER_ENTERED`;
        const appendRes = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ values }),
        });
        if (!appendRes.ok) throw new Error(`Sheets API append error: ${await appendRes.text()}`);
        return res.json({ ok: true, tool, result: await appendRes.json() });
      }

      if (tool === 'sheets_update_values') {
        const range = encodeURIComponent(String(params.range || 'Sheet1!A1'));
        const values = Array.isArray(params.values) ? params.values : [];
        const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}?valueInputOption=USER_ENTERED`;
        const updateRes = await fetch(url, {
          method: 'PUT',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ values }),
        });
        if (!updateRes.ok) throw new Error(`Sheets API update error: ${await updateRes.text()}`);
        return res.json({ ok: true, tool, result: await updateRes.json() });
      }
    }

    // 7. Google Docs Tools
    if (tool.startsWith('docs_')) {
      const accessToken = await getValidAccessToken(userId, 'google');

      if (tool === 'docs_get_document') {
        const documentId = encodeURIComponent(String(params.documentId || ''));
        if (!documentId) throw new Error('Missing documentId parameter.');

        const docRes = await fetch(`https://docs.googleapis.com/v1/documents/${documentId}`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!docRes.ok) throw new Error(`Docs API error: ${await docRes.text()}`);
        const docData = (await docRes.json()) as any;

        // Parse document structural text
        let fullText = '';
        if (docData.body?.content && Array.isArray(docData.body.content)) {
          for (const elem of docData.body.content) {
            if (elem.paragraph?.elements) {
              for (const pElem of elem.paragraph.elements) {
                if (pElem.textRun?.content) {
                  fullText += pElem.textRun.content;
                }
              }
            }
          }
        }

        return res.json({
          ok: true,
          tool,
          result: {
            documentId: docData.documentId,
            title: docData.title,
            revisionId: docData.revisionId,
            textContent: fullText,
          },
        });
      }

      if (tool === 'docs_create_document') {
        const title = String(params.title || 'Untitled Document');
        const createRes = await fetch('https://docs.googleapis.com/v1/documents', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ title }),
        });
        if (!createRes.ok) throw new Error(`Docs create error: ${await createRes.text()}`);
        return res.json({ ok: true, tool, result: await createRes.json() });
      }

      if (tool === 'docs_append_text') {
        const documentId = encodeURIComponent(String(params.documentId || ''));
        const text = String(params.text || '');
        if (!documentId) throw new Error('Missing documentId parameter.');

        // Get document to find end index
        const getRes = await fetch(`https://docs.googleapis.com/v1/documents/${documentId}`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!getRes.ok) throw new Error(`Docs get error: ${await getRes.text()}`);
        const getJson = (await getRes.json()) as any;
        const endIndex = Math.max(1, (getJson.body?.content?.slice(-1)[0]?.endIndex || 1) - 1);

        const updateRes = await fetch(`https://docs.googleapis.com/v1/documents/${documentId}:batchUpdate`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            requests: [
              {
                insertText: {
                  location: { index: endIndex },
                  text: text.endsWith('\n') ? text : `${text}\n`,
                },
              },
            ],
          }),
        });
        if (!updateRes.ok) throw new Error(`Docs batchUpdate error: ${await updateRes.text()}`);
        return res.json({ ok: true, tool, result: await updateRes.json() });
      }
    }

    // 8. GitHub Tools
    if (tool.startsWith('github_')) {
      const accessToken = await getValidAccessToken(userId, 'github');
      const ghHeaders = {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/vnd.github.v3+json',
        'User-Agent': 'AdoetzGPT',
      };

      if (tool === 'github_list_repositories') {
        const sort = String(params.sort || 'updated');
        const perPage = Math.min(Number(params.per_page || 15), 50);
        const ghRes = await fetch(`https://api.github.com/user/repos?sort=${sort}&per_page=${perPage}`, {
          headers: ghHeaders,
        });
        if (!ghRes.ok) throw new Error(`GitHub API error: ${await ghRes.text()}`);
        const repos = (await ghRes.json()) as any[];
        return res.json({
          ok: true,
          tool,
          result: repos.map((r) => ({
            id: r.id,
            name: r.name,
            fullName: r.full_name,
            private: r.private,
            htmlUrl: r.html_url,
            description: r.description,
            fork: r.fork,
            language: r.language,
            stargazersCount: r.stargazers_count,
            updatedAt: r.updated_at,
          })),
        });
      }

      if (tool === 'github_get_repository') {
        const owner = encodeURIComponent(String(params.owner || ''));
        const repo = encodeURIComponent(String(params.repo || ''));
        if (!owner || !repo) throw new Error('Missing owner or repo parameter.');
        const ghRes = await fetch(`https://api.github.com/repos/${owner}/${repo}`, { headers: ghHeaders });
        if (!ghRes.ok) throw new Error(`GitHub API error: ${await ghRes.text()}`);
        return res.json({ ok: true, tool, result: await ghRes.json() });
      }

      if (tool === 'github_list_issues') {
        const owner = encodeURIComponent(String(params.owner || ''));
        const repo = encodeURIComponent(String(params.repo || ''));
        const state = String(params.state || 'open');
        const perPage = Math.min(Number(params.per_page || 15), 50);
        if (!owner || !repo) throw new Error('Missing owner or repo parameter.');

        const ghRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/issues?state=${state}&per_page=${perPage}`, {
          headers: ghHeaders,
        });
        if (!ghRes.ok) throw new Error(`GitHub API error: ${await ghRes.text()}`);
        const issues = (await ghRes.json()) as any[];
        return res.json({
          ok: true,
          tool,
          result: issues.map((iss) => ({
            number: iss.number,
            title: iss.title,
            state: iss.state,
            user: iss.user?.login,
            htmlUrl: iss.html_url,
            comments: iss.comments,
            createdAt: iss.created_at,
            bodySnippet: iss.body ? iss.body.slice(0, 300) : '',
          })),
        });
      }

      if (tool === 'github_create_issue') {
        const owner = encodeURIComponent(String(params.owner || ''));
        const repo = encodeURIComponent(String(params.repo || ''));
        const title = String(params.title || '');
        const body = String(params.body || '');
        const labels = Array.isArray(params.labels) ? params.labels : undefined;
        if (!owner || !repo || !title) throw new Error('Missing owner, repo, or title parameter.');

        const ghRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/issues`, {
          method: 'POST',
          headers: { ...ghHeaders, 'Content-Type': 'application/json' },
          body: JSON.stringify({ title, body, labels }),
        });
        if (!ghRes.ok) throw new Error(`GitHub issue create error: ${await ghRes.text()}`);
        return res.json({ ok: true, tool, result: await ghRes.json() });
      }

      if (tool === 'github_get_file_content') {
        const owner = encodeURIComponent(String(params.owner || ''));
        const repo = encodeURIComponent(String(params.repo || ''));
        const filePath = String(params.path || '').replace(/^\/+/, '');
        const ref = params.ref ? `?ref=${encodeURIComponent(String(params.ref))}` : '';
        if (!owner || !repo || !filePath) throw new Error('Missing owner, repo, or path parameter.');

        const ghRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/${filePath}${ref}`, {
          headers: ghHeaders,
        });
        if (!ghRes.ok) throw new Error(`GitHub file error: ${await ghRes.text()}`);
        const fileJson = (await ghRes.json()) as any;

        let decodedContent = '';
        if (fileJson.content && fileJson.encoding === 'base64') {
          decodedContent = Buffer.from(fileJson.content, 'base64').toString('utf8');
        }

        return res.json({
          ok: true,
          tool,
          result: {
            name: fileJson.name,
            path: fileJson.path,
            sha: fileJson.sha,
            size: fileJson.size,
            htmlUrl: fileJson.html_url,
            content: decodedContent,
          },
        });
      }

      if (tool === 'github_search_code') {
        const q = encodeURIComponent(String(params.q || ''));
        const perPage = Math.min(Number(params.per_page || 10), 30);
        if (!q) throw new Error('Missing query "q" parameter.');

        const ghRes = await fetch(`https://api.github.com/search/code?q=${q}&per_page=${perPage}`, {
          headers: ghHeaders,
        });
        if (!ghRes.ok) throw new Error(`GitHub code search error: ${await ghRes.text()}`);
        const searchJson = (await ghRes.json()) as any;
        return res.json({
          ok: true,
          tool,
          result: {
            totalCount: searchJson.total_count,
            items: (searchJson.items || []).map((item: any) => ({
              name: item.name,
              path: item.path,
              sha: item.sha,
              htmlUrl: item.html_url,
              repository: item.repository?.full_name,
            })),
          },
        });
      }
    }

    res.status(400).json({ ok: false, tool, error: `Unknown plugin tool: "${tool}"` });
  } catch (error: any) {
    console.error(`Tool execution error for "${tool}":`, error);
    res.status(500).json({ ok: false, tool, error: error.message || String(error) });
  }
});

// Serve compiled Flutter Web assets if build/web directory exists
const webBuildDir = path.join(root, 'build', 'web');
app.use(express.static(webBuildDir));
app.get('*', async (_req, res, next) => {
  try {
    const indexPath = path.join(webBuildDir, 'index.html');
    await fs.access(indexPath);
    res.sendFile(indexPath);
  } catch (_) {
    next();
  }
});

app.listen(port, host, () => {
  console.log(`Adoetz Chat running at http://${host}:${port}`);
  console.log(`Shared state database: ${dbPath}`);
});
