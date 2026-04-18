import { Link, useParams } from 'react-router-dom';
import { useDocument } from '@/api/docs';
import { HtmlContent } from '@/components/HtmlContent';
import { ContentContainer, ContentError, ContentLoading } from '@/screens/public/ContentContainer';

export default function DocDetailScreen() {
  const { id } = useParams<{ id: string }>();
  const { data, isPending, isError } = useDocument(id);
  if (isPending) return <ContentLoading />;
  if (isError) return <ContentError message="couldn't load this doc — try refreshing" />;

  return (
    <ContentContainer>
      <Link to="/docs" className="mb-4 inline-block text-sm text-neutral-500 hover:underline">
        ← back to docs
      </Link>
      <h1 className="mb-4 text-2xl font-medium tracking-tight">{data.title}</h1>
      <HtmlContent html={data.contentHtml} />
    </ContentContainer>
  );
}
