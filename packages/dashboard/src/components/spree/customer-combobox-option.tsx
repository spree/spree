import type { Customer } from '@spree/admin-sdk'
import { CustomerIdentity } from './customers/customer-identity'

export { customerHasName } from './customers/customer-identity'

/** Dropdown row for a customer picker: the shared identity, compact. */
export function CustomerComboboxOption({ customer }: { customer: Customer }) {
  return <CustomerIdentity customer={customer} size="sm" />
}
