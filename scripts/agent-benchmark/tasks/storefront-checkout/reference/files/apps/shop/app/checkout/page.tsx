import { redirect } from 'next/navigation'
import {
  chooseDelivery,
  getCart,
  offlinePaymentMethods,
  payOffline,
  placeOrder,
  setContact,
} from '@/lib/checkout'
import { currentCart, forgetCart } from '@/lib/session'

export const dynamic = 'force-dynamic'

const field = (formData: FormData, name: string) => String(formData.get(name) ?? '')

async function saveAddress(formData: FormData) {
  'use server'
  const cart = await currentCart()
  if (!cart) redirect('/cart')
  await setContact(cart, field(formData, 'email'), {
    firstName: field(formData, 'firstName'),
    lastName: field(formData, 'lastName'),
    address1: field(formData, 'address1'),
    city: field(formData, 'city'),
    postalCode: field(formData, 'postalCode'),
    stateCode: field(formData, 'stateCode'),
    countryCode: field(formData, 'countryCode'),
    phone: field(formData, 'phone'),
  })
  redirect('/checkout')
}

async function saveDelivery(formData: FormData) {
  'use server'
  const cart = await currentCart()
  if (!cart) redirect('/cart')
  // One radio group per fulfillment, named rate:<fulfillment id>.
  const rateIds: Record<string, string> = {}
  for (const [name, value] of formData.entries()) {
    if (name.startsWith('rate:')) rateIds[name.slice('rate:'.length)] = String(value)
  }
  await chooseDelivery(cart, rateIds)
  redirect('/checkout')
}

async function pay(formData: FormData) {
  'use server'
  const cart = await currentCart()
  if (!cart) redirect('/cart')
  await payOffline(cart, field(formData, 'paymentMethodId'))
  const order = await placeOrder(cart)
  await forgetCart()
  redirect(`/orders/${order.id}?token=${order.token}`)
}

const ADDRESS_FIELDS = [
  ['firstName', 'First name'],
  ['lastName', 'Last name'],
  ['address1', 'Address'],
  ['city', 'City'],
  ['postalCode', 'Postal code'],
  ['stateCode', 'State code'],
  ['countryCode', 'Country code'],
  ['phone', 'Phone'],
] as const

export default async function CheckoutPage() {
  const ref = await currentCart()
  if (!ref) redirect('/cart')
  const cart = await getCart(ref)
  const methods = await offlinePaymentMethods(ref)
  return (
    <main>
      <h1>Checkout</h1>
      <p>Total: {cart.display_total}</p>

      <h2>Contact and shipping address</h2>
      <form action={saveAddress}>
        <input
          name="email"
          type="email"
          placeholder="Email"
          defaultValue={cart.email ?? ''}
          required
        />
        {ADDRESS_FIELDS.map(([name, label]) => (
          <input key={name} name={name} placeholder={label} required />
        ))}
        <button type="submit">Continue</button>
      </form>

      {cart.fulfillments.length > 0 && (
        <>
          <h2>Delivery</h2>
          <form action={saveDelivery}>
            {cart.fulfillments.map((fulfillment, index) => (
              <fieldset key={fulfillment.id}>
                <legend>Shipment {index + 1}</legend>
                {fulfillment.delivery_rates.map((rate) => (
                  <label key={rate.id} style={{ display: 'block' }}>
                    <input
                      type="radio"
                      name={`rate:${fulfillment.id}`}
                      value={rate.id}
                      defaultChecked={rate.selected}
                    />{' '}
                    {rate.name} ({rate.cost})
                  </label>
                ))}
              </fieldset>
            ))}
            <button type="submit">Use this delivery</button>
          </form>
        </>
      )}

      <h2>Payment</h2>
      <form action={pay}>
        {methods.map((method, index) => (
          <label key={method.id} style={{ display: 'block' }}>
            <input
              type="radio"
              name="paymentMethodId"
              value={method.id}
              defaultChecked={index === 0}
            />{' '}
            {method.name}
          </label>
        ))}
        <button type="submit" disabled={methods.length === 0}>
          Place order
        </button>
      </form>
    </main>
  )
}
