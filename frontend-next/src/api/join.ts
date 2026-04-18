// Join-request API: fetch the dynamic question list + submit. The static
// fields (display_name, phone_number) are NOT in the question list — the form
// composes them with the server questions.
//
// The submit endpoint has three notable error shapes:
//   400 { detail }                  — validation (bad name, duplicate pending, etc.)
//   409 { detail: 'already_invited' } — phone already matches a user → /login?invited=true

import { useMutation, useQuery } from '@tanstack/react-query';
import { apiClient } from './client';

export type JoinQuestionType = 'text' | 'select';

export interface JoinQuestion {
  id: string;
  label: string;
  fieldType: JoinQuestionType;
  options: string[];
  required: boolean;
  displayOrder: number;
}

interface WireQuestion {
  id: string;
  label: string;
  field_type: JoinQuestionType;
  options?: string[];
  required?: boolean;
  display_order: number;
}

async function fetchJoinQuestions(): Promise<JoinQuestion[]> {
  const { data } = await apiClient.get<WireQuestion[]>('/api/community/join-form/');
  return data
    .map((q) => ({
      id: q.id,
      label: q.label,
      fieldType: q.field_type,
      options: q.options ?? [],
      required: q.required ?? false,
      displayOrder: q.display_order,
    }))
    .sort((a, b) => a.displayOrder - b.displayOrder);
}

export function useJoinQuestions() {
  return useQuery({ queryKey: ['join-questions'], queryFn: fetchJoinQuestions });
}

export interface SubmitJoinRequestPayload {
  displayName: string;
  phoneNumber: string;
  answers: Record<string, string>;
}

export class AlreadyInvitedError extends Error {
  constructor() {
    super('already_invited');
    this.name = 'AlreadyInvitedError';
  }
}

export function useSubmitJoinRequest() {
  return useMutation({
    mutationFn: async (payload: SubmitJoinRequestPayload) => {
      try {
        await apiClient.post('/api/community/join-request/', {
          display_name: payload.displayName,
          phone_number: payload.phoneNumber,
          answers: payload.answers,
        });
      } catch (err) {
        const status = (err as { response?: { status?: number } }).response?.status;
        if (status === 409) throw new AlreadyInvitedError();
        throw err;
      }
    },
  });
}
