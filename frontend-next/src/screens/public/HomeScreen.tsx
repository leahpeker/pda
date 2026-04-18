import { Link } from 'react-router-dom';
import { useHome } from '@/api/content';
import { useAuthStore } from '@/auth/store';
import { HtmlContent } from '@/components/HtmlContent';
import { ContentContainer, ContentError, ContentLoading } from './ContentContainer';

export default function HomeScreen() {
  const { data, isPending, isError } = useHome();
  const isAuthed = useAuthStore((s) => s.status === 'authed');

  if (isPending) return <ContentLoading />;
  if (isError) return <ContentError message="couldn't load the home page — try refreshing" />;

  return (
    <ContentContainer>
      <HtmlContent html={data.contentHtml} />

      {!isAuthed && data.joinContentHtml ? (
        <section className="mt-10 rounded-lg border border-neutral-200 bg-white p-6">
          <HtmlContent html={data.joinContentHtml} />
          <Link
            to="/join"
            className="mt-4 inline-flex h-10 items-center rounded-md bg-neutral-900 px-4 text-sm font-medium text-white hover:bg-neutral-800"
          >
            request to join
          </Link>
        </section>
      ) : null}

      {data.donateUrl ? (
        <div className="mt-8 flex justify-center">
          <a
            href={data.donateUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-10 items-center rounded-md bg-neutral-900 px-4 text-sm font-medium text-white hover:bg-neutral-800"
          >
            donate
          </a>
        </div>
      ) : null}
    </ContentContainer>
  );
}
