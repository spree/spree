import { Subject, type SubjectName, usePermissions } from '@spree/dashboard-core'
import { Tabs, TabsList, TabsTrigger } from '@spree/dashboard-ui'
import { useNavigate, useParams, useRouterState } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

type TaxesTab = 'categories' | 'rates' | 'exemption-reasons'

/** Each tab is its own route, so a link or the back button lands on it. */
export const TAXES_TABS: { value: TaxesTab; subject: SubjectName; labelKey: string }[] = [
  { value: 'categories', subject: Subject.TaxCategory, labelKey: 'admin.taxes.tabs.categories' },
  { value: 'rates', subject: Subject.TaxRate, labelKey: 'admin.taxes.tabs.rates' },
  {
    value: 'exemption-reasons',
    subject: Subject.TaxExemptionReason,
    labelKey: 'admin.taxes.tabs.exemption_reasons',
  },
]

/** The tabs a staff member may read; none at all when only one is left. */
export function TaxesTabs() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const { permissions } = usePermissions()
  const pathname = useRouterState({ select: (state) => state.location.pathname })

  const tabs = TAXES_TABS.filter((tab) => permissions.can('read', tab.subject))
  if (tabs.length < 2) return null

  const current = tabs.find((tab) => pathname.endsWith(`/taxes/${tab.value}`))?.value

  return (
    <Tabs
      // Never undefined: on `/taxes`, before the redirect to a tab, no tab
      // matches, and an undefined value would leave Base UI uncontrolled and
      // deaf to the tab the redirect lands on.
      value={current ?? null}
      onValueChange={(value) =>
        navigate({ to: `/$storeId/settings/taxes/${value as TaxesTab}`, params: { storeId } })
      }
    >
      <TabsList>
        {tabs.map((tab) => (
          <TabsTrigger key={tab.value} value={tab.value}>
            {t(tab.labelKey)}
          </TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
  )
}
