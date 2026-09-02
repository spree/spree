import type { Customer } from '@spree/admin-sdk'
import { PageHeader, Slot, Subject } from '@spree/dashboard-core'
import { Badge, ErrorState, MetadataCard, ResourceLayout } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
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
import { useCustomer, useCustomerOrders, useDeleteCustomer } from '../../../../hooks/use-customers'
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
  const navigate = useNavigate()
  const { data, isLoading } = useCustomerOrders(customer.id, { limit: 10 })
  const orders = data?.data ?? []
  const totalCount = data?.meta?.count ?? orders.length
  const lastCompletedOrder = orders.find((o) => o.status === 'complete')

  const defaultShipping = customer.addresses?.find((a) => a.is_default_shipping)
  const location = [defaultShipping?.city, defaultShipping?.country_code].filter(Boolean).join(', ')

  // The server hard-deletes only when the customer has no completed orders
  // (Spree::Core::DestroyWithOrdersError → 422 `customer_has_orders`). We
  // surface the API error message inline rather than swallowing the failure.
  const deleteMutation = useDeleteCustomer(customer.id)

  async function handleDelete() {
    await deleteMutation.mutateAsync()
    navigate({ to: '/$storeId/customers', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <>
          <PageHeader
            title={customer.full_name ?? customer.email}
            subtitle={location || undefined}
            backTo="customers"
            badges={customer.tags?.map((tag) => <Badge key={tag}>{tag}</Badge>)}
            resource={{ id: customer.id }}
            onDelete={handleDelete}
            deleteLabel={t('admin.customers.detail.delete_label')}
            jsonPreview={{
              title: `Customer ${customer.email}`,
              // Reuse what `useCustomer` already loaded — opening the drawer
              // shouldn't trigger a duplicate fetch.
              fetch: () => Promise.resolve(customer),
              endpoint: `/api/v3/admin/customers/${customer.id}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
          />
          {deleteMutation.error && (
            <p className="text-sm text-destructive">{(deleteMutation.error as Error).message}</p>
          )}
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
