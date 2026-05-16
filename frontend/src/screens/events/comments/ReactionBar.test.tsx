import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import type { CommentReactionSummary } from '@/models/eventComment';
import { ReactionEmoji } from '@/models/eventComment';

import { ReactionBar } from './ReactionBar';

const summary = (emoji: string, count: number, mine = false): CommentReactionSummary => ({
  emoji: emoji as CommentReactionSummary['emoji'],
  count,
  reactedByMe: mine,
});

describe('ReactionBar', () => {
  it('renders all 6 emojis and shows counts > 0', () => {
    render(
      <ReactionBar
        reactions={[summary(ReactionEmoji.Heart, 3, true)]}
        canReact
        onToggle={vi.fn()}
      />,
    );
    const heart = screen.getByRole('button', { name: /❤️/u });
    expect(heart).toHaveAttribute('aria-pressed', 'true');
    expect(heart).toHaveTextContent('3');
  });

  it('omits count when zero', () => {
    render(<ReactionBar reactions={[]} canReact onToggle={vi.fn()} />);
    const fire = screen.getByRole('button', { name: /🔥/u });
    expect(fire).not.toHaveTextContent('0');
  });

  it('disables all buttons when canReact is false', () => {
    render(<ReactionBar reactions={[]} canReact={false} onToggle={vi.fn()} />);
    for (const btn of screen.getAllByRole('button')) {
      expect(btn).toBeDisabled();
    }
  });

  it('calls onToggle with the emoji', () => {
    const onToggle = vi.fn();
    render(<ReactionBar reactions={[]} canReact onToggle={onToggle} />);
    fireEvent.click(screen.getByRole('button', { name: /🌱/u }));
    expect(onToggle).toHaveBeenCalledWith(ReactionEmoji.Seedling);
  });
});
