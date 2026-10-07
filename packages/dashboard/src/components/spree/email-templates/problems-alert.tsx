import { Alert, AlertDescription, AlertTitle } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import type { EmailTemplateProblem } from '../../../hooks/use-email-templates'
import { emailTemplateName } from '../../../lib/email-template-name'

/** Why a template does not render, naming the email and line where known. */
export function EmailTemplateProblemsAlert({ problems }: { problems: EmailTemplateProblem[] }) {
  const { t } = useTranslation()

  return (
    <Alert variant="destructive">
      <AlertTitle>{t('admin.email_templates.problems.title')}</AlertTitle>
      <AlertDescription>
        <ul className="list-disc pl-4">
          {problems.map((problem) => (
            <li key={`${problem.email}:${problem.line}:${problem.message}`}>
              {problem.email && `${emailTemplateName(t, problem.email.replace(/\./g, '/'))}: `}
              {problem.line
                ? t('admin.email_templates.problems.on_line', {
                    line: problem.line,
                    message: problem.message,
                  })
                : problem.message}
            </li>
          ))}
        </ul>
      </AlertDescription>
    </Alert>
  )
}
