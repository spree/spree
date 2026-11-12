import type { PaymentMethod, PaymentMethodType } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import type { TFunction } from 'i18next'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdatePaymentMethod } from '../../../hooks/use-payment-methods'
import { isTestGateway } from '../../../schemas/payment-method'
import { IntegrationCard } from '../integrations/integration-card'
import { paymentProviderLabel } from '../payment-method-editors/payment-method-sheets'

function paymentStatusLabels(t: TFunction) {
  return {
    active: t('admin.integrations.status.active'),
    inactive: t('admin.payment_methods.status.disabled'),
    not_connected: t('admin.integrations.status.not_connected'),
  }
}

/** A payment provider this store has set up, with a switch to turn it on or off. */
export function PaymentMethodCard({
  paymentMethod,
  groupTag,
  onConfigure,
}: {
  paymentMethod: PaymentMethod
  /** Leading tag naming the group, for galleries that mix kinds of integration. */
  groupTag?: ReactNode
  onConfigure: () => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const canWrite = permissions.can('update', Subject.PaymentMethod)
  const updateMutation = useUpdatePaymentMethod(paymentMethod.id, { showValidationErrors: true })
  const testMode = paymentMethod.preferences?.test_mode === true
  const provider = paymentProviderLabel(paymentMethod.type)

  return (
    <IntegrationCard
      name={paymentMethod.name}
      logoUrl={paymentMethod.logo_url}
      docsUrl={paymentMethod.docs_url}
      status={paymentMethod.active ? 'active' : 'inactive'}
      statusLabels={paymentStatusLabels(t)}
      description={
        paymentMethod.description !== paymentMethod.name
          ? (paymentMethod.description ?? undefined)
          : undefined
      }
      tags={
        <>
          {groupTag}
          {provider !== paymentMethod.name && <Badge variant="outline">{provider}</Badge>}
          {isTestGateway(paymentMethod.type) && (
            <Badge variant="warning">{t('admin.pages.settings.payments.test_gateway')}</Badge>
          )}
          {testMode && <Badge variant="warning">{t('admin.integrations.test_mode')}</Badge>}
          {!paymentMethod.storefront_visible && (
            <Badge variant="outline">{t('admin.payment_methods.storefront.admin_only')}</Badge>
          )}
        </>
      }
      toggle={{
        checked: paymentMethod.active,
        disabled: !canWrite,
        label: t('admin.integrations.toggle_label', { name: paymentMethod.name }),
        onCheckedChange: (active) =>
          updateMutation.mutateAsync({ active }).then((saved) => saved.active),
      }}
      actionLabel={t('admin.integrations.configure_cta')}
      onAction={onConfigure}
    />
  )
}

/** A payment provider this store can add but has not set up yet. */
export function PaymentProviderCard({
  type,
  groupTag,
  onSetUp,
}: {
  type: PaymentMethodType
  groupTag?: ReactNode
  onSetUp: () => void
}) {
  const { t } = useTranslation()

  return (
    <IntegrationCard
      name={type.label}
      logoUrl={type.logo_url}
      docsUrl={type.docs_url}
      status="not_connected"
      statusLabels={paymentStatusLabels(t)}
      description={type.description ?? undefined}
      tags={
        <>
          {groupTag}
          {isTestGateway(type.type) && (
            <Badge variant="warning">{t('admin.pages.settings.payments.test_gateway')}</Badge>
          )}
        </>
      }
      // Nothing to activate until the provider is set up; the add sheet it
      // opens starts with the method active.
      toggle={{
        checked: false,
        label: t('admin.integrations.toggle_label', { name: type.label }),
        onCheckedChange: (active) => {
          if (active) onSetUp()
          return undefined
        },
      }}
      actionLabel={t('admin.integrations.connect_cta')}
      onAction={onSetUp}
    />
  )
}
