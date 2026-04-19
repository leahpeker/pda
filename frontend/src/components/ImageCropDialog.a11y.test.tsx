import React from 'react';
import { render } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { axe } from 'vitest-axe';

vi.mock('react-easy-crop', () => ({
  default: ({ cropShape }: { cropShape?: string }) => (
    <div data-testid="cropper" data-crop-shape={cropShape} />
  ),
}));

vi.mock('@/utils/cropImage', () => ({
  cropImage: vi.fn().mockResolvedValue(new Blob(['img'], { type: 'image/png' })),
}));

import { ImageCropDialog } from './ImageCropDialog';

beforeEach(() => {
  vi.stubGlobal('URL', {
    createObjectURL: vi.fn().mockReturnValue('blob:mock-url'),
    revokeObjectURL: vi.fn(),
  });
});

function makeFile() {
  return new File(['img-data'], 'photo.png', { type: 'image/png' });
}

describe('ImageCropDialog accessibility', () => {
  it('round mode has no axe violations', async () => {
    const { container } = render(
      <ImageCropDialog
        file={makeFile()}
        shape="round"
        onCancel={vi.fn()}
        onCrop={vi.fn()}
      />,
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('rect mode has no axe violations', async () => {
    const { container } = render(
      <ImageCropDialog
        file={makeFile()}
        shape="rect"
        onCancel={vi.fn()}
        onCrop={vi.fn()}
      />,
    );
    expect(await axe(container)).toHaveNoViolations();
  });
});
