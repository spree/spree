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
import { DownloadIcon, FilterIcon, GlobeIcon } from 'lucide-react'
import { useState } from 'react'
import type { ResourceActionsContext } from '@/components/spree/resource-table'
import { useExport } from '@/hooks/use-export'
import { filtersToRansack } from '@/lib/filters-to-ransack'

interface ExportButtonProps extends ResourceActionsContext {
  /** Which dataset to export. Server validates against `Spree::Export.available_types`. */
  type: ExportType
  /** Label shown on the button. Defaults to "Export". */
  label?: string
}

type Selection = 'filtered' | 'all'

export function ExportButton({
  type,
  label = 'Export',
  filters,
  search,
  searchParam,
  columns,
  totalCount,
}: ExportButtonProps) {
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
        {label}
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Export to CSV</DialogTitle>
            <DialogDescription>
              We'll prepare your CSV in the background and download it as soon as it's ready. If it
              takes a while you'll get an email link too.
            </DialogDescription>
          </DialogHeader>

          <DialogBody>
            <RadioGroup
              value={selection}
              onValueChange={(value) => setSelection(value as Selection)}
            >
              <ChoiceCard
                value="filtered"
                icon={<FilterIcon className="size-4" />}
                title="Current filter"
                description={describeFiltered(hasActiveFilter, totalCount)}
              />
              <ChoiceCard
                value="all"
                icon={<GlobeIcon className="size-4" />}
                title="All records"
                description="Ignore filters and export everything in this store."
              />
            </RadioGroup>
          </DialogBody>

          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleExport} disabled={exportMutation.isPending}>
              {exportMutation.isPending ? 'Exporting…' : 'Export'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

function describeFiltered(hasActiveFilter: boolean, totalCount: number | undefined): string {
  if (!hasActiveFilter) return 'No filter active — same as exporting all records.'
  if (totalCount === undefined) return 'Export the records matching your current filter.'
  const noun = totalCount === 1 ? 'record' : 'records'
  return `Export the ${totalCount.toLocaleString()} ${noun} matching your current filter.`
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
