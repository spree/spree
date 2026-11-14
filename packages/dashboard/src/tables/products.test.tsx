import type { Product } from '@spree/admin-sdk'
import { getTable } from '@spree/dashboard-core'
import { describe, expect, it } from 'vitest'
import './products'

describe('products table SKU column', () => {
  const column = () => {
    const sku = getTable<Product>('products').columns.find((c) => c.key === 'sku')
    if (!sku?.render) throw new Error('the products table has no SKU column')
    return sku as typeof sku & { render: NonNullable<typeof sku.render> }
  }

  it('requests the default variant while the column is on', () => {
    expect(column().expand).toBe('default_variant')
  })

  it("shows the default variant's SKU", () => {
    const product = { default_variant: { sku: '8721302933309' } } as unknown as Product
    expect(column().render(product)).toBe('8721302933309')
  })

  it('shows a dash when the default variant has no SKU', () => {
    expect(column().render({ default_variant: { sku: '' } } as unknown as Product)).toBe('—')
    expect(column().render({} as Product)).toBe('—')
  })
})
