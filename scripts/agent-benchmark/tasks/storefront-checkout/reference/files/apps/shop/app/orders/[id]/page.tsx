import { spree } from '@/lib/spree'

export const dynamic = 'force-dynamic'

export default async function OrderPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ token?: string }>
}) {
  const { id } = await params
  const { token } = await searchParams
  const order = await spree().orders.get(id, {}, { spreeToken: token })
  return (
    <main>
      <h1>Thank you!</h1>
      <p>
        Order {order.number} is placed. Total: {order.display_total}
      </p>
    </main>
  )
}
