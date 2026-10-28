// Object storage for coach videos, built for Cloudflare R2 (S3 compatible).
//
// Uploads go straight from the phone to the bucket through a short lived signed
// URL, so large videos never pass through the app server. Signing is plain
// AWS Signature V4 on Web Crypto: no SDK, and it runs on Node and on Workers.
//
// Everything is dormant until the environment is configured:
//   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET,
//   R2_PUBLIC_BASE_URL (the public r2.dev link or a custom domain, no trailing slash)

export interface StorageConfig {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicBaseUrl: string;
}

export const MAX_UPLOAD_MB = 500;
export const VIDEO_TYPES = ['video/mp4', 'video/quicktime', 'video/x-m4v'] as const;
export const IMAGE_TYPES = ['image/jpeg', 'image/png'] as const;

export function getStorageConfig(env: Record<string, string | undefined> = process.env): StorageConfig | null {
  const { R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL } = env;
  if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY || !R2_BUCKET || !R2_PUBLIC_BASE_URL) {
    return null;
  }
  return {
    accountId: R2_ACCOUNT_ID,
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
    bucket: R2_BUCKET,
    publicBaseUrl: R2_PUBLIC_BASE_URL.replace(/\/+$/, ''),
  };
}

const encoder = new TextEncoder();

function hex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function sha256Hex(text: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', encoder.encode(text)));
}

async function hmac(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey('raw', key as BufferSource, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return crypto.subtle.sign('HMAC', k, encoder.encode(data));
}

// RFC 3986 encoding, as AWS requires (also escapes ! ' ( ) *).
function awsEncode(value: string): string {
  return encodeURIComponent(value).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

export interface PresignInput {
  method: 'GET' | 'PUT' | 'DELETE';
  host: string;
  // Path including the bucket for path style requests, e.g. "/bucket/videos/a.mp4".
  path: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  expiresSec: number;
  now?: Date;
  // Headers the client must send unchanged (lower-case names), besides host.
  signedHeaders?: Record<string, string>;
}

// Builds a query-string signed URL (AWS Signature V4 "presigned URL").
export async function presignUrl(input: PresignInput): Promise<string> {
  const now = input.now ?? new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.slice(0, 8);
  const scope = `${dateStamp}/${input.region}/s3/aws4_request`;

  const headers: Record<string, string> = { host: input.host, ...(input.signedHeaders ?? {}) };
  const names = Object.keys(headers).sort();
  const signedHeaderNames = names.join(';');

  const query: Record<string, string> = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `${input.accessKeyId}/${scope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': String(input.expiresSec),
    'X-Amz-SignedHeaders': signedHeaderNames,
  };
  const canonicalQuery = Object.keys(query)
    .sort()
    .map((k) => `${awsEncode(k)}=${awsEncode(query[k]!)}`)
    .join('&');

  const canonicalUri = input.path
    .split('/')
    .map((segment) => awsEncode(segment))
    .join('/');
  const canonicalHeaders = names.map((n) => `${n}:${headers[n]!.trim()}\n`).join('');
  const canonicalRequest = [
    input.method,
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    signedHeaderNames,
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  const stringToSign = ['AWS4-HMAC-SHA256', amzDate, scope, await sha256Hex(canonicalRequest)].join('\n');
  const kDate = await hmac(encoder.encode(`AWS4${input.secretAccessKey}`), dateStamp);
  const kRegion = await hmac(kDate, input.region);
  const kService = await hmac(kRegion, 's3');
  const kSigning = await hmac(kService, 'aws4_request');
  const signature = hex(await hmac(kSigning, stringToSign));

  return `https://${input.host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

function r2Host(config: StorageConfig): string {
  return `${config.accountId}.r2.cloudflarestorage.com`;
}

export async function presignUpload(
  config: StorageConfig,
  key: string,
  contentType: string,
  expiresSec = 1800,
  now?: Date,
): Promise<string> {
  return presignUrl({
    method: 'PUT',
    host: r2Host(config),
    path: `/${config.bucket}/${key}`,
    region: 'auto',
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
    expiresSec,
    now,
    // R2 stores the Content-Type it receives, so it is pinned to what was approved.
    signedHeaders: { 'content-type': contentType },
  });
}

export function publicUrl(config: StorageConfig, key: string): string {
  return `${config.publicBaseUrl}/${key.split('/').map(encodeURIComponent).join('/')}`;
}

// Best effort: a failed delete must never block removing the video record.
export async function deleteObject(config: StorageConfig, key: string): Promise<boolean> {
  try {
    const url = await presignUrl({
      method: 'DELETE',
      host: r2Host(config),
      path: `/${config.bucket}/${key}`,
      region: 'auto',
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      expiresSec: 120,
    });
    const res = await fetch(url, { method: 'DELETE' });
    return res.ok || res.status === 404;
  } catch {
    return false;
  }
}

export function sanitizeFileName(name: string): string {
  const base = name.split(/[\\/]/).pop() ?? 'file';
  const cleaned = base
    .normalize('NFKD')
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(-80);
  return cleaned || 'file';
}

// Keys are generated here, never taken from the client, so a request cannot
// aim an upload or a delete at some other object in the bucket.
export function buildKey(kind: 'video' | 'thumb', fileName: string, id: string): string {
  return `${kind === 'video' ? 'videos' : 'thumbs'}/${id}/${sanitizeFileName(fileName)}`;
}

// Accepts only keys of the shape buildKey makes.
export const STORAGE_KEY_PATTERN = /^(videos|thumbs)\/[A-Za-z0-9-]{8,64}\/[A-Za-z0-9._-]{1,80}$/;
