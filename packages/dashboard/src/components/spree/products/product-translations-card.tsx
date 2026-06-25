import { Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { LanguagesIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ProductTranslationsDialog } from '@/components/spree/products/product-translations-dialog'
import { useProductTranslations } from '@/hooks/use-translations'

/**
 * Launcher card for the full-page translations editor. Shows how many target
 * locales the product is translated into and opens the spreadsheet dialog. The
 * editing itself lives in <ProductTranslationsDialog>, not inline here.
 */
export function ProductTranslationsCard({ productId }: { productId: string }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const { data } = useProductTranslations(productId)

  const targetLocales = data ? data.supported_locales.filter((l) => l !== data.default_locale) : []
  const translatedCount = targetLocales.filter(
    (l) => (data?.translations[l]?.translated_field_count ?? 0) > 0,
  ).length

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0">
        <CardTitle>{t('admin.translations.title')}</CardTitle>
        {targetLocales.length > 0 && (
          <Button type="button" size="sm" variant="outline" onClick={() => setOpen(true)}>
            <LanguagesIcon />
            {t('admin.translations.manage')}
          </Button>
        )}
      </CardHeader>
      <CardContent>
        {targetLocales.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('admin.translations.no_locales')}</p>
        ) : (
          <p className="text-sm text-muted-foreground">
            {t('admin.translations.coverage_summary', {
              translated: translatedCount,
              total: targetLocales.length,
            })}
          </p>
        )}
      </CardContent>
      <ProductTranslationsDialog productId={productId} open={open} onOpenChange={setOpen} />
    </Card>
  )
}
