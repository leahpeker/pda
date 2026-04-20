import { useState } from 'react';
import { isValidPhoneNumber } from 'react-phone-number-input';
import { toast } from 'sonner';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { PhoneField } from '@/components/ui/PhoneField';
import { useRequestLoginLink } from '@/api/auth';
import { extractApiError } from '@/utils/errors';

interface Props {
  open: boolean;
  initialPhone?: string;
  onClose: () => void;
}

// Outer wrapper unmounts the form on close so internal state (phone, error)
// is reseeded from `initialPhone` each time the dialog opens — no effect-based
// state syncing required.
export function RequestLoginLinkDialog({ open, initialPhone, onClose }: Props) {
  if (!open) return null;
  return <RequestLoginLinkForm initialPhone={initialPhone ?? ''} onClose={onClose} />;
}

function RequestLoginLinkForm({
  initialPhone,
  onClose,
}: {
  initialPhone: string;
  onClose: () => void;
}) {
  const [phone, setPhone] = useState(initialPhone);
  const [error, setError] = useState<string | null>(null);
  const requestLink = useRequestLoginLink();

  async function onSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    setError(null);
    if (!phone || !isValidPhoneNumber(phone)) {
      setError('enter a valid phone number');
      return;
    }
    try {
      await requestLink.mutateAsync(phone);
      toast.success('check your texts for a link 🌱');
      onClose();
    } catch (err) {
      const message = extractApiError(err, "couldn't send a link — try again");
      setError(message);
    }
  }

  return (
    <Dialog open onClose={onClose} title="send me a login link">
      <form
        onSubmit={(e) => {
          void onSubmit(e);
        }}
        className="flex flex-col gap-4"
      >
        <p className="text-sm text-muted">
          we'll text a one-tap login link to your number — works for invited members only
        </p>
        <PhoneField
          label="phone number"
          value={phone}
          onChange={setPhone}
          error={error ?? undefined}
        />
        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="ghost"
            onClick={onClose}
            disabled={requestLink.isPending}
          >
            cancel
          </Button>
          <Button type="submit" disabled={requestLink.isPending}>
            {requestLink.isPending ? 'sending…' : 'send link'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
