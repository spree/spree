import type { EmailTemplate } from '@spree/admin-sdk'
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

const GROUPS = ['email', 'layout', 'partial'] as const

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
            GROUPS.map((kind) => (
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
  kind: (typeof GROUPS)[number]
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
              <Link
                to="/$storeId/settings/emails/templates/$templateId"
                params={{ storeId, templateId: template.id }}
                className="flex items-center gap-3 px-4 py-3 hover:bg-accent"
              >
                <div className="flex min-w-0 flex-1 flex-col">
                  <span className="font-medium">{emailTemplateName(t, template.key)}</span>
                  {template.subject && template.kind === 'email' && (
                    <span className="truncate text-sm text-muted-foreground">
                      {template.subject}
                    </span>
                  )}
                </div>
                <TemplateBadges template={template} />
                <ChevronRightIcon className="size-4 text-muted-foreground" aria-hidden />
              </Link>
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
