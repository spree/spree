import type { Customer } from '@spree/admin-sdk'

/** Whether a customer has a name to show in place of their email. */
export function customerHasName(customer: Customer): boolean {
  return !!(customer.first_name || customer.last_name)
}

/** Dropdown row for a customer picker — the name, with the email under it. */
export function CustomerComboboxOption({ customer }: { customer: Customer }) {
  if (!customerHasName(customer)) {
    return <div className="font-medium">{customer.email ?? customer.id}</div>
  }

  return (
    <div>
      <div className="font-medium">{customer.full_name}</div>
      {customer.email && <div className="text-muted-foreground text-xs">{customer.email}</div>}
    </div>
  )
}
