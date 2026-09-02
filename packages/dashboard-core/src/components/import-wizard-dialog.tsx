import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
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
  WizardProgress,
} from '@spree/dashboard-ui'
import {
  AlertTriangleIcon,
  CheckCircle2Icon,
  ChevronLeftIcon,
  ChevronRightIcon,
  DownloadIcon,
  RotateCcwIcon,
  XIcon,
} from '@spree/dashboard-ui/icons'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { PanelImport, PanelImportRow } from '../api-client'
import {
  isImportActive,
  useCompleteMapping,
  useDownloadImportOriginal,
  useImport,
  useImportRows,
  useRetryFailedRows,
} from '../hooks/use-import'
import { importTypeLabel } from '../lib/import-types'

const NOT_MAPPED = '__not_mapped__'

interface ImportWizardDialogProps {
  /** Prefixed id of the import to drive; `null` keeps the dialog closed. */
  importId: string | null
  onClose: () => void
  /**
   * Sends the user to the records the import wrote, once it has finished.
   *
   * Injected rather than routed here: each panel files its catalog under its
   * own route tree, and a component that navigated by itself would only work
   * in the one it was written for. Omit it and the button is not rendered —
   * the import is still complete, there is simply nowhere named to go.
   */
  onViewRecords?: (type: string | null) => void
}

/**
 * Full-window wizard for one import — mapping → progress → results as states
 * of a single edge-to-edge dialog (same shell as the bulk price editor).
 * "Deeper into this thing", not "leave this thing": the page behind keeps its
 * state, and closing mid-processing is safe — the import continues server-side
 * and reopens from the history page (or the same `?import=` URL).
 */
export function ImportWizardDialog({ importId, onClose, onViewRecords }: ImportWizardDialogProps) {
  return (
    <Dialog open={!!importId} onOpenChange={(next) => !next && onClose()} modal>
      <DialogContent
        // Edge-to-edge minus a 3-unit gutter — see BulkPriceEditorDialog for
        // why every inset/translate/max is overridden.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        {importId && (
          <ImportWizard importId={importId} onClose={onClose} onViewRecords={onViewRecords} />
        )}
      </DialogContent>
    </Dialog>
  )
}

function ImportWizard({
  importId,
  onClose,
  onViewRecords,
}: {
  importId: string
  onClose: () => void
  onViewRecords?: (type: string | null) => void
}) {
  const { t } = useTranslation()
  const { data: imp, isLoading, isError, refetch } = useImport(importId)
  const downloadOriginal = useDownloadImportOriginal()
  // Explicit retry marker: the processing card must not infer a retry pass
  // from row totals (they look identical in the last poll tick of a first
  // pass that ends with failures).
  const [retryRequested, setRetryRequested] = useState(false)
  const completeMapping = useCompleteMapping(importId)
  const [assignments, setAssignments] = useState<MappingAssignments>({})

  // Seeded once per import. The query is stale immediately, so a refetch on
  // window focus hands back a new object; re-seeding on that would throw away
  // a mapping the merchant is part-way through.
  const seededFor = useRef<string | null>(null)
  useEffect(() => {
    if (!imp || seededFor.current === imp.id) return
    seededFor.current = imp.id
    setAssignments(initialAssignments(imp))
  }, [imp])

  const isMapping = imp?.status === 'mapping'
  const isCompleted = imp?.status === 'completed'
  const missingRequired = imp && isMapping ? missingRequiredFields(imp, assignments) : []
  const retryMutation = useRetryFailedRows(importId)

  function handleStartImport() {
    if (!imp) return
    completeMapping.mutate({
      mappings: imp.schema_fields.map((field) => ({
        schema_field: field.name,
        file_column: assignments[field.name] ?? null,
      })),
    })
  }

  const showFailedRows =
    !!imp && imp.failed_rows_count > 0 && (isImportActive(imp.status) || imp.status === 'completed')

  return (
    <>
      <DialogHeader className="h-14 shrink-0 flex-row items-center gap-3 space-y-0 border-b border-border-subtle bg-background px-4 py-0">
        <div className="flex min-w-0 items-center gap-3">
          <DialogTitle className="truncate text-base">
            {t('admin.imports.wizard_title')}
          </DialogTitle>
          {imp && (
            <>
              <span aria-hidden className="h-4 w-px shrink-0 bg-border" />
              <span className="truncate text-muted-foreground text-sm">
                {`${importTypeLabel(imp.type)} · ${imp.number}`}
              </span>
            </>
          )}
        </div>
        <div className="ms-auto flex shrink-0 items-center gap-2">
          {imp && (
            <StatusBadge status={imp.status} label={t(`admin.imports.status.${imp.status}`)} />
          )}
          {/* Keyed on the filename rather than the URL: a client that serves
              the file from its own endpoint may send no `original_file_url`
              (the download hook falls back to `imports().downloadUrl`), but an
              import with nothing attached must still not offer a download —
              that endpoint answers 422. */}
          {imp?.original_filename && (
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

      {/* The body itself does not scroll: the rail stays put while the step's
          own column scrolls, so a long mapping table never carries the
          progress list off-screen. */}
      <DialogBody className="flex min-h-0 flex-1 gap-8 overflow-hidden p-0">
        <StepIndicator status={imp?.status ?? 'mapping'} />
        <div className="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto py-8 pe-8 ps-8 md:ps-0">
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
              {imp.status === 'mapping' && (
                <MappingStep
                  imp={imp}
                  assignments={assignments}
                  setAssignments={setAssignments}
                  error={completeMapping.error}
                />
              )}
              {isImportActive(imp.status) && (
                <ProcessingCard imp={imp} retryPass={retryRequested} />
              )}
              {imp.status === 'completed' && <ResultsCard imp={imp} />}
              {imp.status === 'failed' && <FailedCard imp={imp} />}
              {showFailedRows && <FailedRowsCard imp={imp} />}
            </>
          )}
        </div>
      </DialogBody>

      {/* Every step's action lives here rather than at the end of its card:
          a long mapping table or failed-rows list would otherwise push the
          button below the fold. */}
      {(isMapping || isCompleted) && imp && (
        <DialogFooter className="h-16 shrink-0 flex-row items-center justify-between border-border-subtle bg-background px-4 py-0 sm:justify-between">
          <span className="text-muted-foreground text-sm">
            {isMapping && missingRequired.length > 0
              ? t('admin.imports.mapping.missing_required', {
                  fields: missingRequired.map((f) => f.label).join(', '),
                })
              : null}
          </span>

          {isMapping ? (
            <Button
              onClick={handleStartImport}
              disabled={missingRequired.length > 0 || completeMapping.isPending}
            >
              {completeMapping.isPending
                ? t('admin.imports.mapping.starting')
                : t('admin.imports.mapping.start')}
            </Button>
          ) : (
            <div className="flex items-center gap-2">
              {imp.failed_rows_count > 0 && (
                <Button
                  variant="outline"
                  onClick={() =>
                    retryMutation.mutate(undefined, { onSuccess: () => setRetryRequested(true) })
                  }
                  disabled={retryMutation.isPending}
                >
                  <RotateCcwIcon className="size-4" />
                  {retryMutation.isPending
                    ? t('admin.imports.results.retrying')
                    : t('admin.imports.results.retry_failed', { failed: imp.failed_rows_count })}
                </Button>
              )}
              {onViewRecords && (
                <Button
                  onClick={() => {
                    onClose()
                    onViewRecords(imp.type)
                  }}
                >
                  {t('admin.imports.results.view_records', { type: importTypeLabel(imp.type) })}
                </Button>
              )}
            </div>
          )}
        </DialogFooter>
      )}
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
    <WizardProgress
      className="hidden w-56 shrink-0 py-8 ps-8 md:flex"
      current={steps[activeIndex]}
      steps={steps.map((step) => ({ key: step, label: t(`admin.imports.steps.${step}`) }))}
    />
  )
}

// ---------------------------------------------------------------------------
// Mapping step
// ---------------------------------------------------------------------------

/** Which schema field each CSV column feeds, keyed by field name. */
export type MappingAssignments = Record<string, string | null>

export function initialAssignments(imp: PanelImport): MappingAssignments {
  return Object.fromEntries(imp.mappings.map((m) => [m.schema_field, m.file_column]))
}

export function missingRequiredFields(imp: PanelImport, assignments: MappingAssignments) {
  return imp.schema_fields.filter((f) => f.required && !assignments[f.name])
}

/**
 * The mapping table. Assignments live in the wizard rather than here, because
 * the action that submits them sits in the wizard's footer — a long column
 * list would otherwise bury the button below the fold.
 */
function MappingStep({
  imp,
  assignments,
  setAssignments,
  error,
}: {
  imp: PanelImport
  assignments: MappingAssignments
  setAssignments: React.Dispatch<React.SetStateAction<MappingAssignments>>
  /** Failure from the footer's submit, rendered beside the fields it concerns. */
  error?: Error | null
}) {
  const { t } = useTranslation()

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
            <TableHeader>
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

        {error && (
          <div className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-3 text-destructive text-sm">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>{error.message}</span>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Processing
// ---------------------------------------------------------------------------

// `retryPass` is the wizard's explicit marker that the user triggered a
// failed-rows retry: every row is already terminal then, so the bar would sit
// at 100% — show the shrinking failed count instead.
function ProcessingCard({ imp, retryPass }: { imp: PanelImport; retryPass: boolean }) {
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

function ResultsCard({ imp }: { imp: PanelImport }) {
  const { t } = useTranslation()

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
      </CardContent>
    </Card>
  )
}

function FailedCard({ imp }: { imp: PanelImport }) {
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

function FailedRowsCard({ imp }: { imp: PanelImport }) {
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
                <TableHeader>
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

function FailedRow({ row }: { row: PanelImportRow }) {
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
