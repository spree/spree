import { Badge, Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

/**
 * Which seller to act as.
 *
 * Only shown to a seller who runs more than one — the panel acts as exactly
 * one at a time, because every request carries a single `X-Spree-Seller-Id`.
 */
export function SellerPicker() {
  const { t } = useTranslation()
  const { data, isLoading, error } = useQuery({
    queryKey: ['seller', 'me'],
    queryFn: () => sellerClient().me(),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  const sellers = data?.sellers ?? []

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>{t('seller_picker.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          <p className="mb-2 text-muted-foreground text-sm">{t('seller_picker.subtitle')}</p>
          {sellers.map((seller) => (
            <Button key={seller.id} variant="outline" className="justify-between" asChild>
              <Link to="/$sellerId" params={{ sellerId: seller.id }}>
                <span>{seller.name}</span>
                <Badge variant="outline">{seller.status}</Badge>
              </Link>
            </Button>
          ))}
        </CardContent>
      </Card>
    </div>
  )
}
