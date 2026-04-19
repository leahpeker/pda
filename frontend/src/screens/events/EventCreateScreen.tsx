import { useNavigate } from 'react-router-dom';
import { EventForm } from './form/EventForm';

export default function EventCreateScreen() {
  const navigate = useNavigate();
  return (
    <main className="bg-brand-50 dark:bg-brand-900/30 min-h-full">
      <div className="mx-auto max-w-3xl px-4 py-6 md:py-10">
        <div className="mb-5 flex items-center justify-between">
          <h1 className="text-2xl font-medium tracking-tight text-foreground">new event</h1>
          <button
            type="button"
            onClick={() => void navigate(-1)}
            className="text-sm text-muted hover:text-neutral-700 dark:hover:text-neutral-300"
          >
            cancel
          </button>
        </div>
        <EventForm />
      </div>
    </main>
  );
}
