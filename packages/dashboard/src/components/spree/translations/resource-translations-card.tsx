import { Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { LanguagesIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ResourceTranslationsDialog } from '@/components/spree/translations/resource-translations-dialog'
import { type TranslatableResourceType, useResourceTranslations } from '@/hooks/use-translations'

interface ResourceTranslationsCardProps {
  /** Public resource token, e.g. `product`, `category`, `option_type`. */
  resourceType: TranslatableResourceType
  /** Prefixed id of the resource being translated. */
  resourceId: string
}

/**
 * Launcher card for the full-page translations editor — works for any
 * translatable resource. Shows how many target locales the resource is
 * translated into and opens the editor dialog. Both the card and the dialog are
 * resource-agnostic: pass a `resourceType` token and an id, no per-resource
 * adapter needed.
 */
export function ResourceTranslationsCard({
  resourceType,
  resourceId,
}: ResourceTranslationsCardProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const { data } = useResourceTranslations(resourceType, resourceId)

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
      <ResourceTranslationsDialog
        open={open}
        onOpenChange={setOpen}
        resourceType={resourceType}
        resourceId={resourceId}
      />
    </Card>
  )
}
