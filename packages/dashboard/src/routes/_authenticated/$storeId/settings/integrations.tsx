import type {
  Integration,
  IntegrationTypeDefinition,
  PaymentMethod,
  PaymentMethodType,
} from '@spree/admin-sdk'
import { PageHeader, Subject, typeDescription, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Tabs,
  TabsList,
  TabsTrigger,
} from '@spree/dashboard-ui'
import { PlugIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { type ReactNode, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { ConfigureIntegrationSheet } from '../../../../components/spree/integrations/configure-integration-sheet'
import { IntegrationCard } from '../../../../components/spree/integrations/integration-card'
import {
  CreatePaymentMethodSheet,
  EditPaymentMethodSheet,
  paymentProviderLabel,
} from '../../../../components/spree/payment-method-editors/payment-method-sheets'
import {
  useIntegrations,
  useIntegrationTypes,
  useUpdateIntegration,
} from '../../../../hooks/use-integrations'
import {
  usePaymentMethods,
  usePaymentMethodTypes,
  useUpdatePaymentMethod,
} from '../../../../hooks/use-payment-methods'

const PAYMENTS_GROUP = 'payments'
const ALL_TAB = 'all'

const integrationsSearchSchema = z.object({
  tab: z.string().optional(),
  configure: z.string().optional(),
  payment_method: z.string().optional(),
  add_payment_method: z.string().optional(),
  activate: z.coerce.boolean().optional(),
})

type IntegrationsSearch = z.infer<typeof integrationsSearchSchema>

export const Route = createFileRoute('/_authenticated/$storeId/settings/integrations')({
  validateSearch: integrationsSearchSchema,
  component: IntegrationsPage,
})

function groupLabel(t: (key: string, options?: Record<string, unknown>) => string, group: string) {
  // Groups arrive as open strings from gems, so unknown ones fall back to a
  // capitalized version of the token.
  return t(`admin.integrations.groups.${group}`, {
    defaultValue: group.charAt(0).toUpperCase() + group.slice(1),
  })
}

function IntegrationsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const search = Route.useSearch()
  const { storeId } = Route.useParams()
  const { permissions } = usePermissions()
  const canReadPayments = permissions.can('read', Subject.PaymentMethod)
  const canCreatePayments = permissions.can('create', Subject.PaymentMethod)

  const { data: typesResponse, isLoading: loadingTypes } = useIntegrationTypes()
  const { data: integrationsResponse } = useIntegrations()
  const { data: paymentMethodsResponse, isLoading: loadingPaymentMethods } = usePaymentMethods({
    enabled: canReadPayments,
  })
  const { data: paymentTypesResponse, isLoading: loadingPaymentTypes } = usePaymentMethodTypes({
    enabled: canCreatePayments,
  })

  const types = useMemo(() => typesResponse?.data ?? [], [typesResponse])
  const integrationsByType = useMemo(
    () => new Map((integrationsResponse?.data ?? []).map((record) => [record.type, record])),
    [integrationsResponse],
  )
  // Only methods backed by an external provider belong with integrations;
  // checks, store credit and the like stay on the Payment methods page.
  const paymentMethods = useMemo(
    () =>
      canReadPayments
        ? (paymentMethodsResponse?.data ?? []).filter((method) => method.third_party)
        : [],
    [canReadPayments, paymentMethodsResponse],
  )
  // The server already leaves out providers installed on this store, so
  // these are only the ones still to set up.
  const availablePaymentTypes = useMemo(
    () =>
      (paymentTypesResponse?.data ?? []).filter(
        (type) => type.third_party && !type.superseded && !type.installed,
      ),
    [paymentTypesResponse],
  )

  const integrationGroups = useMemo(() => {
    const map = new Map<string, IntegrationTypeDefinition[]>()
    for (const type of types) {
      const group = type.group ?? 'other'
      map.set(group, [...(map.get(group) ?? []), type])
    }
    return [...map.entries()]
  }, [types])

  const hasPayments = paymentMethods.length > 0 || availablePaymentTypes.length > 0
  const tabs = [
    ALL_TAB,
    ...(hasPayments ? [PAYMENTS_GROUP] : []),
    ...integrationGroups.map(([group]) => group),
  ]
  const activeTab = search.tab && tabs.includes(search.tab) ? search.tab : ALL_TAB
  const showGroup = (group: string) => activeTab === ALL_TAB || activeTab === group

  const updateSearch = (patch: Partial<IntegrationsSearch>) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const next: Record<string, unknown> = { ...prev, ...patch }
        for (const key of Object.keys(next)) if (next[key] === undefined) delete next[key]
        return next as never
      },
    })

  const closeSheets = () =>
    updateSearch({
      configure: undefined,
      activate: undefined,
      payment_method: undefined,
      add_payment_method: undefined,
    })

  const configuringType = types.find((type) => type.type === search.configure)
  const addingPaymentType = availablePaymentTypes.find(
    (type) => type.type === search.add_payment_method,
  )
  // Every list feeding the gallery has to land before it can be called empty.
  const loading =
    loadingTypes ||
    (canReadPayments && loadingPaymentMethods) ||
    (canCreatePayments && loadingPaymentTypes)

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        docsPath="settings/integrations"
        title={t('admin.integrations.title')}
        description={t('admin.integrations.description')}
      />

      {!loading && types.length === 0 && !hasPayments && (
        <Empty>
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <PlugIcon />
            </EmptyMedia>
            <EmptyTitle>{t('admin.integrations.empty.title')}</EmptyTitle>
            <EmptyDescription>{t('admin.integrations.empty.description')}</EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {tabs.length > 2 && (
        <Tabs
          value={activeTab}
          onValueChange={(value) =>
            updateSearch({ tab: value === ALL_TAB ? undefined : (value as string) })
          }
          className="min-w-0 max-w-full overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          <TabsList className="w-max">
            {tabs.map((tab) => (
              <TabsTrigger key={tab} value={tab} className="whitespace-nowrap">
                {tab === ALL_TAB ? t('admin.integrations.tabs.all') : groupLabel(t, tab)}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      )}

      {hasPayments && showGroup(PAYMENTS_GROUP) && (
        <GallerySection
          title={groupLabel(t, PAYMENTS_GROUP)}
          action={
            <Button asChild variant="link" size="sm" className="h-auto p-0">
              <Link to="/$storeId/settings/payment-methods" params={{ storeId }}>
                {t('admin.integrations.manage_payment_methods')}
              </Link>
            </Button>
          }
        >
          {paymentMethods.map((paymentMethod) => (
            <PaymentMethodCard
              key={paymentMethod.id}
              paymentMethod={paymentMethod}
              onConfigure={() => updateSearch({ payment_method: paymentMethod.id })}
            />
          ))}
          {availablePaymentTypes.map((type) => (
            <PaymentProviderCard
              key={type.type}
              type={type}
              onSetUp={() => updateSearch({ add_payment_method: type.type })}
            />
          ))}
        </GallerySection>
      )}

      {integrationGroups
        .filter(([group]) => showGroup(group))
        .map(([group, groupTypes]) => (
          <GallerySection key={group} title={groupLabel(t, group)}>
            {groupTypes.map((type) => (
              <ServiceIntegrationCard
                key={type.type}
                type={type}
                integration={integrationsByType.get(type.type)}
                onConfigure={(activate) =>
                  updateSearch({ configure: type.type, activate: activate || undefined })
                }
              />
            ))}
          </GallerySection>
        ))}

      {configuringType && (
        <ConfigureIntegrationSheet
          key={`${configuringType.type}:${integrationsByType.get(configuringType.type)?.id ?? 'new'}`}
          type={configuringType}
          integration={integrationsByType.get(configuringType.type)}
          defaultActive={search.activate}
          open
          onOpenChange={(open) => !open && closeSheets()}
        />
      )}
      {search.payment_method && (
        <EditPaymentMethodSheet
          id={search.payment_method}
          open
          onOpenChange={(open) => !open && closeSheets()}
        />
      )}
      {addingPaymentType && (
        <CreatePaymentMethodSheet
          key={addingPaymentType.type}
          initialType={addingPaymentType}
          open
          onOpenChange={(open) => !open && closeSheets()}
        />
      )}
    </div>
  )
}

function GallerySection({
  title,
  action,
  children,
}: {
  title: string
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-medium text-muted-foreground text-sm">{title}</h2>
        {action}
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">{children}</div>
    </section>
  )
}

function GroupTag({ children }: { children: ReactNode }) {
  return (
    <Badge variant="secondary" className="uppercase tracking-wide">
      {children}
    </Badge>
  )
}

function ServiceIntegrationCard({
  type,
  integration,
  onConfigure,
}: {
  type: IntegrationTypeDefinition
  integration?: Integration
  /** Opens the connect sheet; `activate` pre-sets it to switch the integration on. */
  onConfigure: (activate?: boolean) => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const canWrite = permissions.can('update', Subject.Integration)
  const updateMutation = useUpdateIntegration(integration?.id ?? '', {
    showValidationErrors: true,
  })

  const status = !integration ? 'not_connected' : integration.active ? 'active' : 'inactive'

  return (
    <IntegrationCard
      name={type.name}
      logoUrl={type.logo_url}
      docsUrl={type.docs_url}
      status={status}
      statusLabels={{
        active: t('admin.integrations.status.active'),
        inactive: t('admin.integrations.status.connected_inactive'),
        not_connected: t('admin.integrations.status.not_connected'),
      }}
      description={typeDescription('integration', type.type, type.description)}
      tags={<GroupTag>{groupLabel(t, type.group ?? 'other')}</GroupTag>}
      toggle={{
        checked: integration?.active ?? false,
        disabled: !canWrite,
        label: t('admin.integrations.toggle_label', { name: type.name }),
        // Not connected yet: there are no credentials to activate, so the
        // switch opens the connect sheet ready to activate on save.
        // Connected: activating verifies the connection server-side, and a
        // refusal is toasted by the mutation while the switch flips back.
        onCheckedChange: (active) => {
          if (!integration) {
            if (active) onConfigure(true)
            return undefined
          }
          return updateMutation.mutateAsync({ active }).then((saved) => saved.active)
        },
      }}
      actionLabel={
        integration
          ? t('admin.integrations.configure_cta')
          : canWrite
            ? t('admin.integrations.connect_cta')
            : t('admin.integrations.view_cta')
      }
      onAction={() => onConfigure()}
    />
  )
}

function paymentStatusLabels(t: (key: string) => string) {
  return {
    active: t('admin.integrations.status.active'),
    inactive: t('admin.payment_methods.status.disabled'),
    not_connected: t('admin.integrations.status.not_connected'),
  }
}

function PaymentMethodCard({
  paymentMethod,
  onConfigure,
}: {
  paymentMethod: PaymentMethod
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
          <GroupTag>{groupLabel(t, PAYMENTS_GROUP)}</GroupTag>
          {provider !== paymentMethod.name && <Badge variant="outline">{provider}</Badge>}
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

function PaymentProviderCard({ type, onSetUp }: { type: PaymentMethodType; onSetUp: () => void }) {
  const { t } = useTranslation()

  return (
    <IntegrationCard
      name={type.label}
      logoUrl={type.logo_url}
      docsUrl={type.docs_url}
      status="not_connected"
      statusLabels={paymentStatusLabels(t)}
      description={type.description ?? undefined}
      tags={<GroupTag>{groupLabel(t, PAYMENTS_GROUP)}</GroupTag>}
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
