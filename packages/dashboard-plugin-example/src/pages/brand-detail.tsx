/**
 * Brand detail page, rendered by the `brands.$brandId` file route with the
 * path param already extracted.
 */
import { PageHeader } from '@spree/dashboard-core'
import { Card, CardContent, CardHeader, CardTitle, Skeleton } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { brandsClient } from '../client'

interface BrandDetailPageProps {
  brandId: string
}

export function BrandDetailPage({ brandId }: BrandDetailPageProps) {
  const { t } = useTranslation()

  const { data: brand, isLoading } = useQuery({
    queryKey: ['plugin-brands', 'brand', brandId],
    queryFn: () => brandsClient.get(brandId),
  })

  if (isLoading || !brand) {
    return <Skeleton className="h-48 w-full rounded-xl" />
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title={brand.name} subtitle={brand.slug} />
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.brands_plugin.detail.about')}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <p>{brand.description ?? t('admin.brands_plugin.detail.no_description')}</p>
          <p className="text-muted-foreground">
            {t('admin.brands_plugin.fields.products_count')}: {brand.products_count}
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
