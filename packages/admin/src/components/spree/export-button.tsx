import type { ExportType } from '@spree/admin-sdk'
import { DownloadIcon, FilterIcon, GlobeIcon } from 'lucide-react'
import { useState } from 'react'
import type { ResourceActionsContext } from '@/components/spree/resource-table'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useExport } from '@/hooks/use-export'
import { filtersToRansack } from '@/lib/filters-to-ransack'
import { cn } from '@/lib/utils'

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

          <DialogBody className="grid gap-3">
            <RadioOption
              icon={<FilterIcon className="size-4" />}
              title="Current filter"
              description={describeFiltered(hasActiveFilter, totalCount)}
              selected={selection === 'filtered'}
              onSelect={() => setSelection('filtered')}
            />
            <RadioOption
              icon={<GlobeIcon className="size-4" />}
              title="All records"
              description="Ignore filters and export everything in this store."
              selected={selection === 'all'}
              onSelect={() => setSelection('all')}
            />
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

function RadioOption({
  icon,
  title,
  description,
  selected,
  onSelect,
}: {
  icon: React.ReactNode
  title: string
  description: string
  selected: boolean
  onSelect: () => void
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={cn(
        'flex items-start gap-3 rounded-lg border p-3 text-left transition-colors',
        'hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        selected ? 'border-primary bg-muted/30' : 'border-border',
      )}
    >
      <span className="mt-0.5 text-muted-foreground">{icon}</span>
      <span className="flex-1">
        <span className="block text-sm font-medium">{title}</span>
        <span className="block text-xs text-muted-foreground">{description}</span>
      </span>
      <span
        className={cn(
          'mt-1 size-4 shrink-0 rounded-full border',
          selected ? 'border-primary bg-primary' : 'border-border',
        )}
      >
        {selected && (
          <span className="block size-full rounded-full ring-2 ring-background ring-inset" />
        )}
      </span>
    </button>
  )
}
