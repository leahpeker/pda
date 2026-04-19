// Fully static screen — no API. Step copy mirrors install_app_screen.dart so
// the web and Flutter apps stay consistent while both are in production.

import { useMemo, useState } from 'react';
import { ContentContainer } from './ContentContainer';

interface Step {
  label: string;
  hint: string;
}

const IOS_STEPS: Step[] = [
  { label: 'open pda in safari', hint: "other browsers can't add to home screen" },
  { label: 'tap the share button', hint: 'the square-with-arrow icon at the bottom' },
  { label: 'tap "add to home screen"', hint: "scroll down if you don't see it" },
  { label: 'tap "add"', hint: 'top-right of the popup' },
];

const ANDROID_STEPS: Step[] = [
  { label: 'open pda in chrome', hint: '' },
  { label: 'tap the three-dot menu', hint: 'top-right of the browser' },
  { label: 'tap "add to home screen" or "install app"', hint: '' },
];

function guessPlatform(): 'ios' | 'android' | 'other' {
  if (typeof navigator === 'undefined') return 'other';
  const ua = navigator.userAgent;
  if (/iP(hone|ad|od)/.test(ua)) return 'ios';
  if (ua.includes('Android')) return 'android';
  return 'other';
}

export default function InstallAppScreen() {
  const initialPlatform = useMemo(() => guessPlatform(), []);
  const [openIos, setOpenIos] = useState(initialPlatform !== 'android');
  const [openAndroid, setOpenAndroid] = useState(initialPlatform !== 'ios');

  return (
    <ContentContainer>
      <h1 className="mb-2 text-2xl font-medium tracking-tight">install the app</h1>
      <p className="mb-6 text-sm text-foreground-tertiary">
        add pda to your home screen for a native-app feel
      </p>

      <InstallCard
        icon="🍎"
        title="iphone / ipad"
        open={openIos}
        onToggle={() => {
          setOpenIos((v) => !v);
        }}
        steps={IOS_STEPS}
      />
      <InstallCard
        icon="🤖"
        title="android"
        open={openAndroid}
        onToggle={() => {
          setOpenAndroid((v) => !v);
        }}
        steps={ANDROID_STEPS}
      />

      <p className="mt-8 text-center text-xs text-muted">
        once installed, pda opens full-screen — just like a native app
      </p>
    </ContentContainer>
  );
}

function InstallCard({
  icon,
  title,
  open,
  onToggle,
  steps,
}: {
  icon: string;
  title: string;
  open: boolean;
  onToggle: () => void;
  steps: Step[];
}) {
  return (
    <section className="mb-3 overflow-hidden rounded-lg border border-border bg-surface">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className="flex w-full items-center justify-between px-4 py-3 text-left hover:bg-background"
      >
        <span className="flex items-center gap-3">
          <span aria-hidden="true">{icon}</span>
          <span className="text-base font-medium">{title}</span>
        </span>
        <span aria-hidden="true" className="text-muted-foreground">
          {open ? '▾' : '▸'}
        </span>
      </button>
      {open ? (
        <ol className="list-decimal border-t border-border px-4 py-3 ps-10 text-sm">
          {steps.map((s) => (
            <li key={s.label} className="mb-2 last:mb-0">
              <p className="text-foreground">{s.label}</p>
              {s.hint ? <p className="text-xs text-muted">{s.hint}</p> : null}
            </li>
          ))}
        </ol>
      ) : null}
    </section>
  );
}
