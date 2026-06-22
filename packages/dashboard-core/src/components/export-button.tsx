import type { ExportType } from '@spree/admin-sdk'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldContent,
  FieldDescription,
  FieldLabel,
  FieldTitle,
  RadioGroup,
  RadioGroupItem,
} from '@spree/dashboard-ui'
import type { TFunction } from 'i18next'
import { DownloadIcon, FilterIcon, GlobeIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useExport } from '../hooks/use-export'
import { filtersToRansack } from '../lib/filters-to-ransack'
import type { ResourceActionsContext } from './resource-table'

interface ExportButtonProps extends ResourceActionsContext {
  /** Which dataset to export. Server validates against `Spree::Export.available_types`. */
  type: ExportType
  /** Label shown on the button. Defaults to the translated "Export" action. */
  label?: string
}

type Selection = 'filtered' | 'all'

export function ExportButton({
  type,
  label,
  filters,
  search,
  searchParam,
  columns,
  totalCount,
}: ExportButtonProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [selection, setSelection] = useState<Selection>('filtered')
  const exportMutation = useExport()

  const hasActiveFilter = filters.length > 0 || search.trim().length > 0

  function handleExport() {
    const search_params: Record<string, unknown> = filtersToRansack(filters, columns)
    if (search.trim()) {
      search_params[searchParam] = search.trim()
    }

    exportMutation.mutate({
      type,
      record_selection: selection,
      search_params: selection === 'filtered' ? search_params : undefined,
    })
    setOpen(false)
  }

  return (
    <>
      <Button
        size="sm"
        variant="outline"
        className="h-[2.125rem]"
        onClick={() => setOpen(true)}
        disabled={exportMutation.isPending}
      >
        <DownloadIcon className="size-4" />
        {label ?? t('admin.actions.export')}
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('admin.components.export_button.title')}</DialogTitle>
            <DialogDescription>{t('admin.components.export_button.description')}</DialogDescription>
          </DialogHeader>

          <DialogBody>
            <RadioGroup
              value={selection}
              onValueChange={(value) => setSelection(value as Selection)}
            >
              <ChoiceCard
                value="filtered"
                icon={<FilterIcon className="size-4" />}
                title={t('admin.components.export_button.filtered.title')}
                description={describeFiltered(t, hasActiveFilter, totalCount)}
              />
              <ChoiceCard
                value="all"
                icon={<GlobeIcon className="size-4" />}
                title={t('admin.components.export_button.all.title')}
                description={t('admin.components.export_button.all.description')}
              />
            </RadioGroup>
          </DialogBody>

          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button onClick={handleExport} disabled={exportMutation.isPending}>
              {exportMutation.isPending ? t('admin.actions.exporting') : t('admin.actions.export')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

function describeFiltered(
  t: TFunction,
  hasActiveFilter: boolean,
  totalCount: number | undefined,
): string {
  if (!hasActiveFilter) return t('admin.components.export_button.filtered.no_filter')
  if (totalCount === undefined) return t('admin.components.export_button.filtered.unknown_count')
  return t('admin.components.export_button.filtered.count', {
    count: totalCount,
    formattedCount: totalCount.toLocaleString(),
  })
}

function ChoiceCard({
  value,
  icon,
  title,
  description,
}: {
  value: string
  icon?: React.ReactNode
  title: string
  description: string
}) {
  return (
    <FieldLabel>
      <Field orientation="horizontal">
        {icon && <span className="mt-0.5 text-muted-foreground">{icon}</span>}
        <FieldContent>
          <FieldTitle>{title}</FieldTitle>
          <FieldDescription>{description}</FieldDescription>
        </FieldContent>
        <RadioGroupItem value={value} />
      </Field>
    </FieldLabel>
  )
}
