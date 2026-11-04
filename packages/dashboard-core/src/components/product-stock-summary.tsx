import { useTranslation } from 'react-i18next'

/** The fields both panels' product payloads carry for a stock summary. */
export interface ProductStockFields {
  in_stock: boolean
  backorderable: boolean
  total_on_hand?: number | null
  variant_count: number
}

/**
 * A product's stock in a products list: how many units are on hand, on
 * backorder, or out of stock, followed by the variant count when there are
 * several. Shared by the admin and seller product lists.
 *
 * It reads the stock total rather than `in_stock`, which counts only variants
 * a shopper can buy: an unpriced draft with units on the shelf is in stock as
 * far as inventory goes.
 */
export function ProductStockSummary({ product }: { product: ProductStockFields }) {
  const { t } = useTranslation()

  // Null is untracked stock, which is unlimited. Undefined is a server too
  // old to send a total, which leaves only the sellable flag to go by.
  const total = product.total_on_hand
  const inStock = total === undefined ? product.in_stock : total === null || total > 0

  const status = inStock ? (
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
