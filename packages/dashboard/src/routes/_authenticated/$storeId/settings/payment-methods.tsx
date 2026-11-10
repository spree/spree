import { Can, PageHeader, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Card,
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { BanknoteIcon, CreditCardIcon, ListOrderedIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  CreatePaymentMethodSheet,
  EditPaymentMethodSheet,
} from '../../../../components/spree/payment-method-editors/payment-method-sheets'
import { CheckoutOrderSheet } from '../../../../components/spree/payments/checkout-order-sheet'
import { PaymentCaptureSection } from '../../../../components/spree/payments/payment-capture-section'
import { PaymentMethodList } from '../../../../components/spree/payments/payment-method-list'
import { usePaymentMethods, usePaymentMethodTypes } from '../../../../hooks/use-payment-methods'
import { useStoreSettings } from '../../../../hooks/use-store-settings'
import { filterPaymentMethodProviderTypes } from '../../../../schemas/payment-method'

/** `new` names the provider to set up, or `manual` for the store's own methods. */
const MANUAL = 'manual'

const paymentsSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.string().optional(),
  order: z.coerce.boolean().optional(),
})

type PaymentsSearch = z.infer<typeof paymentsSearchSchema>

export const Route = createFileRoute('/_authenticated/$storeId/settings/payment-methods')({
  validateSearch: paymentsSearchSchema,
  component: PaymentsPage,
})

function PaymentsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const canCreate = permissions.can('create', Subject.PaymentMethod)
  const canReorder = permissions.can('update', Subject.PaymentMethod)
  const canEditStore = permissions.can('update', Subject.Store)

  const { data: methodsResponse, isLoading } = usePaymentMethods()
  const { data: typesResponse } = usePaymentMethodTypes({ enabled: canCreate })
  const { data: store } = useStoreSettings()

  // Checkout lists methods by position, so every list here follows it too.
  const methods = useMemo(
    () => [...(methodsResponse?.data ?? [])].sort((a, b) => a.position - b.position),
    [methodsResponse],
  )
  const providerMethods = methods.filter((method) => method.third_party)
  const manualMethods = methods.filter((method) => !method.third_party)
  const addableTypes = useMemo(
    () => filterPaymentMethodProviderTypes(typesResponse?.data ?? []),
    [typesResponse],
  )
  const availableProviders = addableTypes.filter((type) => type.third_party && !type.superseded)
  const canAddManual = canCreate && addableTypes.some((type) => !type.third_party)

  const updateSearch = (patch: Partial<PaymentsSearch>) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const next: Record<string, unknown> = { ...prev, ...patch }
        for (const key of Object.keys(next)) if (next[key] === undefined) delete next[key]
        return next as never
      },
    })
  const closeSheets = () => updateSearch({ edit: undefined, new: undefined, order: undefined })

  const settingUpProvider = availableProviders.find((type) => type.type === search.new)
  const addManual = () => updateSearch({ new: MANUAL })

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        docsPath="settings/payments"
        title={t('admin.pages.settings.payments.title')}
        description={t('admin.pages.settings.payments.description')}
        actions={
          canReorder && methods.length > 1 ? (
            <Button variant="outline" size="sm" onClick={() => updateSearch({ order: true })}>
              <ListOrderedIcon className="size-4" />
              {t('admin.pages.settings.payments.checkout_order.cta')}
            </Button>
          ) : undefined
        }
      />

      <Section>
        <SectionHeader>
          <SectionTitle>
            <CreditCardIcon />
            {t('admin.pages.settings.payments.providers_title')}
          </SectionTitle>
        </SectionHeader>
        {isLoading ? (
          <Skeleton className="h-36 w-full" />
        ) : providerMethods.length === 0 && availableProviders.length === 0 ? (
          <Card>
            <Empty className="p-6">
              <EmptyHeader>
                <EmptyTitle>{t('admin.pages.settings.payments.providers_empty.title')}</EmptyTitle>
                <EmptyDescription>
                  {t('admin.pages.settings.payments.providers_empty.description')}
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          </Card>
        ) : (
          <PaymentMethodList
            methods={providerMethods}
            available={availableProviders}
            onConfigure={(id) => updateSearch({ edit: id })}
            onSetUp={(type) => updateSearch({ new: type })}
          />
        )}
      </Section>

      <Section>
        <SectionHeader>
          <SectionTitle>
            <BanknoteIcon />
            {t('admin.pages.settings.payments.manual_title')}
          </SectionTitle>
          {canAddManual && manualMethods.length > 0 && (
            <SectionActions>
              <Button variant="outline" size="sm" onClick={addManual}>
                <PlusIcon className="size-4" />
                {t('admin.pages.settings.payments.add_manual')}
              </Button>
            </SectionActions>
          )}
        </SectionHeader>
        {isLoading ? (
          <Skeleton className="h-16 w-full" />
        ) : manualMethods.length === 0 ? (
          <Card>
            <Empty className="p-6">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <BanknoteIcon />
                </EmptyMedia>
                <EmptyTitle>{t('admin.pages.settings.payments.manual_empty.title')}</EmptyTitle>
                <EmptyDescription>
                  {t('admin.pages.settings.payments.manual_empty.description')}
                </EmptyDescription>
              </EmptyHeader>
              {canAddManual && (
                <EmptyContent>
                  <Button variant="outline" size="sm" onClick={addManual}>
                    <PlusIcon className="size-4" />
                    {t('admin.pages.settings.payments.add_manual')}
                  </Button>
                </EmptyContent>
              )}
            </Empty>
          </Card>
        ) : (
          <PaymentMethodList
            methods={manualMethods}
            onConfigure={(id) => updateSearch({ edit: id })}
          />
        )}
      </Section>

      {store && canEditStore && <PaymentCaptureSection key={store.capture_method} store={store} />}

      {search.edit && (
        <EditPaymentMethodSheet id={search.edit} open onOpenChange={(o) => !o && closeSheets()} />
      )}
      {settingUpProvider && (
        <CreatePaymentMethodSheet
          key={settingUpProvider.type}
          initialType={settingUpProvider}
          open
          onOpenChange={(o) => !o && closeSheets()}
        />
      )}
      <Can I="create" a={Subject.PaymentMethod}>
        {search.new === MANUAL && (
          <CreatePaymentMethodSheet manualOnly open onOpenChange={(o) => !o && closeSheets()} />
        )}
      </Can>
      {search.order && (
        <CheckoutOrderSheet methods={methods} open onOpenChange={(o) => !o && closeSheets()} />
      )}
    </div>
  )
}
