import type { InvoiceKind } from '@spree/core'
import { StatusBadge } from '@spree/dashboard-ui'
import { i18n } from '../lib/i18n'

/** "Invoice", "Receipt" or "Credit note" in the panel's language. */
export function invoiceKindLabel(kind: InvoiceKind | string): string {
  return i18n.t(`admin.order_documents.kinds.${kind}`, { defaultValue: kind })
}

/** An invoice's kind, with credit notes set apart because they take money back. */
export function InvoiceKindBadge({ kind }: { kind: InvoiceKind | string }) {
  return (
    <StatusBadge
      status={kind}
      tone={kind === 'credit_note' ? 'warning' : 'neutral'}
      label={invoiceKindLabel(kind)}
    />
  )
}
