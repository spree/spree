import type { Customer } from '@spree/admin-sdk'
import { PageHeader, Slot, Subject } from '@spree/dashboard-core'
import { Badge, ErrorState, MetadataCard, ResourceLayout } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  CustomFieldsInlineCard,
  EditableApiCustomFieldsProvider,
} from '../../../../components/spree/custom-fields/custom-fields-inline'
import { CustomerAddressesCard } from '../../../../components/spree/customers/customer-addresses-card'
import { CustomerGroupsCard } from '../../../../components/spree/customers/customer-groups-card'
import { CustomerInternalNoteCard } from '../../../../components/spree/customers/customer-internal-note-card'
import { CustomerLastOrderCard } from '../../../../components/spree/customers/customer-last-order-card'
import { CustomerLifetimeStatsCard } from '../../../../components/spree/customers/customer-lifetime-stats-card'
import { CustomerOrdersCard } from '../../../../components/spree/customers/customer-orders-card'
import { CustomerPrivacyCard } from '../../../../components/spree/customers/customer-privacy-card'
import { CustomerProfileCard } from '../../../../components/spree/customers/customer-profile-card'
import { CustomerStoreCreditsCard } from '../../../../components/spree/customers/customer-store-credits-card'
import { CustomerTaxIdentifiersCard } from '../../../../components/spree/customers/customer-tax-identifiers-card'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import { useCustomer, useCustomerOrders } from '../../../../hooks/use-customers'
import { customerDisplayName } from '../../../../lib/erased-customer'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'

export const Route = createFileRoute('/_authenticated/$storeId/customers/$customerId')({
  component: CustomerDetailPage,
})

function CustomerDetailPage() {
  const { t } = useTranslation()
  const { customerId } = Route.useParams()
  const { data: customer, isLoading, error, refetch } = useCustomer(customerId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !customer) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_customer')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CustomerBody customer={customer} />
}

function CustomerBody({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const { data, isLoading } = useCustomerOrders(customer.id, { limit: 10 })
  const orders = data?.data ?? []
  const totalCount = data?.meta?.count ?? orders.length
  const lastCompletedOrder = orders.find((o) => o.status === 'complete')

  const defaultShipping = customer.addresses?.find((a) => a.is_default_shipping)
  const location = [defaultShipping?.city, defaultShipping?.country_code].filter(Boolean).join(', ')

  return (
    <ResourceLayout
      header={
        <>
          <PageHeader
            title={customerDisplayName(customer, t('admin.customers.erased.name'))}
            subtitle={location || undefined}
            backTo="customers"
            badges={[
              // First, and in the warning colour: everything else on this page
              // reads differently once you know the person asked to be
              // forgotten — the blank fields are an answered request, not
              // missing data.
              ...(customer.anonymized
                ? [
                    <Badge key="erased" variant="destructive">
                      {t('admin.customers.erased.badge')}
                    </Badge>,
                  ]
                : []),
              ...(customer.tags?.map((tag) => <Badge key={tag}>{tag}</Badge>) ?? []),
            ]}
            // No delete here. Destroying the row and erasing the person were
            // two buttons that never both applied — deletion is refused once
            // someone has bought anything, which is exactly when a real
            // erasure request arrives. Worse, the milder-sounding one was the
            // destructive one: it took the store credit and gift cards with
            // it. Privacy and data, below, is the one action, and it behaves
            // the same whatever the customer has done.
            resource={{ id: customer.id }}
            jsonPreview={{
              title: `Customer ${customer.email}`,
              // Reuse what `useCustomer` already loaded — opening the drawer
              // shouldn't trigger a duplicate fetch.
              fetch: () => Promise.resolve(customer),
              endpoint: `/api/v3/admin/customers/${customer.id}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
          />
          <CustomerLifetimeStatsCard customer={customer} />
        </>
      }
      main={
        <>
          {lastCompletedOrder && <CustomerLastOrderCard order={lastCompletedOrder} />}
          <CustomerOrdersCard
            customer={customer}
            orders={orders}
            totalCount={totalCount}
            isLoading={isLoading}
          />
          <CustomerStoreCreditsCard customer={customer} />
          <EditableApiCustomFieldsProvider
            ownerType={Subject.Customer}
            ownerId={customer.id}
            resourceType={Subject.Customer}
            resourceLabel={t('admin.nav.customers').toLowerCase()}
          >
            <CustomFieldsInlineCard />
          </EditableApiCustomFieldsProvider>
          <MetadataCard
            metadata={customer.metadata}
            title={t('admin.components.metadata_card.title')}
            emptyTitle={t('admin.components.metadata_card.empty_title')}
            emptyDescription={t('admin.components.metadata_card.empty_description')}
          />
        </>
      }
      sidebar={
        <>
          <CustomerProfileCard customer={customer} />
          <CustomerGroupsCard customer={customer} />
          <CustomerAddressesCard customer={customer} />
          <CustomerTaxIdentifiersCard customer={customer} />
          <CustomerInternalNoteCard customer={customer} />
          <CustomerPrivacyCard customer={customer} />
          <Slot name="customer.form_sidebar" context={{ customer }} />
        </>
      }
    />
  )
}
