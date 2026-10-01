import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { templateVariables } from '../../../lib/email-template-variables'

/** The variables a template receives, with the fields worth pointing out. */
export function EmailTemplateVariablesCard({ templateId }: { templateId: string }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.email_templates.variables.title')}</CardTitle>
        <CardDescription>{t('admin.email_templates.variables.description')}</CardDescription>
      </CardHeader>
      <CardContent>
        <dl className="grid gap-3 sm:grid-cols-2">
          {templateVariables(templateId).map((variable) => (
            <div key={variable.name} className="flex flex-col gap-1">
              <dt className="font-mono text-sm">{`{{ ${variable.name} }}`}</dt>
              <dd className="text-sm text-muted-foreground">{t(variable.descriptionKey)}</dd>
              {variable.fields && (
                <dd className="flex flex-wrap gap-1">
                  {variable.fields.map((field) => (
                    <code key={field} className="rounded bg-muted px-1.5 py-0.5 text-xs">
                      {`${variable.name}.${field}`}
                    </code>
                  ))}
                </dd>
              )}
            </div>
          ))}
        </dl>
      </CardContent>
    </Card>
  )
}
