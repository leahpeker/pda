import { render, screen, waitFor } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { QueryClientProvider, QueryClient } from '@tanstack/react-query';
import LoginScreen from './screens/auth/LoginScreen';

vi.mock('./api/auth', () => ({
  login: vi.fn(),
  magicLogin: vi.fn(),
  restoreSession: vi.fn(),
  logout: vi.fn(),
  fetchMe: vi.fn(),
  completeOnboarding: vi.fn(),
  changePassword: vi.fn(),
}));

function renderWith(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('LoginScreen', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders phone + password fields', async () => {
    renderWith(<LoginScreen />);
    await waitFor(() => {
      expect(screen.getByLabelText(/phone number/i)).toBeInTheDocument();
    });
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });
});
