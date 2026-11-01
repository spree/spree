import type { Invoice, InvoiceCreateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** Commission invoices the marketplace issued a seller for one payout. */
export function usePayoutInvoices(payoutId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-payout-invoices', payoutId),
    queryFn: () => adminClient.sellerPayouts.invoices.list(payoutId, { limit: 100 }),
  })
}

export function useCreatePayoutInvoice(payoutId: string) {
  return useResourceMutation<Invoice, Error, InvoiceCreateParams>({
    mutationFn: (params) => adminClient.sellerPayouts.invoices.create(payoutId, params),
    invalidate: [['seller-payout-invoices', payoutId], ['invoices']],
    successMessage: i18n.t('admin.order_documents.invoice_uploaded'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/**
 * How many of a seller's paid orders still have no invoice or receipt: one
 * request reading the list's total, so the seller page shows what to chase.
 */
export function useSellerMissingInvoicesCount(sellerId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', 'missing-invoices', sellerId),
    queryFn: () =>
      adminClient.orders.list({
        seller_id_eq: sellerId,
        missing_invoice: true,
        limit: 1,
        fields: ['id'],
      }),
    select: (response) => response.meta.count,
  })
}
