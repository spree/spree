import type { Product } from '@spree/admin-sdk'
import { getInitials } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  StatusBadge,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

/**
 * Who supplies this product.
 *
 * Only rendered for a seller's product — the marketplace's own listings have
 * no seller, and an empty card saying so on every first-party product would
 * be noise. The seller's status rides along because a product from a
 * suspended seller is not on sale whatever the product's own status says.
 */
export function ProductSellerCard({ product }: { product: Product }) {
  const { t } = useTranslation()

  if (!product.seller_id) return null

  const name = product.seller?.name ?? product.seller_name ?? product.seller_id

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.products.seller.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex items-center gap-3">
        <Avatar className="size-8">
          {product.seller?.logo_url && <AvatarImage src={product.seller.logo_url} alt="" />}
          <AvatarFallback>{getInitials(name, '?')}</AvatarFallback>
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
      </CardContent>
    </Card>
  )
}
