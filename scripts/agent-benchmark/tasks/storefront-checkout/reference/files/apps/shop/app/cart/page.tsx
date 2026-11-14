import { getCart } from '@/lib/checkout'
import { currentCart } from '@/lib/session'

export const dynamic = 'force-dynamic'

export default async function CartPage() {
  const ref = await currentCart()
  const cart = ref ? await getCart(ref) : null
  if (!cart || cart.items.length === 0) {
    return (
      <main>
        <h1>Cart</h1>
        <p>Your cart is empty.</p>
      </main>
    )
  }
  return (
    <main>
      <h1>Cart</h1>
      <ul>
        {cart.items.map((item) => (
          <li key={item.id}>
            {item.quantity} × {item.name}: {item.display_total}
          </li>
        ))}
      </ul>
      <p>Total: {cart.display_total}</p>
      <a href="/checkout">Checkout</a>
    </main>
  )
}
