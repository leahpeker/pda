import { NavLink } from 'react-router-dom';
import { cn } from '@/utils/cn';
import { useAuthStore } from '@/auth/store';
import { useHasAnyAdminPermission } from '@/auth/useAuth';

// Links shown in the primary nav. Auth-gated entries are filtered at render.
interface LinkDef {
  to: string;
  label: string;
  show: 'always' | 'authed' | 'unauthed' | 'admin';
}

const LINKS: LinkDef[] = [
  { to: '/', label: 'home', show: 'always' },
  { to: '/calendar', label: 'calendar', show: 'always' },
  { to: '/guidelines', label: 'guidelines', show: 'authed' },
  { to: '/faq', label: 'faq', show: 'always' },
  { to: '/profile', label: 'profile', show: 'authed' },
  { to: '/admin', label: 'admin', show: 'admin' },
  { to: '/join', label: 'join', show: 'unauthed' },
];

export function Nav() {
  const isAuthed = useAuthStore((s) => s.status === 'authed');
  const isAdmin = useHasAnyAdminPermission();

  const visible = LINKS.filter((l) => {
    switch (l.show) {
      case 'always':
        return true;
      case 'authed':
        return isAuthed;
      case 'unauthed':
        return !isAuthed;
      case 'admin':
        return isAdmin;
    }
  });

  return (
    <nav aria-label="primary" className="flex items-center gap-1">
      {visible.map((l) => (
        <NavLink
          key={l.to}
          to={l.to}
          end={l.to === '/'}
          className={({ isActive }) =>
            cn(
              'rounded-md px-3 py-1.5 text-sm text-neutral-700 transition-colors hover:bg-neutral-100',
              isActive && 'bg-neutral-100 font-medium text-neutral-900',
            )
          }
        >
          {l.label}
        </NavLink>
      ))}
    </nav>
  );
}
