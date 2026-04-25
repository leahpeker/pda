import { describe, it, expect, afterEach, vi } from 'vitest';
import { buildSmsHref, buildWelcomeMessage } from './welcomeMessage';

const IPHONE_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1';
const ANDROID_UA =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

function setUserAgent(ua: string) {
  vi.spyOn(navigator, 'userAgent', 'get').mockReturnValue(ua);
}

describe('buildSmsHref', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('uses & separator on iOS so Messages opens a draft instead of showing the raw url', () => {
    setUserAgent(IPHONE_UA);
    const href = buildSmsHref('+15551234567', 'hi there');
    expect(href).toBe('sms:+15551234567&body=hi%20there');
  });

  it('uses ? separator on Android', () => {
    setUserAgent(ANDROID_UA);
    const href = buildSmsHref('+15551234567', 'hi there');
    expect(href).toBe('sms:+15551234567?body=hi%20there');
  });

  it('url-encodes the body (newlines, emoji, special chars)', () => {
    setUserAgent(ANDROID_UA);
    const href = buildSmsHref('+15551234567', 'hi 🌱\nlink: https://x/y?z=1');
    expect(href).toContain('body=hi%20%F0%9F%8C%B1%0Alink%3A%20https%3A%2F%2Fx%2Fy%3Fz%3D1');
  });
});

describe('buildWelcomeMessage', () => {
  it('greets by name when provided', () => {
    expect(buildWelcomeMessage('alex', 'https://x/y')).toBe(
      'hi alex 🌱 welcome to pda! use this link to sign in: https://x/y',
    );
  });

  it('falls back to a name-less greeting when display name is missing or blank', () => {
    expect(buildWelcomeMessage(null, 'https://x/y')).toBe(
      'hi 🌱 welcome to pda! use this link to sign in: https://x/y',
    );
    expect(buildWelcomeMessage('   ', 'https://x/y')).toBe(
      'hi 🌱 welcome to pda! use this link to sign in: https://x/y',
    );
  });
});
