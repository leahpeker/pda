// Frontend error reporter. Mirrors Flutter's `ErrorReporter`: when the user
// is authenticated, POSTs a normalized error payload to the backend so it
// surfaces in server logs. When there's no access token, or the POST fails,
// we fall back to `console.error` so the error is never silently swallowed.
//
// Field names match the existing `/api/community/error-report/` schema in
// `backend/community/_feedback.py` (`error`, `stack_trace`, `route`,
// `client_timestamp`) — not the in-code `{message, stack, timestamp}` shape.

import { apiClient } from '@/api/client';
import { useAuthStore } from '@/auth/store';

const ERROR_REPORT_PATH = '/api/community/error-report/';

interface NormalizedError {
  message: string;
  stack: string;
}

function normalizeError(error: unknown): NormalizedError {
  if (error instanceof Error) {
    return { message: error.message || String(error), stack: error.stack ?? '' };
  }
  if (typeof error === 'string') {
    return { message: error, stack: '' };
  }
  try {
    return { message: JSON.stringify(error), stack: '' };
  } catch {
    return { message: String(error), stack: '' };
  }
}

export async function reportError(error: unknown, route: string): Promise<void> {
  const { accessToken } = useAuthStore.getState();
  if (!accessToken) {
    console.error(error);
    return;
  }

  const { message, stack } = normalizeError(error);
  try {
    await apiClient.post(ERROR_REPORT_PATH, {
      error: message,
      stack_trace: stack,
      route,
      client_timestamp: new Date().toISOString(),
    });
  } catch {
    // Never re-throw from the reporter — surface locally instead.
    console.error(error);
  }
}
