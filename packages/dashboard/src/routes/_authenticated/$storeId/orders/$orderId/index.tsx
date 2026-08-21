import { Slot } from '@spree/dashboard-core'
import { ErrorState, MetadataCard, ResourceLayout } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  CustomFieldsInlineCard,
  EditableApiCustomFieldsProvider,
} from '../../../../../components/spree/custom-fields/custom-fields-inline'
import {
  OrderClaimsCard,
  OrderExchangesCard,
} from '../../../../../components/spree/order-post-sale-cards'
import { OrderReturnsCard } from '../../../../../components/spree/order-returns-card'
import { FulfillmentsCard } from '../../../../../components/spree/orders/fulfillments-card'
import {
  FeesCard,
  OrderDiscountsCard,
  TaxLinesCard,
} from '../../../../../components/spree/orders/order-adjustments-cards'
import { CustomerCard } from '../../../../../components/spree/orders/order-customer-card'
import { DiscountsCard } from '../../../../../components/spree/orders/order-discounts-sidebar-card'
import { OrderHeader } from '../../../../../components/spree/orders/order-header'
import { MarketplaceCard } from '../../../../../components/spree/orders/order-marketplace-card'
import {
  InternalNoteCard,
  SpecialInstructionsCard,
  TagsCard,
} from '../../../../../components/spree/orders/order-notes-cards'
import { PaymentsCard } from '../../../../../components/spree/orders/order-payments-card'
import { OrderSkeleton } from '../../../../../components/spree/orders/order-skeleton'
import { OrderSummaryCard } from '../../../../../components/spree/orders/order-summary-card'
import { useOrder } from '../../../../../hooks/use-order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId/')({
  component: OrderDetailPage,
})

function OrderDetailPage() {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const { data: order, isLoading, error, refetch } = useOrder(orderId)

  if (isLoading) return <OrderSkeleton />
  if (error || !order) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_order')}
        description={t('admin.orders.detail.load_failed_message', { orderId })}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return (
    <ResourceLayout
      header={<OrderHeader order={order} />}
      main={
        <>
          <FulfillmentsCard order={order} />
          <OrderReturnsCard order={order} />
          <OrderExchangesCard order={order} />
          <OrderClaimsCard order={order} />
          <PaymentsCard order={order} />
          <TaxLinesCard order={order} />
          <OrderDiscountsCard order={order} />
          <FeesCard order={order} />
          <OrderSummaryCard order={order} />
          <EditableApiCustomFieldsProvider
            ownerType="Spree::Order"
            ownerId={order.id}
            resourceType="Spree::Order"
            resourceLabel={t('admin.nav.orders').toLowerCase()}
          >
            <CustomFieldsInlineCard />
          </EditableApiCustomFieldsProvider>
          <MetadataCard
            metadata={order.metadata}
            title={t('admin.components.metadata_card.title')}
            emptyTitle={t('admin.components.metadata_card.empty_title')}
            emptyDescription={t('admin.components.metadata_card.empty_description')}
          />
        </>
      }
      sidebar={
        <>
          <CustomerCard order={order} />
          <MarketplaceCard order={order} />
          <TagsCard order={order} />
          <DiscountsCard order={order} />
          <SpecialInstructionsCard order={order} />
          <InternalNoteCard order={order} />
          <Slot name="order.form_sidebar" context={{ order }} />
        </>
      }
    />
  )
}
