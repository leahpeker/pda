export function buildMagicLinkUrl(token: string): string {
  return `${window.location.origin}/magic-login/${token}`;
}

export function buildWelcomeMessage(displayName: string | null | undefined, url: string): string {
  const name = (displayName ?? '').trim();
  const greeting = name ? `hi ${name} 🌱` : 'hi 🌱';
  return `${greeting} welcome to pda! use this link to sign in: ${url}`;
}

export function buildSmsHref(phoneNumber: string, body: string): string {
  // iOS expects `&body=` after the number; Android/others use `?body=`.
  // Using the wrong separator on iOS causes Messages to show the raw URL
  // instead of opening a draft.
  const isIos = /iPad|iPhone|iPod/.test(navigator.userAgent);
  const separator = isIos ? '&' : '?';
  return `sms:${phoneNumber}${separator}body=${encodeURIComponent(body)}`;
}
