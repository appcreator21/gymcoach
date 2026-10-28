import { describe, it, expect } from 'vitest';
import { buildKey, getStorageConfig, presignUpload, presignUrl, publicUrl, sanitizeFileName, STORAGE_KEY_PATTERN } from './storage';

describe('presignUrl', () => {
  it('matches the AWS documented presigned GET example', async () => {
    const url = await presignUrl({
      method: 'GET',
      host: 'examplebucket.s3.amazonaws.com',
      path: '/test.txt',
      region: 'us-east-1',
      accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      expiresSec: 86400,
      now: new Date('2013-05-24T00:00:00Z'),
    });
    expect(url).toBe(
      'https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256' +
        '&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request' +
        '&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host' +
        '&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404',
    );
  });
});

describe('storage config', () => {
  const full = {
    R2_ACCOUNT_ID: 'acct',
    R2_ACCESS_KEY_ID: 'key',
    R2_SECRET_ACCESS_KEY: 'secret',
    R2_BUCKET: 'surba',
    R2_PUBLIC_BASE_URL: 'https://videos.example.com/',
  };

  it('is null until every setting is present', () => {
    expect(getStorageConfig({})).toBeNull();
    expect(getStorageConfig({ ...full, R2_BUCKET: undefined })).toBeNull();
  });

  it('trims the trailing slash of the public url', () => {
    expect(getStorageConfig(full)?.publicBaseUrl).toBe('https://videos.example.com');
  });

  it('signs an upload to the R2 endpoint with the content type pinned', async () => {
    const config = getStorageConfig(full)!;
    const url = await presignUpload(config, 'videos/abc12345/clip.mp4', 'video/mp4', 600, new Date('2026-10-30T10:00:00Z'));
    expect(url.startsWith('https://acct.r2.cloudflarestorage.com/surba/videos/abc12345/clip.mp4?')).toBe(true);
    expect(url).toContain('X-Amz-SignedHeaders=content-type%3Bhost');
    expect(url).toContain('X-Amz-Expires=600');
    expect(url).toMatch(/X-Amz-Signature=[0-9a-f]{64}$/);
  });

  it('builds public urls', () => {
    const config = getStorageConfig(full)!;
    expect(publicUrl(config, 'videos/abc12345/my clip.mp4')).toBe('https://videos.example.com/videos/abc12345/my%20clip.mp4');
  });
});

describe('keys', () => {
  it('sanitizes file names', () => {
    expect(sanitizeFileName('../../My Reel #1 (final).MOV')).toBe('My-Reel-1-final-.MOV');
    expect(sanitizeFileName('???')).toBe('file');
  });

  it('builds keys that match the accepted pattern and nothing else does', () => {
    const key = buildKey('video', 'Squat Tips.mp4', 'a1b2c3d4-e5f6');
    expect(key).toBe('videos/a1b2c3d4-e5f6/Squat-Tips.mp4');
    expect(STORAGE_KEY_PATTERN.test(key)).toBe(true);
    expect(STORAGE_KEY_PATTERN.test('../etc/passwd')).toBe(false);
    expect(STORAGE_KEY_PATTERN.test('videos/../secret/x.mp4')).toBe(false);
    expect(STORAGE_KEY_PATTERN.test('other/abc12345/x.mp4')).toBe(false);
  });
});
