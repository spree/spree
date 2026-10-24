import { adminClient, i18n, useResourceMutation } from '@spree/dashboard-core'

export function useResendDigitalLinks(orderId: string) {
  return useResourceMutation({
    mutationFn: () => adminClient.orders.resendDigitalLinks(orderId),
    successMessage: i18n.t('admin.messages.digital_links_email_sent'),
  })
}

export function useResetDigitalLink(orderId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.digitalLinks.reset(id),
    invalidate: [['orders', orderId]],
    successMessage: i18n.t('admin.messages.digital_link_reset'),
  })
}
