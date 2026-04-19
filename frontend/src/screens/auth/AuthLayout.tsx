import type { ReactNode } from 'react';

export function AuthLayout({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-4">
      <div className="w-full max-w-sm rounded-lg border border-border bg-surface p-6 shadow-(--shadow-sm)">
        <h1 className="text-xl font-medium tracking-tight text-foreground">{title}</h1>
        {subtitle ? <p className="mt-1 text-sm text-foreground-tertiary">{subtitle}</p> : null}
        <div className="mt-6">{children}</div>
      </div>
    </main>
  );
}
