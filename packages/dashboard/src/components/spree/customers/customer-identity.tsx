import type { Customer } from '@spree/admin-sdk'
import { PersonIdentity } from '../person-identity'

/** Whether a customer has a name to show in place of their email. */
export function customerHasName(customer: Pick<Customer, 'first_name' | 'last_name'>): boolean {
  return !!(customer.first_name || customer.last_name)
}

/**
 * A customer as a `PersonIdentity`: name and email, or the email alone.
 *
 * `customer` may be missing where a record only carries the email (a list
 * fetched without `expand=customer`); `email` then stands in for it.
 */
export function CustomerIdentity({
  customer,
  email = customer?.email,
  linkTo,
  size,
  className,
}: {
  customer?: Customer | null
  email?: string | null
  /** Makes the whole block — avatar, name and email — a link to this customer's page. */
  linkTo?: { storeId: string; customerId: string }
  size?: 'default' | 'sm'
  className?: string
}) {
  return (
    <PersonIdentity
      name={customer && customerHasName(customer) ? customer.full_name : null}
      email={email ?? customer?.id}
      link={linkTo && { to: '/$storeId/customers/$customerId', params: linkTo }}
      size={size}
      className={className}
    />
  )
}
