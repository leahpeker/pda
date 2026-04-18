// App chrome: sticky top bar + outlet. Replaces Flutter's AppScaffold. Kept
// deliberately simple — specific screens (calendar side-panel, modals, full-
// bleed detail) can opt out by rendering their own layout above the outlet.

import { Link, Outlet } from 'react-router-dom';
import { useAuthStore } from '@/auth/store';
import { Nav } from './Nav';
import { NotificationBell } from './NotificationBell';

export function AppShell() {
  const isAuthed = useAuthStore((s) => s.status === 'authed');

  return (
    <div className="flex min-h-screen flex-col bg-neutral-50">
      <header className="sticky top-0 z-10 border-b border-neutral-200 bg-white">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4">
          <Link to="/" className="text-base font-medium tracking-tight">
            pda
          </Link>
          <Nav />
          <div className="flex items-center gap-1">
            {isAuthed ? (
              <NotificationBell />
            ) : (
              <Link
                to="/login"
                className="inline-flex h-9 items-center rounded-md px-3 text-sm text-neutral-700 hover:bg-neutral-100"
              >
                sign in
              </Link>
            )}
          </div>
        </div>
      </header>
      <div className="flex-1">
        <Outlet />
      </div>
    </div>
  );
}
