import { type ProductFormValues, useStore } from '@spree/dashboard-core'
import { Alert, AlertDescription, AlertTitle } from '@spree/dashboard-ui'
import { TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import { type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

// The storefront lists a product only in currencies it has a base price in,
// unless the store shows unpriced products (Spree::ProductScopes.with_currency).
// The form holds base prices only, so price-list prices never count here.
function unpricedCurrencies(variants: ProductFormValues['variants'], currencies: string[]) {
  const priced = new Set<string>(
    (variants ?? []).flatMap((v) =>
      (v.prices ?? []).filter((p) => p.amount.trim() !== '').map((p) => p.currency),
    ),
  )
  return currencies.filter((currency) => !priced.has(currency))
}

export function MissingPriceAlert({ form }: { form: UseFormReturn<ProductFormValues> }) {
  const { t, i18n } = useTranslation()
  const { store } = useStore()
  const [productStatus, variants] = useWatch({
    control: form.control,
    name: ['status', 'variants'],
  })
  if (productStatus !== 'active' || !store || store.show_products_without_price) return null

  const missing = unpricedCurrencies(variants, store.supported_currencies)
  if (missing.length === 0) return null

  return (
    <Alert variant="warning" className="mb-2">
      <TriangleAlertIcon />
      <AlertTitle>
        {t('admin.pages.products.publishing.missing_price_title', {
          currencies: new Intl.ListFormat(i18n.language).format(missing),
        })}
      </AlertTitle>
      <AlertDescription>
        {t('admin.pages.products.publishing.missing_price_description')}
      </AlertDescription>
    </Alert>
  )
}
