import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { templateVariables } from '../../../lib/email-template-variables'

/** The variables a template receives, with the fields worth pointing out. */
export function EmailTemplateVariablesCard({
  templateId,
  onInsert,
}: {
  templateId: string
  /** Inserts a variable into the template; chips are plain text without it. */
  onInsert?: (text: string) => void
}) {
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
                  {variable.fields.map((field) => {
                    const path = `${variable.name}.${field}`
                    return onInsert ? (
                      <button
                        key={field}
                        type="button"
                        aria-label={t('admin.email_templates.variables.insert', { variable: path })}
                        onClick={() => onInsert(`{{ ${path} }}`)}
                        className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs hover:bg-accent-strong focus-visible:outline-2 focus-visible:outline-ring"
                      >
                        {path}
                      </button>
                    ) : (
                      <code key={field} className="rounded bg-muted px-1.5 py-0.5 text-xs">
                        {path}
                      </code>
                    )
                  })}
                </dd>
              )}
            </div>
          ))}
        </dl>
      </CardContent>
    </Card>
  )
}
