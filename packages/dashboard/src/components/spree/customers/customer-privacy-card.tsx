import type { Customer } from '@spree/admin-sdk'
import {
  downloadFromApi,
  formatStoreDateTime,
  getApiClient,
  useAuth,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { DownloadIcon, ShieldIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useAnonymizeCustomer } from '../../../hooks/use-customers'

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
  const { token } = useAuth()
  const confirm = useConfirm()
  const anonymizeMutation = useAnonymizeCustomer(customer.id)
  const [exporting, setExporting] = useState(false)

  const anonymized = Boolean(customer.anonymized_at)

  // Streamed through the admin endpoint rather than fetched and re-serialized,
  // so the file the merchant forwards is exactly what the server produced.
  async function handleExport() {
    setExporting(true)

    try {
      await downloadFromApi(
        token,
        // A full engine path: downloadFromApi resolves against the API
        // origin, not the SDK's admin base.
        `/api/v3/admin/customers/${customer.id}/export`,
        `customer-${customer.id}.json`,
        getApiClient().downloadHeaders?.() ?? {},
      )
    } catch (error) {
      // A click handler that swallows the failure leaves the merchant staring
      // at a button that did nothing.
      toastManager.add({
        type: 'error',
        title: t('admin.customers.privacy.export_failed'),
        description: error instanceof Error ? error.message : String(error),
      })
    } finally {
      setExporting(false)
    }
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

        {anonymized && (
          <p className="text-sm text-muted-foreground">
            {t('admin.customers.privacy.already_anonymized', {
              date: formatStoreDateTime(customer.anonymized_at as string, timezone),
            })}
          </p>
        )}

        <div className="flex flex-wrap gap-2">
          {/* Exporting an erased account would hand back the tombstone, so it
              goes once there is nothing left to disclose. */}
          {!anonymized && (
            <Button variant="outline" size="sm" onClick={handleExport} disabled={exporting}>
              <DownloadIcon className="size-4" />
              {t('admin.customers.privacy.export')}
            </Button>
          )}
          {/* Erasing stays, because personal data can come back onto an erased
              account — an address added to finish an old order, a note typed
              here — and running it again is the only thing that takes it off.
              Hiding the button after the first run would strand it. */}
          <Button
            variant="destructive"
            size="sm"
            onClick={handleAnonymize}
            disabled={anonymizeMutation.isPending}
          >
            <ShieldIcon className="size-4" />
            {t(
              anonymized
                ? 'admin.customers.privacy.anonymize_again'
                : 'admin.customers.privacy.anonymize',
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
