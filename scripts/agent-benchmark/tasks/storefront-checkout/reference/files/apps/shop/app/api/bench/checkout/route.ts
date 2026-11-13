// Runs the whole guest checkout through the same steps the pages use.
import {
  addItem,
  type CheckoutAddress,
  chooseDelivery,
  createCart,
  payOffline,
  placeOrder,
  setContact,
} from '@/lib/checkout'

export const dynamic = 'force-dynamic'

type Body = { variantId: string; quantity?: number; email: string; address: CheckoutAddress }

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as Body
    const cart = await createCart()
    await addItem(cart, body.variantId, body.quantity ?? 1)
    await setContact(cart, body.email, body.address)
    await chooseDelivery(cart)
    await payOffline(cart)
    const order = await placeOrder(cart)
    return Response.json({
      orderId: order.id,
      confirmationUrl: `/orders/${order.id}?token=${encodeURIComponent(order.token)}`,
    })
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 422 },
    )
  }
}
