// Content API: home, faq, guidelines, and the slug-based "editable pages"
// (donate, volunteer, ...). All expose the same readable shape: a rendered
// HTML string plus a Quill Delta JSON string for the editor. Phase 2 uses
// only `contentHtml`; the editor integration in phase 4 reads `content`.

import { useQuery } from '@tanstack/react-query';
import { apiClient } from './client';
import { useAuthStore } from '@/auth/store';

export interface HomePage {
  content: string;
  contentHtml: string;
  joinContent: string;
  joinContentHtml: string;
  donateUrl: string;
  updatedAt: string;
}

export interface SimplePage {
  content: string;
  contentHtml: string;
  updatedAt: string;
}

export interface EditablePage {
  slug: string;
  content: string;
  contentHtml: string;
  visibility: 'public' | 'members_only';
  updatedAt: string;
}

interface WireHome {
  content?: string;
  content_html?: string;
  join_content?: string;
  join_content_html?: string;
  donate_url?: string;
  updated_at: string;
}
interface WireSimple {
  content?: string;
  content_html?: string;
  updated_at: string;
}
interface WireEditable {
  slug: string;
  content?: string;
  content_html?: string;
  visibility: 'public' | 'members_only';
  updated_at: string;
}

async function fetchHome(): Promise<HomePage> {
  const { data } = await apiClient.get<WireHome>('/api/community/home/');
  return {
    content: data.content ?? '',
    contentHtml: data.content_html ?? '',
    joinContent: data.join_content ?? '',
    joinContentHtml: data.join_content_html ?? '',
    donateUrl: data.donate_url ?? '',
    updatedAt: data.updated_at,
  };
}

async function fetchSimple(path: string): Promise<SimplePage> {
  const { data } = await apiClient.get<WireSimple>(path);
  return {
    content: data.content ?? '',
    contentHtml: data.content_html ?? '',
    updatedAt: data.updated_at,
  };
}

async function fetchEditablePage(slug: string): Promise<EditablePage> {
  const { data } = await apiClient.get<WireEditable>(`/api/community/pages/${slug}/`);
  return {
    slug: data.slug,
    content: data.content ?? '',
    contentHtml: data.content_html ?? '',
    visibility: data.visibility,
    updatedAt: data.updated_at,
  };
}

export function useHome() {
  // Home is public but includes join CTA only when logged-out — same endpoint
  // for both, so no auth-keyed refetch needed.
  return useQuery({ queryKey: ['home'], queryFn: fetchHome });
}

export function useFaq() {
  return useQuery({
    queryKey: ['faq'],
    queryFn: () => fetchSimple('/api/community/faq/'),
  });
}

export function useGuidelines() {
  // Backend requires auth; the React route guard already blocks unauthed users
  // but we key on isAuthed so a login flips the cache cleanly.
  const isAuthed = useAuthStore((s) => s.status === 'authed');
  return useQuery({
    queryKey: ['guidelines', { authed: isAuthed }],
    queryFn: () => fetchSimple('/api/community/guidelines/'),
    enabled: isAuthed,
  });
}

export function useEditablePage(slug: string) {
  return useQuery({
    queryKey: ['page', slug],
    queryFn: () => fetchEditablePage(slug),
  });
}
