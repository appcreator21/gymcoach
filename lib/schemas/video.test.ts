import { describe, it, expect } from 'vitest';
import { normalizeExerciseName, videoInputSchema } from './video';

const base = { title: 'Squat depth', videoUrl: 'https://cdn.example.com/squat.mp4' };

describe('videoInputSchema', () => {
  it('accepts a minimal video and applies defaults', () => {
    const v = videoInputSchema.parse(base);
    expect(v.category).toBe('Workouts');
    expect(v.featured).toBe(false);
  });

  it('turns empty optional strings into null', () => {
    const v = videoInputSchema.parse({ ...base, description: '  ', thumbnailUrl: '', exerciseName: '', durationSec: '' });
    expect(v.description).toBeNull();
    expect(v.thumbnailUrl).toBeNull();
    expect(v.exerciseName).toBeNull();
    expect(v.durationSec).toBeNull();
  });

  it('rejects non-https and malformed links', () => {
    expect(videoInputSchema.safeParse({ ...base, videoUrl: 'http://x.com/a.mp4' }).success).toBe(false);
    expect(videoInputSchema.safeParse({ ...base, videoUrl: 'javascript:alert(1)' }).success).toBe(false);
    expect(videoInputSchema.safeParse({ ...base, videoUrl: 'not a url' }).success).toBe(false);
    expect(videoInputSchema.safeParse({ ...base, thumbnailUrl: 'ftp://x.com/a.jpg' }).success).toBe(false);
  });

  it('bounds the duration', () => {
    expect(videoInputSchema.safeParse({ ...base, durationSec: 0 }).success).toBe(false);
    expect(videoInputSchema.parse({ ...base, durationSec: '95' }).durationSec).toBe(95);
  });
});

describe('video links and storage keys', () => {
  it('accepts a workout link and generated keys', () => {
    const v = videoInputSchema.parse({ ...base, workoutName: ' Upper A ', storageKey: 'videos/a1b2c3d4-e5f6/clip.mp4' });
    expect(v.workoutName).toBe('Upper A');
    expect(v.storageKey).toBe('videos/a1b2c3d4-e5f6/clip.mp4');
  });

  it('rejects keys that do not look generated', () => {
    expect(videoInputSchema.safeParse({ ...base, storageKey: '../../secret.mp4' }).success).toBe(false);
    expect(videoInputSchema.safeParse({ ...base, thumbnailKey: 'videos/x/y.mp4' }).success).toBe(false);
  });
});

describe('normalizeExerciseName', () => {
  it('matches across case and punctuation', () => {
    expect(normalizeExerciseName('Barbell Back-Squat')).toBe(normalizeExerciseName('barbell back squat'));
  });
});
