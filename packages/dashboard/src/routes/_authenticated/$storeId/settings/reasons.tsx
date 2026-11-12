import { PageHeader, Subject } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  ReasonSection,
  type SectionConfig,
} from '../../../../components/spree/reasons/reason-section'

export const Route = createFileRoute('/_authenticated/$storeId/settings/reasons')({
  component: ReasonsPage,
})

/**
 * The reason lists live on one page rather than four: each is a handful of
 * short rows, and a merchant setting up returns wants to see the whole
 * vocabulary at once. They stay separate lists because they answer different
 * questions — why a customer sent something back, what the merchant got wrong,
 * why money moved, and why an order never shipped at all. Tax exemption
 * reasons live with the other tax settings.
 */
const SECTIONS: SectionConfig[] = [
  {
    kind: 'return-reasons',
    subject: Subject.ReturnReason,
    titleKey: 'admin.reasons.return.title',
    helpKey: 'admin.reasons.return.help',
  },
  {
    kind: 'claim-reasons',
    subject: Subject.ClaimReason,
    titleKey: 'admin.reasons.claim.title',
    helpKey: 'admin.reasons.claim.help',
  },
  {
    kind: 'refund-reasons',
    subject: Subject.RefundReason,
    titleKey: 'admin.reasons.refund.title',
    helpKey: 'admin.reasons.refund.help',
  },
  {
    kind: 'order-cancellation-reasons',
    subject: Subject.OrderCancellationReason,
    titleKey: 'admin.reasons.order_cancellation.title',
    helpKey: 'admin.reasons.order_cancellation.help',
  },
]

function ReasonsPage() {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.reasons.title')}
        description={t('admin.reasons.description')}
        docsPath="settings/returns-configuration"
      />

      {SECTIONS.map((section) => (
        <ReasonSection key={section.kind} {...section} />
      ))}
    </div>
  )
}
