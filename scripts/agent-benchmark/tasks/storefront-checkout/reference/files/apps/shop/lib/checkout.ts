// The guest checkout, step by step. The pages and the bench route handler
// both call these, so they exercise the same code.
import type { Cart, CartAddressParams } from '@spree/sdk'
import { spree } from './spree'

export type CartRef = { id: string; token: string }

export type CheckoutAddress = {
  firstName: string
  lastName: string
  address1: string
  city: string
  postalCode: string
  stateCode: string
  countryCode: string
  phone: string
}

const asGuest = (cart: CartRef) => ({ spreeToken: cart.token })

export async function createCart(): Promise<CartRef> {
  const cart = await spree().carts.create()
  return { id: cart.id, token: cart.token }
}

export function getCart(cart: CartRef): Promise<Cart> {
  return spree().carts.get(cart.id, asGuest(cart))
}

export function addItem(cart: CartRef, variantId: string, quantity: number): Promise<Cart> {
  return spree().carts.items.create(cart.id, { variant_id: variantId, quantity }, asGuest(cart))
}

export function setContact(cart: CartRef, email: string, address: CheckoutAddress): Promise<Cart> {
  const shipping = {
    first_name: address.firstName,
    last_name: address.lastName,
    address1: address.address1,
    city: address.city,
    postal_code: address.postalCode,
    state_code: address.stateCode,
    country_code: address.countryCode,
    phone: address.phone,
  } as CartAddressParams
  return spree().carts.update(
    cart.id,
    { email, shipping_address: shipping, use_shipping: true },
    asGuest(cart),
  )
}

// Picks the given rate for every fulfillment, or each one's first rate.
export async function chooseDelivery(cart: CartRef, rateId?: string): Promise<Cart> {
  let current = await getCart(cart)
  for (const fulfillment of current.fulfillments ?? []) {
    const rates = fulfillment.delivery_rates ?? []
    const rate = rates.find((candidate) => candidate.id === rateId) ?? rates[0]
    if (!rate) throw new Error(`No delivery option for fulfillment ${fulfillment.id}`)
    current = await spree().carts.fulfillments.update(
      cart.id,
      fulfillment.id,
      { selected_delivery_rate_id: rate.id },
      asGuest(cart),
    )
  }
  return current
}

// Payment methods that need no card: no payment session, no payment source.
export async function offlinePaymentMethods(cart: CartRef) {
  const current = await getCart(cart)
  return (current.payment_methods ?? []).filter(
    (method) => !method.session_required && !method.source_required,
  )
}

export async function payOffline(cart: CartRef, paymentMethodId?: string): Promise<void> {
  const methods = await offlinePaymentMethods(cart)
  const method = methods.find((candidate) => candidate.id === paymentMethodId) ?? methods[0]
  if (!method) throw new Error('The store has no payment method that works without a card.')
  await spree().carts.payments.create(cart.id, { payment_method_id: method.id }, asGuest(cart))
}

export async function placeOrder(cart: CartRef): Promise<{ id: string; token: string }> {
  const placed = await spree().carts.complete(cart.id, asGuest(cart))
  return { id: placed.id, token: cart.token }
}
