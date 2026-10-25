import { Subject } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { ReasonSection } from '../../../../../components/spree/reasons/reason-section'

export const Route = createFileRoute('/_authenticated/$storeId/settings/taxes/exemption-reasons')({
  component: TaxExemptionReasonsPage,
})

function TaxExemptionReasonsPage() {
  return (
    <ReasonSection
      kind="tax-exemption-reasons"
      subject={Subject.TaxExemptionReason}
      titleKey="admin.reasons.tax_exemption.title"
      helpKey="admin.reasons.tax_exemption.help"
      withCode
    />
  )
}
