// Location autocomplete field. Type 3+ chars to search via Photon geocode
// API (proxied through backend). On selection, fills the input with a condensed
// lowercase address and fires onChange with location + lat/lng. Free text
// still works — coords stay null if no result is picked.

import { useEffect, useRef, useState } from 'react';
import { searchLocations, type PhotonResult } from '@/api/geocode';

interface Props {
  label: string;
  value: string;
  latitude: number | null;
  longitude: number | null;
  onChange: (patch: { location: string; latitude: number | null; longitude: number | null }) => void;
  disabled?: boolean;
  error?: string | undefined;
  maxLength?: number;
  placeholder?: string;
}

export function LocationField({
  label,
  value,
  onChange,
  disabled,
  error,
  maxLength,
  placeholder,
}: Props) {
  const [query, setQuery] = useState(value);
  const [results, setResults] = useState<PhotonResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [open, setOpen] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  // Track the last value the parent set, so we can sync when it changes
  // externally (e.g. form reset) without overwriting user input.
  const [prevValue, setPrevValue] = useState(value);

  if (value !== prevValue) {
    setPrevValue(value);
    setQuery(value);
  }

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    function onClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
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

  function handleInput(text: string) {
    setQuery(text);
    setOpen(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (text.trim().length < 3) {
      setResults([]);
      setSearching(false);
      onChange({ location: text, latitude: null, longitude: null });
      return;
    }

    setSearching(true);
    debounceRef.current = setTimeout(async () => {
      try {
        const found = await searchLocations(text);
        setResults(found);
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 400);
  }

  function handleSelect(result: PhotonResult) {
    setQuery(result.fullAddress);
    setPrevValue(result.fullAddress);
    setOpen(false);
    setResults([]);
    onChange({ location: result.fullAddress, latitude: result.lat, longitude: result.lon });
  }

  function handleBlur() {
    if (query !== value) {
      setPrevValue(query);
      onChange({ location: query, latitude: null, longitude: null });
    }
  }

  const inputId = `field-${label.replace(/\s+/g, '-').toLowerCase()}`;

  return (
    <div ref={containerRef} className="relative flex flex-col gap-1">
      <label htmlFor={inputId} className="text-sm font-medium text-neutral-800">
        {label}
      </label>
      <div className="relative">
        <input
          id={inputId}
          type="text"
          value={query}
          onChange={(e) => {
            handleInput(e.target.value);
          }}
          onBlur={handleBlur}
          onFocus={() => {
            if (results.length > 0) setOpen(true);
          }}
          disabled={disabled}
          aria-invalid={error ? true : undefined}
          autoComplete="off"
          maxLength={maxLength}
          placeholder={placeholder}
          className={[
            'h-10 w-full rounded-md border bg-white px-3 text-sm transition-colors outline-none focus:ring-2',
            'border-neutral-300 focus:border-brand-500 focus:ring-brand-200',
            error && 'border-red-500 focus:border-red-500 focus:ring-red-100',
            disabled && 'bg-neutral-100 text-neutral-400',
          ]
            .filter(Boolean)
            .join(' ')}
        />
        {searching && (
          <span className="absolute right-3 top-1/2 -translate-y-1/2">
            <span className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-neutral-300 border-t-brand-600" />
          </span>
        )}
      </div>

      {open && results.length > 0 && (
        <ul className="absolute top-full left-0 right-0 z-50 mt-1 max-h-56 overflow-auto rounded-[var(--radius-md)] border border-neutral-200 bg-white shadow-lg">
          {results.map((r, i) => (
            <li key={`${String(r.lat)},${String(r.lon)}-${String(i)}`}>
              <button
                type="button"
                className="w-full px-3 py-2 text-left text-sm transition-colors hover:bg-brand-50 focus:bg-brand-50 focus:outline-none"
                onMouseDown={(e) => {
                  e.preventDefault();
                  handleSelect(r);
                }}
              >
                <span className="font-medium text-neutral-900">{r.name.toLowerCase()}</span>
                {r.subtitle && r.subtitle !== r.name ? (
                  <span className="ml-1 text-neutral-500">{r.subtitle.toLowerCase()}</span>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
      )}

      {error ? <p className="text-xs text-red-600">{error}</p> : null}
    </div>
  );
}