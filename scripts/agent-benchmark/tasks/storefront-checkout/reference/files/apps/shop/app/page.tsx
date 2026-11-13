import { spree } from '@/lib/spree'

export const dynamic = 'force-dynamic'

export default async function ProductsPage() {
  const { data: products } = await spree().products.list()
  return (
    <main>
      <h1>Products</h1>
      {products.length === 0 && <p>No products yet.</p>}
      <ul>
        {products.map((product) => (
          <li key={product.id}>
            <a href={`/products/${product.slug}`}>{product.name}</a> {product.price?.amount}{' '}
            {product.price?.currency}
          </li>
        ))}
      </ul>
    </main>
  )
}
