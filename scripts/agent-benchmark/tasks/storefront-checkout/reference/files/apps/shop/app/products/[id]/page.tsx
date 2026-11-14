import { redirect } from 'next/navigation'
import { addItem } from '@/lib/checkout'
import { cartForWriting } from '@/lib/session'
import { spree } from '@/lib/spree'

export const dynamic = 'force-dynamic'

async function addToCart(formData: FormData) {
  'use server'
  const cart = await cartForWriting()
  await addItem(cart, String(formData.get('variantId')), Number(formData.get('quantity') ?? 1))
  redirect('/cart')
}

export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await spree().products.get(id)
  return (
    <main>
      <h1>{product.name}</h1>
      <p>
        {product.price?.amount} {product.price?.currency}
      </p>
      {product.description && <p>{product.description}</p>}
      <form action={addToCart}>
        <input type="hidden" name="variantId" value={product.default_variant_id} />
        <input type="number" name="quantity" defaultValue={1} min={1} />
        <button type="submit" disabled={!product.purchasable}>
          Add to cart
        </button>
      </form>
    </main>
  )
}
