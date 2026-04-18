import { useGuidelines } from '@/api/content';
import { HtmlContent } from '@/components/HtmlContent';
import { ContentContainer, ContentError, ContentLoading } from './ContentContainer';

export default function GuidelinesScreen() {
  // The RequireAuth guard blocks unauthed users upstream, so we never see
  // the empty/disabled query state here.
  const { data, isPending, isError } = useGuidelines();

  if (isPending) return <ContentLoading />;
  if (isError) {
    return <ContentError message="couldn't load the guidelines — try refreshing" />;
  }

  return (
    <ContentContainer>
      <h1 className="mb-4 text-2xl font-medium tracking-tight">community guidelines</h1>
      <HtmlContent html={data.contentHtml} />
    </ContentContainer>
  );
}
