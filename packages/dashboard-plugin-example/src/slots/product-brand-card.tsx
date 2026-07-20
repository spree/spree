/**
 * Widget rendered inside the product detail page's right-hand sidebar via the
 * `product.form_sidebar` slot. Shows the currently-assigned brand (if any),
 * with a button to clear or change it.
 *
 * The slot's context (typed by the dashboard as `{ product }`) gives us the
 * product being edited. The widget is purely additive — the host page knows
 * nothing about brands, the plugin contributes this card via `registerSlot`.
 */
import { Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { brandsClient } from '../client'

interface ProductBrandCardProps {
  // The host product page's slot context. We type only what we read.
  product: { id: string; brand_id?: string | null }
}

export function ProductBrandCard({ product }: ProductBrandCardProps) {
  const { t } = useTranslation()

  const { data: brand } = useQuery({
    queryKey: ['plugin-brands', 'brand', product.brand_id],
    queryFn: () => (product.brand_id ? brandsClient.get(product.brand_id) : null),
    enabled: Boolean(product.brand_id),
  })

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.brands_plugin.product_card.title')}</CardTitle>
      </CardHeader>
      <CardContent>
        {brand ? (
          <p className="text-sm">{brand.name}</p>
        ) : (
          <p className="text-sm text-muted-foreground">
            {t('admin.brands_plugin.product_card.empty')}
          </p>
        )}
      </CardContent>
    </Card>
  )
}
