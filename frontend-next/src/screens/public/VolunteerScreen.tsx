import { isAxiosError } from 'axios';
import { useEditablePage } from '@/api/content';
import { HtmlContent } from '@/components/HtmlContent';
import { ContentContainer, ContentError, ContentLoading } from './ContentContainer';

export default function VolunteerScreen() {
  const { data, isPending, error } = useEditablePage('volunteer');
  if (isPending) return <ContentLoading />;
  if (error) {
    if (isAxiosError(error) && error.response?.status === 403) {
      return <ContentError message="this page is for members only" />;
    }
    return <ContentError message="couldn't load the volunteer page — try refreshing" />;
  }
  return (
    <ContentContainer>
      <h1 className="mb-4 text-2xl font-medium tracking-tight">volunteer</h1>
      <HtmlContent html={data.contentHtml} />
    </ContentContainer>
  );
}
