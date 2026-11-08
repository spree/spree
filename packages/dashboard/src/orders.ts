// @spree/dashboard/orders — the order building blocks, for plugins whose
// pages work on an order in their own layout (a quote over a draft order, an
// approval queue) instead of slotting cards into the order page.
//
// The editor is staged: `useOrderItemsEditor` owns the form, the table and
// picker write to it, and nothing reaches the server until its `save`. The
// cards read the order they are given and save their own edits, as they do on
// the order page.

export { CompanyComboboxOption } from './components/spree/company-combobox-option'
export { AddLineItemDialog } from './components/spree/orders/line-item-dialogs'
export { CustomerCard } from './components/spree/orders/order-customer-card'
export { DiscountsCard } from './components/spree/orders/order-discounts-sidebar-card'
export { OrderEditItemsTable } from './components/spree/orders/order-edit-items-table'
export { OrderLogisticsCard } from './components/spree/orders/order-logistics-card'
export {
  InternalNoteCard,
  SpecialInstructionsCard,
  TagsCard,
} from './components/spree/orders/order-notes-cards'
export { OrderPurchaseOrderCard } from './components/spree/orders/order-purchase-order-card'
export { OrderSummaryCard } from './components/spree/orders/order-summary-card'
export { OrderTotalsCard } from './components/spree/orders/order-totals-card'
// The pickers the new-order page starts an order with: companies, then the
// customers who can buy for the chosen one.
export { companyAutocompleteProps } from './hooks/use-companies'
export { customerAutocompleteProps } from './hooks/use-customers'
export { useOrder, useOrderMutation } from './hooks/use-order'
export { useOrderItemsEditor } from './hooks/use-order-items-editor'
export type { OrderEditFormValues, OrderEditItemValues } from './schemas/order'
