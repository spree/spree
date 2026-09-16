import type { Product } from '@spree/admin-sdk'
import type { ProductFormValues } from '@spree/dashboard-core'
import { getInitials } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  StatusBadge,
  Switch,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

/**
 * This product's place in the marketplace: who supplies it, and whether
 * sellers may compete on it.
 *
 * Two states that never overlap. A product a seller owns outright names that
 * seller and offers nothing to set — inviting rival offers onto somebody
 * else's listing would be the marketplace reselling their work. A first-party
 * product is the one that can be opened to sellers, which is how the shared
 * catalog gets its stock (docs/plans/6.0-seller-master-catalog-listings.md,
 * Decision 2).
 *
 * Renders nothing at all on a store with no sellers: an operator selling only
 * their own goods should never meet any of this.
 */
export function ProductMarketplaceCard({
  product,
  form,
  hasSellers,
}: {
  product: Product
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  /** Whether this store has any sellers at all. */
  hasSellers: boolean
}) {
  const { t } = useTranslation()

  if (!hasSellers) return null

  const name = product.seller?.name ?? product.seller_name ?? product.seller_id

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.products.marketplace.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {product.seller_id ? (
          <div className="flex items-center gap-3">
            <Avatar className="size-8">
              {product.seller?.logo_url && <AvatarImage src={product.seller.logo_url} alt="" />}
              <AvatarFallback>{getInitials(name ?? '?', '?')}</AvatarFallback>
            </Avatar>
            <div className="flex min-w-0 flex-col">
              <Link
                to={'/$storeId/sellers/$sellerId' as string}
                params={{ sellerId: product.seller_id }}
                className="truncate font-medium text-foreground no-underline"
              >
                {name}
              </Link>
              {product.seller?.status && (
                <span className="mt-1">
                  <StatusBadge status={product.seller.status} />
                </span>
              )}
            </div>
          </div>
        ) : (
          <Field orientation="horizontal">
            <div className="flex flex-col">
              <FieldLabel htmlFor="product-open-to-sellers">
                {t('admin.fields.product.open_to_sellers.label')}
              </FieldLabel>
              <span className="text-muted-foreground text-xs">
                {t('admin.fields.product.open_to_sellers.help')}
              </span>
            </div>
            <Controller
              name="open_to_sellers"
              control={form.control}
              render={({ field }) => (
                <Switch
                  id="product-open-to-sellers"
                  checked={!!field.value}
                  onCheckedChange={field.onChange}
                />
              )}
            />
          </Field>
        )}
      </CardContent>
    </Card>
  )
}
