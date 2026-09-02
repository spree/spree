import type { Customer } from '@spree/admin-sdk'
import { formatStoreDateTime, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  useConfirm,
} from '@spree/dashboard-ui'
import { DownloadIcon, ShieldIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useAnonymizeCustomer, useExportCustomerData } from '../../../hooks/use-customers'

/**
 * The two GDPR actions a merchant needs when a subject request arrives by
 * email: produce a copy of the data, or erase it.
 *
 * Erasure keeps the orders — the financial record has its own retention
 * obligation — so the card says so rather than leaving the merchant to guess
 * what an irreversible button will destroy.
 */
export function CustomerPrivacyCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const confirm = useConfirm()
  const anonymizeMutation = useAnonymizeCustomer(customer.id)
  const exportMutation = useExportCustomerData(customer.id)

  const anonymized = Boolean(customer.anonymized_at)

  async function handleExport() {
    const payload = await exportMutation.mutateAsync()

    // Handed to the merchant as a file because that is what they forward to
    // the person who asked. Revoked immediately — the object URL holds the
    // whole payload in memory.
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' }),
    )
    const link = document.createElement('a')
    link.href = url
    link.download = `customer-${customer.id}.json`
    link.click()
    URL.revokeObjectURL(url)
  }

  async function handleAnonymize() {
    const confirmed = await confirm({
      title: t('admin.customers.privacy.anonymize_confirm_title'),
      message: t('admin.customers.privacy.anonymize_confirm_message'),
      variant: 'destructive',
      confirmLabel: t('admin.customers.privacy.anonymize'),
    })

    if (confirmed) anonymizeMutation.mutate()
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.customers.privacy.title')}</CardTitle>
        <CardDescription>{t('admin.customers.privacy.description')}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {customer.email_marketing_consent_updated_at && (
          <p className="text-sm text-muted-foreground">
            {t('admin.customers.privacy.consent_updated', {
              date: formatStoreDateTime(customer.email_marketing_consent_updated_at, timezone),
            })}
          </p>
        )}

        {anonymized ? (
          <p className="text-sm text-muted-foreground">
            {t('admin.customers.privacy.already_anonymized', {
              date: formatStoreDateTime(customer.anonymized_at as string, timezone),
            })}
          </p>
        ) : (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleExport}
              disabled={exportMutation.isPending}
            >
              <DownloadIcon className="size-4" />
              {t('admin.customers.privacy.export')}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={handleAnonymize}
              disabled={anonymizeMutation.isPending}
            >
              <ShieldIcon className="size-4" />
              {t('admin.customers.privacy.anonymize')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
