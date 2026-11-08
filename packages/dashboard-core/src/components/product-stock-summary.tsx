import { useTranslation } from 'react-i18next'

/** The fields both panels' product payloads carry for a stock summary. */
export interface ProductStockFields {
  in_stock: boolean
  backorderable: boolean
  total_on_hand?: number | null
  variant_count: number
}

/**
 * Whether a product has stock, by its total rather than `in_stock`. Null is
 * untracked stock, which is unlimited; undefined is a server too old to send
 * a total, which leaves only the sellable flag to go by. Shared so every place
 * that labels a product's stock agrees.
 */
export function productInStock(product: Pick<ProductStockFields, 'in_stock' | 'total_on_hand'>) {
  const total = product.total_on_hand
  return total === undefined ? product.in_stock : total === null || total > 0
}

/**
 * A product's stock in a products list: how many units are on hand, on
 * backorder, or out of stock, followed by the variant count when there are
 * several. Shared by the admin and seller product lists.
 *
 * It reads the stock total rather than `in_stock`, which leaves out variants
 * whose seller cannot sell yet: a pending seller's units on the shelf are in
 * stock as far as inventory goes.
 */
export function ProductStockSummary({ product }: { product: ProductStockFields }) {
  const { t } = useTranslation()
  const total = product.total_on_hand

  const status = productInStock(product) ? (
    typeof total === 'number' ? (
      t('admin.components.product_stock.in_stock', { count: total })
    ) : (
      t('admin.components.product_stock.in_stock_short')
    )
  ) : product.backorderable ? (
    t('admin.components.product_stock.on_backorder')
  ) : (
    <span className="text-destructive">{t('admin.components.product_stock.out_of_stock')}</span>
  )

  return (
    <span className="text-sm text-muted-foreground">
      {status}
      {product.variant_count > 1 && (
        <>
          {' · '}
          {t('admin.components.product_stock.variants', { count: product.variant_count })}
        </>
      )}
    </span>
  )
}
