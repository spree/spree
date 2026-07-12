import type { Import, ImportRow } from '@spree/admin-sdk'
import { useDownloadImportOriginal } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
  Progress,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { useNavigate } from '@tanstack/react-router'
import {
  AlertTriangleIcon,
  CheckCircle2Icon,
  ChevronLeftIcon,
  ChevronRightIcon,
  DownloadIcon,
  RotateCcwIcon,
  XIcon,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCompleteMapping,
  useImport,
  useImportRows,
  useRetryFailedRows,
} from '../../../hooks/use-imports'
import { importTypeIndexPath, importTypeLabel, isImportActive } from '../../../lib/import-types'

const NOT_MAPPED = '__not_mapped__'

interface ImportWizardDialogProps {
  /** Prefixed id of the import to drive; `null` keeps the dialog closed. */
  importId: string | null
  onClose: () => void
}

/**
 * Full-window wizard for one import — mapping → progress → results as states
 * of a single edge-to-edge dialog (same shell as the bulk price editor).
 * "Deeper into this thing", not "leave this thing": the page behind keeps its
 * state, and closing mid-processing is safe — the import continues server-side
 * and reopens from the history page (or the same `?import=` URL).
 */
export function ImportWizardDialog({ importId, onClose }: ImportWizardDialogProps) {
  return (
    <Dialog open={!!importId} onOpenChange={(next) => !next && onClose()} modal>
      <DialogContent
        // Edge-to-edge minus a 3-unit gutter — see BulkPriceEditorDialog for
        // why every inset/translate/max is overridden.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        {importId && <ImportWizard importId={importId} onClose={onClose} />}
      </DialogContent>
    </Dialog>
  )
}

function ImportWizard({ importId, onClose }: { importId: string; onClose: () => void }) {
  const { t } = useTranslation()
  const { data: imp, isLoading, isError, refetch } = useImport(importId)
  const downloadOriginal = useDownloadImportOriginal()
  // Explicit retry marker: the processing card must not infer a retry pass
  // from row totals (they look identical in the last poll tick of a first
  // pass that ends with failures).
  const [retryRequested, setRetryRequested] = useState(false)

  const showFailedRows =
    !!imp && imp.failed_rows_count > 0 && (isImportActive(imp.status) || imp.status === 'completed')

  return (
    <>
      <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
        <div className="flex min-w-0 items-center gap-2">
          <DialogTitle className="truncate">
            {imp ? `${importTypeLabel(imp.type)} · ${imp.number}` : t('admin.imports.wizard_title')}
          </DialogTitle>
          {imp && (
            <StatusBadge status={imp.status} label={t(`admin.imports.status.${imp.status}`)} />
          )}
        </div>
        <div className="flex items-center gap-1">
          {imp?.original_file_url && (
            <Button
              type="button"
              size="icon-sm"
              variant="ghost"
              onClick={() => downloadOriginal.mutate(imp)}
              disabled={downloadOriginal.isPending}
              aria-label={t('admin.imports.download_original')}
            >
              <DownloadIcon />
            </Button>
          )}
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={onClose}
            aria-label={t('admin.actions.close')}
          >
            <XIcon />
          </Button>
        </div>
      </DialogHeader>

      <DialogBody className="min-h-0 flex-1 overflow-y-auto p-4">
        <div className="mx-auto flex w-full flex-col gap-4">
          {isError ? (
            <div className="flex flex-col items-center gap-3 py-12 text-center">
              <AlertTriangleIcon className="size-8 text-destructive" />
              <p className="text-muted-foreground text-sm">{t('admin.imports.load_failed')}</p>
              <Button variant="outline" onClick={() => refetch()}>
                {t('admin.imports.try_again')}
              </Button>
            </div>
          ) : isLoading || !imp ? (
            <>
              <Skeleton className="h-6 w-64" />
              <Skeleton className="h-40 w-full" />
            </>
          ) : (
            <>
              <StepIndicator status={imp.status} />

              {imp.status === 'mapping' && <MappingStep imp={imp} />}
              {isImportActive(imp.status) && (
                <ProcessingCard imp={imp} retryPass={retryRequested} />
              )}
              {imp.status === 'completed' && (
                <ResultsCard
                  imp={imp}
                  onClose={onClose}
                  onRetried={() => setRetryRequested(true)}
                />
              )}
              {imp.status === 'failed' && <FailedCard imp={imp} />}
              {showFailedRows && <FailedRowsCard imp={imp} />}
            </>
          )}
        </div>
      </DialogBody>
    </>
  )
}

// ---------------------------------------------------------------------------
// Step indicator — Map fields → Process rows → Complete, mirroring the legacy
// wizard's three steps.
// ---------------------------------------------------------------------------

function StepIndicator({ status }: { status: string }) {
  const { t } = useTranslation()

  // A failed import stays on the processing step — it never completed.
  const activeIndex =
    status === 'mapping' ? 0 : isImportActive(status) || status === 'failed' ? 1 : 2
  const steps = ['map_fields', 'process_rows', 'complete'] as const

  return (
    <ol className="flex items-center gap-2">
      {steps.map((step, index) => (
        <li key={step} className="flex items-center gap-2">
          <span
            className={cn(
              'flex size-5 items-center justify-center rounded-full text-xs',
              index <= activeIndex && 'bg-primary text-primary-foreground',
              index > activeIndex && 'bg-muted text-muted-foreground',
            )}
          >
            {index < activeIndex ? <CheckCircle2Icon className="size-3.5" /> : index + 1}
          </span>
          <span
            className={cn(
              'text-sm',
              index === activeIndex ? 'font-medium' : 'text-muted-foreground',
            )}
          >
            {t(`admin.imports.steps.${step}`)}
          </span>
          {index < steps.length - 1 && (
            <ChevronRightIcon className="size-4 text-muted-foreground" />
          )}
        </li>
      ))}
    </ol>
  )
}

// ---------------------------------------------------------------------------
// Mapping step
// ---------------------------------------------------------------------------

function MappingStep({ imp }: { imp: Import }) {
  const { t } = useTranslation()
  const completeMapping = useCompleteMapping(imp.id)
  const [assignments, setAssignments] = useState<Record<string, string | null>>(() =>
    Object.fromEntries(imp.mappings.map((m) => [m.schema_field, m.file_column])),
  )

  const missingRequired = imp.schema_fields.filter((f) => f.required && !assignments[f.name])

  function handleStart() {
    completeMapping.mutate({
      mappings: imp.schema_fields.map((field) => ({
        schema_field: field.name,
        file_column: assignments[field.name] ?? null,
      })),
    })
  }

  const headerOptions = (current: string | null) => [
    { value: NOT_MAPPED, label: t('admin.imports.mapping.not_mapped'), disabled: false },
    ...imp.csv_headers.map((header) => ({
      value: header,
      label: header,
      // A file column can feed only one field — mirror the server's
      // uniqueness validation instead of 422-ing on submit.
      disabled: header !== current && Object.values(assignments).includes(header),
    })),
  ]

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.mapping.title')}</CardTitle>
        <p className="text-muted-foreground text-sm">
          {t('admin.imports.mapping.description', { type: importTypeLabel(imp.type) })}
        </p>
      </CardHeader>
      <CardContent className="flex flex-col gap-4 p-0">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="border-b">
              <TableRow>
                <TableHead>{t('admin.imports.mapping.field')}</TableHead>
                <TableHead>{t('admin.imports.mapping.file_column')}</TableHead>
                <TableHead>{t('admin.imports.mapping.sample')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {imp.schema_fields.map((field) => {
                const current = assignments[field.name] ?? null
                const options = headerOptions(current)
                const sample = current ? (imp.sample_row[current] ?? '') : ''

                return (
                  <TableRow key={field.name}>
                    <TableCell>
                      <span className="inline-flex items-center gap-2">
                        {field.label}
                        {field.required && (
                          <Badge variant="outline">{t('admin.imports.mapping.required')}</Badge>
                        )}
                      </span>
                    </TableCell>
                    <TableCell className="w-72">
                      <Select
                        items={options}
                        value={current ?? NOT_MAPPED}
                        onValueChange={(value) =>
                          setAssignments((prev) => ({
                            ...prev,
                            [field.name]: value === NOT_MAPPED ? null : (value as string),
                          }))
                        }
                      >
                        <SelectTrigger className="w-full">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {options.map((option) => (
                            <SelectItem
                              key={option.value}
                              value={option.value}
                              disabled={option.disabled}
                            >
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell className="max-w-48 truncate text-muted-foreground text-sm">
                      {sample}
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        </div>

        {missingRequired.length > 0 && (
          <p className="text-muted-foreground text-sm">
            {t('admin.imports.mapping.missing_required', {
              fields: missingRequired.map((f) => f.label).join(', '),
            })}
          </p>
        )}

        {completeMapping.isError && (
          <div className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-3 text-destructive text-sm">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>
              {completeMapping.error instanceof Error
                ? completeMapping.error.message
                : String(completeMapping.error)}
            </span>
          </div>
        )}
      </CardContent>
      <CardFooter className="flex justify-end">
        <Button
          onClick={handleStart}
          disabled={missingRequired.length > 0 || completeMapping.isPending}
          className="m-4"
        >
          {completeMapping.isPending
            ? t('admin.imports.mapping.starting')
            : t('admin.imports.mapping.start')}
        </Button>
      </CardFooter>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Processing
// ---------------------------------------------------------------------------

// `retryPass` is the wizard's explicit marker that the user triggered a
// failed-rows retry: every row is already terminal then, so the bar would sit
// at 100% — show the shrinking failed count instead.
function ProcessingCard({ imp, retryPass }: { imp: Import; retryPass: boolean }) {
  const { t } = useTranslation()

  const total = imp.rows_count
  const processed = imp.completed_rows_count + imp.failed_rows_count
  const preparing = total === 0
  const percent = preparing ? 0 : Math.min(100, Math.round((processed / total) * 100))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.processing.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {/* value={null} = Base UI's indeterminate state while rows are created */}
        <Progress value={preparing ? null : percent} />

        <p className="text-sm">
          {preparing ? (
            t('admin.imports.processing.preparing')
          ) : retryPass && imp.failed_rows_count > 0 ? (
            t('admin.imports.processing.retrying', { remaining: imp.failed_rows_count })
          ) : (
            <>
              {t('admin.imports.processing.progress', {
                processed: processed.toLocaleString(),
                total: total.toLocaleString(),
              })}
              {imp.failed_rows_count > 0 && (
                <span className="text-destructive">
                  {' · '}
                  {t('admin.imports.processing.failed_count', { failed: imp.failed_rows_count })}
                </span>
              )}
            </>
          )}
        </p>

        <p className="text-muted-foreground text-sm">{t('admin.imports.processing.note')}</p>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Results / file-level failure
// ---------------------------------------------------------------------------

function ResultsCard({
  imp,
  onClose,
  onRetried,
}: {
  imp: Import
  onClose: () => void
  onRetried: () => void
}) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const retryMutation = useRetryFailedRows(imp.id)

  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-8 text-center">
        <CheckCircle2Icon className="size-10 text-success" />
        <p className="font-medium">{t('admin.imports.results.completed_title')}</p>
        <p className="text-muted-foreground text-sm">
          {t('admin.imports.results.summary', {
            completed: imp.completed_rows_count.toLocaleString(),
            failed: imp.failed_rows_count.toLocaleString(),
          })}
        </p>
        <div className="mt-2 flex items-center gap-2">
          {imp.failed_rows_count > 0 && (
            <Button
              variant="outline"
              onClick={() => retryMutation.mutate(undefined, { onSuccess: onRetried })}
              disabled={retryMutation.isPending}
            >
              <RotateCcwIcon className="size-4" />
              {retryMutation.isPending
                ? t('admin.imports.results.retrying')
                : t('admin.imports.results.retry_failed', { failed: imp.failed_rows_count })}
            </Button>
          )}
          <Button
            onClick={() => {
              onClose()
              navigate({ to: importTypeIndexPath(imp.type) })
            }}
          >
            {t('admin.imports.results.view_records', { type: importTypeLabel(imp.type) })}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function FailedCard({ imp }: { imp: Import }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-8 text-center">
        <AlertTriangleIcon className="size-10 text-destructive" />
        <p className="font-medium">{t('admin.imports.failed.title')}</p>
        <p className="text-muted-foreground text-sm">{t('admin.imports.failed.description')}</p>
        {imp.processing_errors && (
          <code className="max-w-full overflow-x-auto rounded-md bg-muted p-3 text-left text-xs">
            {imp.processing_errors}
          </code>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Failed rows report
// ---------------------------------------------------------------------------

function FailedRowsCard({ imp }: { imp: Import }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { data, isPending, isError, refetch } = useImportRows(
    imp.id,
    { status_eq: 'failed', sort: 'row_number', page },
    { poll: isImportActive(imp.status) },
  )

  const rows = data?.data ?? []
  const meta = data?.meta

  // Retrying shrinks the failure set — an out-of-range page would otherwise
  // return an empty list with no way back.
  useEffect(() => {
    if (meta && page > Math.max(meta.pages, 1)) {
      setPage(Math.max(meta.pages, 1))
    }
  }, [meta, page])

  // Distinguish "nothing failed" (hide the card) from "couldn't load" and
  // "still loading" — the report must not silently disappear.
  if (!isPending && !isError && rows.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.failed_rows.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3 p-0">
        {isError ? (
          <div className="flex items-center gap-3 p-4">
            <AlertTriangleIcon className="size-4 shrink-0 text-destructive" />
            <span className="text-muted-foreground text-sm">{t('admin.imports.load_failed')}</span>
            <Button variant="outline" size="sm" onClick={() => refetch()}>
              {t('admin.imports.try_again')}
            </Button>
          </div>
        ) : isPending ? (
          <div className="flex flex-col gap-2 p-4">
            <Skeleton className="h-5 w-full" />
            <Skeleton className="h-5 w-2/3" />
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader className="border-b">
                  <TableRow>
                    <TableHead className="w-16">
                      {t('admin.imports.failed_rows.row_number')}
                    </TableHead>
                    <TableHead>{t('admin.imports.failed_rows.error')}</TableHead>
                    <TableHead className="w-32" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((row) => (
                    <FailedRow key={row.id} row={row} />
                  ))}
                </TableBody>
              </Table>
            </div>

            {meta && meta.pages > 1 && (
              <div className="flex items-center justify-end gap-2 px-4 pb-4">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  aria-label={t('admin.imports.failed_rows.prev_page')}
                >
                  <ChevronLeftIcon className="size-4" />
                </Button>
                <span className="text-muted-foreground text-sm">
                  {page} / {meta.pages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page >= meta.pages}
                  onClick={() => setPage((p) => p + 1)}
                  aria-label={t('admin.imports.failed_rows.next_page')}
                >
                  <ChevronRightIcon className="size-4" />
                </Button>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  )
}

function FailedRow({ row }: { row: ImportRow }) {
  const { t } = useTranslation()
  const [expanded, setExpanded] = useState(false)

  return (
    <>
      <TableRow>
        <TableCell className="text-muted-foreground">{row.row_number}</TableCell>
        <TableCell className="text-destructive text-sm">
          {String(row.validation_errors ?? '')}
        </TableCell>
        <TableCell className="text-right">
          <Button variant="ghost" size="sm" onClick={() => setExpanded((e) => !e)}>
            {expanded
              ? t('admin.imports.failed_rows.hide_data')
              : t('admin.imports.failed_rows.view_data')}
          </Button>
        </TableCell>
      </TableRow>
      {expanded && (
        <TableRow>
          <TableCell colSpan={3}>
            <div className="overflow-x-auto rounded-md bg-muted p-3">
              <code className="whitespace-pre-wrap text-xs">
                {JSON.stringify(row.data, null, 2)}
              </code>
            </div>
          </TableCell>
        </TableRow>
      )}
    </>
  )
}
