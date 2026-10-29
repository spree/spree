import { PageHeader } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { type EnterprisePreview, enterpriseUrl } from '../../lib/enterprise-previews'
import { ENTERPRISE_BADGE_CLASS } from './enterprise-nav-badge'

/**
 * Introduces a Spree Enterprise feature where its real page will be: what it
 * does, how it works, and where to get it.
 */
export function EnterprisePreviewPage({ preview }: { preview: EnterprisePreview }) {
  const { t } = useTranslation()
  const base = `admin.enterprise.previews.${preview.id}`
  const Icon = preview.icon
  const cta = (
    <Button asChild>
      <a href={enterpriseUrl(preview.id)} target="_blank" rel="noopener noreferrer">
        {t('admin.enterprise.cta')}
      </a>
    </Button>
  )

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t(`${base}.title`)}
        subtitle={t(`${base}.subtitle`)}
        badges={
          <Badge variant="outline" className={ENTERPRISE_BADGE_CLASS} asChild>
            <a href={enterpriseUrl(preview.id)} target="_blank" rel="noopener noreferrer">
              <SparklesIcon />
              {t('admin.enterprise.badge')}
            </a>
          </Badge>
        }
        // The footer repeats the button, so a phone drops this one and gives
        // the title the full width.
        actions={<div className="hidden sm:block">{cta}</div>}
      />

      <Card>
        <CardContent className="flex items-start gap-4">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-muted-foreground">
            <Icon className="size-5" aria-hidden />
          </span>
          <p className="max-w-prose text-sm text-muted-foreground">{t(`${base}.intro`)}</p>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-3">
        {preview.benefits.map((benefit) => (
          <Card key={benefit}>
            {/* Content rather than a header: a header draws a divider, and these
                cards have nothing below it. */}
            <CardContent className="flex flex-col gap-1">
              <CardTitle>{t(`${base}.benefits.${benefit}.title`)}</CardTitle>
              <CardDescription>{t(`${base}.benefits.${benefit}.description`)}</CardDescription>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.enterprise.how_it_works')}</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="grid gap-4 md:grid-flow-col md:auto-cols-fr">
            {preview.steps.map((step, index) => (
              <li key={step} className="flex items-start gap-3">
                <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-medium tabular-nums">
                  {index + 1}
                </span>
                <span className="flex flex-col gap-1">
                  <span className="text-sm font-medium">{t(`${base}.steps.${step}.title`)}</span>
                  <span className="text-sm text-muted-foreground">
                    {t(`${base}.steps.${step}.description`)}
                  </span>
                </span>
              </li>
            ))}
          </ol>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="flex flex-col items-start gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="max-w-prose text-sm text-muted-foreground">
            {t('admin.enterprise.footer')}
          </p>
          {cta}
        </CardContent>
      </Card>
    </div>
  )
}
