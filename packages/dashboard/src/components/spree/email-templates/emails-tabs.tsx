import { Subject, usePermissions } from '@spree/dashboard-core'
import { Tabs, TabsList, TabsTrigger } from '@spree/dashboard-ui'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

/** Switches between the email settings and the email templates. */
export function EmailsTabs({ current }: { current: 'settings' | 'templates' }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const { permissions } = usePermissions()

  if (!permissions.can('read', Subject.EmailTemplate)) return null

  return (
    <Tabs
      value={current}
      onValueChange={(value) =>
        navigate({
          to:
            value === 'templates'
              ? '/$storeId/settings/emails/templates'
              : '/$storeId/settings/emails',
          params: { storeId },
        })
      }
    >
      <TabsList>
        <TabsTrigger value="settings">{t('admin.email_templates.tabs.settings')}</TabsTrigger>
        <TabsTrigger value="templates">{t('admin.email_templates.tabs.templates')}</TabsTrigger>
      </TabsList>
    </Tabs>
  )
}
