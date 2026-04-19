// Cute date/time picker using react-day-picker + a simple time input.
// Clicking the display opens a dropdown calendar; picking a date + time
// shows a formatted string like "saturday, april 18 · 3:30 pm".

import { format } from 'date-fns';
import { enUS } from 'date-fns/locale/en-US';
import { useEffect, useRef, useState } from 'react';
import { DayPicker } from 'react-day-picker';

interface Props {
  label: string;
  value: string | null;
  onChange: (iso: string | null) => void;
  disabled?: boolean;
  error?: string | undefined;
  optional?: boolean;
}

function isoToDate(iso: string | null): Date | undefined {
  if (!iso) return undefined;
  const d = new Date(iso);
  return isNaN(d.getTime()) ? undefined : d;
}

function dateToIso(date: Date, hours: number, minutes: number): string {
  const copy = new Date(date);
  copy.setHours(hours, minutes, 0, 0);
  return copy.toISOString();
}

export function DateTimePicker({ label, value, onChange, disabled, error, optional }: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const selectedDate = isoToDate(value);

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    function onClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', onClick);
    return () => {
      document.removeEventListener('mousedown', onClick);
    };
  }, [open]);

  // Close on Escape
  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') setOpen(false);
    }
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const display = value
    ? (() => {
        const d = new Date(value);
        if (isNaN(d.getTime())) return '';
        return format(d, 'EEEE, MMMM d · h:mmaaa').toLowerCase();
      })()
    : '';

  return (
    <div ref={ref} className="relative flex flex-col gap-1">
      <label className="text-sm font-medium text-foreground">
        {label}
        {optional && <span className="ml-1 text-xs font-normal text-muted-foreground">(optional)</span>}
      </label>

      <button
        type="button"
        disabled={disabled}
        onClick={() => {
          if (!disabled) setOpen((v) => !v);
        }}
        aria-expanded={open}
        className={[
          'h-10 w-full rounded-[var(--radius-md)] border px-3 text-left text-sm transition-colors outline-none',
          display
            ? 'border-brand-200 bg-brand-50 text-brand-900 font-medium'
            : 'border-border-strong bg-surface text-muted-foreground',
          error && 'border-destructive bg-destructive-subtle text-destructive',
          disabled && 'bg-surface-dim text-muted-foreground',
        ].join(' ')}
      >
        {display || 'pick a date & time'}
      </button>

      {open && (
        <div className="absolute z-50 mt-2 rounded-[var(--radius-md)] border border-brand-100 bg-surface p-3 shadow-(--shadow-lg)">
          <DayPicker
            mode="single"
            selected={selectedDate}
            onSelect={(day) => {
              if (!day) return;
              const h = selectedDate?.getHours() ?? 12;
              const m = selectedDate?.getMinutes() ?? 0;
              onChange(dateToIso(day, h, m));
            }}
            defaultMonth={selectedDate ?? new Date()}
            locale={enUS}
          />
          <div className="mt-2 flex items-center gap-2 border-t border-border pt-2">
            <label htmlFor="dt-time" className="text-xs text-muted">time</label>
            <input
              id="dt-time"
              type="time"
              value={
                selectedDate
                  ? `${String(selectedDate.getHours()).padStart(2, '0')}:${String(selectedDate.getMinutes()).padStart(2, '0')}`
                  : '12:00'
              }
              onChange={(e) => {
                const [h, m] = e.target.value.split(':').map(Number) as [number, number];
                const base = selectedDate ?? new Date();
                onChange(dateToIso(base, h, m));
              }}
              className="h-8 rounded-md border border-border bg-surface px-2 text-sm outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-200"
            />
          </div>
        </div>
      )}

      {error ? (
        <p className="text-xs text-destructive">{error}</p>
      ) : null}
    </div>
  );
}
