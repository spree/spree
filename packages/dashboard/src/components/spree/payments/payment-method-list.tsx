import type { PaymentMethod, PaymentMethodType } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  cn,
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemMedia,
  ItemTitle,
  Switch,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdatePaymentMethod } from '../../../hooks/use-payment-methods'
import { isTestGateway } from '../../../schemas/payment-method'
import { IntegrationLogo } from '../integrations/integration-card'
import { SetupGuideLink } from '../integrations/setup-guide-link'
import { PaymentMethodConditionsSummary } from '../payment-method-editors/payment-method-conditions'
import { paymentProviderLabel } from '../payment-method-editors/payment-method-sheets'

type MethodStatus = 'active' | 'inactive' | 'not_connected'

/**
 * Payment methods as one bordered list: those set up on this store, then the
 * providers that can be. Providers and manual methods share it so both read
 * the same. Test gateways go last, so a real provider is read first.
 *
 * Pass `onAddAccount` with the providers that can be added again, and the
 * last row of each offers another account of it.
 */
export function PaymentMethodList({
  methods,
  available = [],
  onConfigure,
  onSetUp,
  addAccountTypes = [],
  onAddAccount,
}: {
  methods: PaymentMethod[]
  available?: PaymentMethodType[]
  onConfigure: (id: string) => void
  onSetUp?: (type: string) => void
  addAccountTypes?: PaymentMethodType[]
  onAddAccount?: (type: string) => void
}) {
  const testLast = <T,>(rows: T[], type: (row: T) => string) =>
    [...rows].sort((a, b) => Number(isTestGateway(type(a))) - Number(isTestGateway(type(b))))
  const rows = testLast(methods, (method) => method.type)
  const isLastOfType = (index: number) =>
    !rows.slice(index + 1).some((other) => other.type === rows[index]?.type)

  return (
    <Card>
      <div className="mx-4 divide-y">
        {rows.map((method, index) => {
          const accountType =
            onAddAccount && isLastOfType(index)
              ? addAccountTypes.find((type) => type.type === method.type)
              : undefined
          return (
            <InstalledMethodRow
              key={method.id}
              method={method}
              onConfigure={() => onConfigure(method.id)}
              onAddAccount={accountType ? () => onAddAccount?.(accountType.type) : undefined}
            />
          )
        })}
        {testLast(available, (type) => type.type).map((type) => (
          <AvailableProviderRow key={type.type} type={type} onSetUp={() => onSetUp?.(type.type)} />
        ))}
      </div>
    </Card>
  )
}

function InstalledMethodRow({
  method,
  onConfigure,
  onAddAccount,
}: {
  method: PaymentMethod
  onConfigure: () => void
  onAddAccount?: () => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const updateMutation = useUpdatePaymentMethod(method.id, { showValidationErrors: true })
  const provider = paymentProviderLabel(method.type)
  const description = method.description !== method.name ? method.description : null

  return (
    <MethodRow
      name={method.name}
      logoUrl={method.logo_url}
      status={method.active ? 'active' : 'inactive'}
      description={description}
      badges={
        <>
          {/* The store's own methods and test gateways are named by their
              other badges, so only an outside provider is named here. */}
          {method.third_party && !isTestGateway(method.type) && provider !== method.name && (
            <Badge variant="outline">{provider}</Badge>
          )}
          {isTestGateway(method.type) && <TestGatewayBadge />}
          {method.preferences?.test_mode === true && (
            <Badge variant="warning">{t('admin.integrations.test_mode')}</Badge>
          )}
          {!method.storefront_visible && (
            <Badge variant="outline">{t('admin.payment_methods.storefront.admin_only')}</Badge>
          )}
        </>
      }
      docsUrl={method.docs_url}
      details={
        <>
          {method.storefront_visible && (
            <PaymentMethodConditionsSummary rules={method.rules ?? []} />
          )}
          {onAddAccount && (
            <Button
              variant="link"
              size="sm"
              className="h-auto self-start p-0"
              onClick={onAddAccount}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.settings.payments.add_another_account', { provider })}
            </Button>
          )}
        </>
      }
      actions={
        <>
          <Switch
            checked={updateMutation.isPending ? !method.active : method.active}
            disabled={!permissions.can('update', Subject.PaymentMethod) || updateMutation.isPending}
            aria-label={t('admin.integrations.toggle_label', { name: method.name })}
            onCheckedChange={(active) => updateMutation.mutate({ active })}
          />
          <Button variant="outline" size="sm" onClick={onConfigure}>
            {t('admin.integrations.configure_cta')}
          </Button>
        </>
      }
    />
  )
}

function AvailableProviderRow({ type, onSetUp }: { type: PaymentMethodType; onSetUp: () => void }) {
  const { t } = useTranslation()

  return (
    <MethodRow
      name={type.label}
      logoUrl={type.logo_url}
      status="not_connected"
      description={type.description}
      badges={isTestGateway(type.type) ? <TestGatewayBadge /> : null}
      docsUrl={type.docs_url}
      actions={
        <Button size="sm" onClick={onSetUp}>
          {t('admin.integrations.connect_cta')}
        </Button>
      }
    />
  )
}

function TestGatewayBadge() {
  const { t } = useTranslation()
  return <Badge variant="warning">{t('admin.pages.settings.payments.test_gateway')}</Badge>
}

function MethodRow({
  name,
  logoUrl,
  status,
  description,
  badges,
  docsUrl,
  details,
  actions,
}: {
  name: string
  logoUrl: string | null
  status: MethodStatus
  description?: string | null
  badges?: ReactNode
  docsUrl?: string | null
  /** Shown under the description, such as the method's conditions. */
  details?: ReactNode
  actions: ReactNode
}) {
  const { t } = useTranslation()
  const statusLabel = {
    active: t('admin.integrations.status.active'),
    inactive: t('admin.payment_methods.status.disabled'),
    not_connected: t('admin.integrations.status.not_connected'),
  }[status]

  return (
    // A plain wrapper takes the list's divider; the Item's own border would hide it.
    <div data-payment-method={name}>
      <Item className="flex-nowrap gap-3 rounded-none border-0 px-0 py-3">
        <ItemMedia>
          <IntegrationLogo name={name} logoUrl={logoUrl} />
        </ItemMedia>
        <ItemContent className="min-w-0">
          <ItemTitle className="flex-wrap">
            {name}
            <span className="flex items-center gap-1.5 font-normal text-muted-foreground text-xs">
              <span
                aria-hidden
                className={cn(
                  'size-1.5 shrink-0 rounded-full',
                  status === 'active' && 'bg-success',
                  status === 'inactive' && 'bg-warning',
                  status === 'not_connected' && 'bg-muted-foreground/40',
                )}
              />
              {statusLabel}
            </span>
            {badges}
          </ItemTitle>
          {description && <ItemDescription className="line-clamp-1">{description}</ItemDescription>}
          {details}
          {status === 'not_connected' && <SetupGuideLink url={docsUrl} />}
        </ItemContent>
        <ItemActions className="shrink-0 gap-3">{actions}</ItemActions>
      </Item>
    </div>
  )
}
