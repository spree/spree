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
import { DownloadIcon, FilterIcon, GlobeIcon } from '@spree/dashboard-ui/icons'
import type { TFunction } from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useExport } from '../hooks/use-export'
import { filtersToRansack } from '../lib/filters-to-ransack'
import type { ResourceActionsContext } from './resource-table'

interface ExportButtonProps extends ResourceActionsContext {
  /**
   * Which dataset to export. A plain string rather than either SDK's union:
   * the operator's registry and a seller's allowlist are different sets, and
   * the server is what validates the value in both panels.
   */
  type: string
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
      // Where the done email sends the user back to, for an export too slow to
      // wait on. Read off the live location rather than built from a
      // configured host: a panel may be mounted under a path (`/sellers`,
      // `/dashboard`) as easily as on a host of its own, and only the page
      // itself knows which. The store's allowed origins decide whether the
      // server trusts it.
      results_url: window.location.href,
    })
    setOpen(false)
  }

  return (
    <>
      {/* Desktop only: picking a dataset, waiting on the job and opening
          the file is desk work, and the button is one of the things that
          pushed the toolbar onto a third row on a phone. */}
      <Button
        size="sm"
        variant="outline"
        className="hidden h-[2.125rem] lg:inline-flex"
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
