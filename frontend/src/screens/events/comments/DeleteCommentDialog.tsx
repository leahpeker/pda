import { ConfirmDialog } from '@/components/ui/ConfirmDialog';

interface Props {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  submitting: boolean;
}

export function DeleteCommentDialog({ open, onClose, onConfirm, submitting }: Props) {
  return (
    <ConfirmDialog
      open={open}
      title="delete comment?"
      message="this can't be undone. replies will stay visible."
      confirmLabel={submitting ? 'deleting…' : 'delete'}
      cancelLabel="cancel"
      destructive
      onCancel={onClose}
      onConfirm={onConfirm}
    />
  );
}
