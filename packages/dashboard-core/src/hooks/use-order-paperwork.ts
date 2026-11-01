import type { Invoice, OrderDocument } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import {
  getApiClient,
  type PanelInvoiceCreateParams,
  type PanelOrderDocumentCreateParams,
} from '../api-client'
import { i18n } from '../lib/i18n'
import { useResourceKey } from '../lib/query-keys'
import { useResourceMutation } from './use-resource-mutation'

/**
 * The registered panel's order paperwork resource. Throws rather than
 * answering undefined: the Documents card is the only caller, and a panel
 * that renders it without registering the resource is misconfigured.
 */
function resource() {
  const paperwork = getApiClient().orderPaperwork
  if (!paperwork) {
    throw new Error(
      '@spree/dashboard-core: this panel registered no `orderPaperwork` resource, so the ' +
        'order Documents card cannot load. Add one in setApiClient(), or drop the card.',
    )
  }
  return paperwork
}

export function useOrderInvoices(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-invoices', orderId),
    queryFn: () => resource().invoices.list(orderId),
  })
}

export function useOrderInvoiceRequests(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-invoice-requests', orderId),
    queryFn: () => resource().invoiceRequests.list(orderId),
  })
}

export function useOrderDocuments(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-documents', orderId),
    queryFn: () => resource().documents.list(orderId),
  })
}

// Uploading an invoice can fulfil the buyer's request, so both lists refresh.
const invoiceKeys = (orderId: string) => [
  ['order-invoices', orderId],
  ['order-invoice-requests', orderId],
  ['invoices'],
]

export function useCreateOrderInvoice(orderId: string) {
  return useResourceMutation<Invoice, Error, PanelInvoiceCreateParams>({
    mutationFn: (params) => resource().invoices.create(orderId, params),
    invalidate: invoiceKeys(orderId),
    successMessage: i18n.t('admin.order_documents.invoice_uploaded'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useDeleteOrderInvoice(orderId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => resource().invoices.delete(id),
    invalidate: invoiceKeys(orderId),
    successMessage: i18n.t('admin.common.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useResendOrderInvoice() {
  return useResourceMutation<Invoice, Error, string>({
    // Sending happens later in a job, so there is nothing new to refetch.
    mutationFn: (id) => resource().invoices.resend(id),
    successMessage: i18n.t('admin.order_documents.invoice_resent'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useCreateOrderDocument(orderId: string) {
  return useResourceMutation<OrderDocument, Error, PanelOrderDocumentCreateParams>({
    mutationFn: (params) => resource().documents.create(orderId, params),
    invalidate: [['order-documents', orderId]],
    successMessage: i18n.t('admin.order_documents.document_uploaded'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateOrderDocument(orderId: string) {
  return useResourceMutation<
    OrderDocument,
    Error,
    { id: string; params: { label?: string; customer_visible?: boolean } }
  >({
    mutationFn: ({ id, params }) => resource().documents.update(orderId, id, params),
    invalidate: [['order-documents', orderId]],
    successMessage: i18n.t('admin.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteOrderDocument(orderId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => resource().documents.delete(orderId, id),
    invalidate: [['order-documents', orderId]],
    successMessage: i18n.t('admin.common.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}
