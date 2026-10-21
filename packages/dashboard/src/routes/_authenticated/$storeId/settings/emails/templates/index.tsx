import type { EmailTemplate } from '@spree/admin-sdk'
import { EMAIL_TEMPLATE_KINDS } from '@spree/core'
import {
  PageHeader,
  Subject,
  useDisplayName,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ErrorState,
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemTitle,
  ResourceLayout,
  Skeleton,
} from '@spree/dashboard-ui'
import { ChevronRightIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { EmailsTabs } from '../../../../../../components/spree/email-templates/emails-tabs'
import { useEmailTemplates } from '../../../../../../hooks/use-email-templates'
import { emailTemplateName } from '../../../../../../lib/email-template-name'

export const Route = createFileRoute('/_authenticated/$storeId/settings/emails/templates/')({
  component: EmailTemplatesPage,
})

function EmailTemplatesPage() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { defaultLocale } = useStore()
  const { data, isLoading, error, refetch } = useEmailTemplates(defaultLocale)

  if (!permissions.can('read', Subject.EmailTemplate)) {
    return <ErrorState title={t('admin.email_templates.errors.not_allowed')} />
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          docsPath="settings/emails"
          title={t('admin.pages.settings.emails.title')}
          description={t('admin.email_templates.list.description')}
        />
      }
      main={
        <>
          <EmailsTabs current="templates" />
          {error ? (
            <ErrorState
              title={t('admin.email_templates.errors.load_failed')}
              description={error.message}
              onRetry={() => refetch()}
            />
          ) : isLoading || !data ? (
            <Skeleton className="h-96 w-full" />
          ) : data.data.length === 0 ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                {t('admin.email_templates.list.empty')}
              </CardContent>
            </Card>
          ) : (
            EMAIL_TEMPLATE_KINDS.map((kind) => (
              <TemplateGroup
                key={kind}
                kind={kind}
                templates={data.data.filter((template) => template.kind === kind)}
              />
            ))
          )}
        </>
      }
    />
  )
}

function TemplateGroup({
  kind,
  templates,
}: {
  kind: (typeof EMAIL_TEMPLATE_KINDS)[number]
  templates: EmailTemplate[]
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  if (templates.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t(`admin.email_templates.list.groups.${kind}.title`)}</CardTitle>
        <CardDescription>
          {t(`admin.email_templates.list.groups.${kind}.description`)}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <ul className="divide-y divide-border">
          {templates.map((template) => (
            <li key={template.id}>
              <Item
                render={
                  <Link
                    to="/$storeId/settings/emails/templates/$templateId"
                    params={{ storeId, templateId: template.id }}
                  />
                }
                className="flex-nowrap gap-3 rounded-none px-4 py-3 hover:bg-accent"
              >
                <ItemContent className="min-w-0 gap-0">
                  <ItemTitle>{emailTemplateName(t, template.key)}</ItemTitle>
                  {template.subject && template.kind === 'email' && (
                    <ItemDescription className="line-clamp-1">{template.subject}</ItemDescription>
                  )}
                </ItemContent>
                <ItemActions>
                  <TemplateBadges template={template} />
                  <ChevronRightIcon className="size-4 text-muted-foreground" aria-hidden />
                </ItemActions>
              </Item>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  )
}

function TemplateBadges({ template }: { template: EmailTemplate }) {
  const { t } = useTranslation()
  const { defaultLocale: language } = useStore()
  const languageName = useDisplayName('language')
  // The list reads one language; versions in the others would otherwise look missing.
  const otherLanguages = template.customized_languages
    .filter((code) => code !== language && code !== 'any')
    .map((code) => languageName(code) ?? code)

  return (
    <div className="flex flex-wrap justify-end gap-1">
      {template.default_changed && (
        <Badge variant="warning">{t('admin.email_templates.badges.default_updated')}</Badge>
      )}
      {template.draft && <Badge variant="info">{t('admin.email_templates.badges.draft')}</Badge>}
      {otherLanguages.length > 0 && (
        <Badge variant="outline">
          {t('admin.email_templates.badges.other_languages', {
            languages: otherLanguages.join(', '),
          })}
        </Badge>
      )}
      {template.customized ? (
        <Badge variant="success">{t('admin.email_templates.badges.customized')}</Badge>
      ) : (
        <Badge variant="outline">{t('admin.email_templates.badges.default')}</Badge>
      )}
    </div>
  )
}
