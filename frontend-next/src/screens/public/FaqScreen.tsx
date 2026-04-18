import { useFaq } from '@/api/content';
import { HtmlContent } from '@/components/HtmlContent';
import { ContentContainer, ContentError, ContentLoading } from './ContentContainer';

export default function FaqScreen() {
  const { data, isPending, isError } = useFaq();

  if (isPending) return <ContentLoading />;
  if (isError) return <ContentError message="couldn't load the faq — try refreshing" />;

  return (
    <ContentContainer>
      <h1 className="mb-4 text-2xl font-medium tracking-tight">faq</h1>
      <HtmlContent html={data.contentHtml} />
    </ContentContainer>
  );
}
