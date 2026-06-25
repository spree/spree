import {
  type ResourceTranslations,
  type ResourceTranslationsNode,
  SpreeError,
  type TranslatableField,
  type TranslationBatchEntry,
} from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
  Button,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
  RichTextEditor,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { XIcon } from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useLocales } from '@/hooks/use-translations'

/** One editable row in the grid: a translatable entity (the resource itself or
 *  a nested child like an option value). */
export interface TranslationRow {
  resourceType: string
  resourceId: string
  /** Visual nesting depth (0 = root, 1 = child). */
  indent: number
  fields: TranslatableField[]
  /** locale → field → stored value (null/absent = untranslated). */
  translations: Record<string, Record<string, string | number | null>>
  /** Optional override for the left-column label (e.g. a value's own label).
   *  When omitted the field's i18n label is used (single-field rows). */
  rowLabel?: string
}

interface ResourceTranslationsDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Translation matrix document (root, possibly with nested `children`). */
  data?: ResourceTranslations
  isLoading?: boolean
  isError?: boolean
  /** Resolves a field key to its display label (resource-specific i18n). */
  fieldLabel: (resourceType: string, field: TranslatableField) => string
  /** Called after a successful save so the parent can refetch. */
  onSaved?: () => void
}

/** Edits keyed by `${resourceId}::${locale}::${field}` → value. */
type EditMap = Map<string, string>
const cellKey = (resourceId: string, locale: string, field: string) =>
  `${resourceId}::${locale}::${field}`

/**
 * Generic full-page translations editor. Renders a flat list of translatable
 * rows (the resource plus any nested children) as a spreadsheet — locale
 * dropdown picks the target column, "Original" shows the source. Edits
 * accumulate across locales and rows; one Save batches them into a single
 * atomic `POST /admin/translations/batch`. Products are the degenerate case
 * (rows are one resource's fields); option types add value rows of another
 * resource type. Modeled on Medusa's editor + the bulk price dialog.
 */
export function ResourceTranslationsDialog({
  open,
  onOpenChange,
  data,
  isLoading,
  isError,
  fieldLabel,
  onSaved,
}: ResourceTranslationsDialogProps) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data: locales } = useLocales()

  const rows = useMemo(() => (data ? flattenTree(data) : []), [data])
  const targetLocales = useMemo(
    () => (data ? data.supported_locales.filter((l) => l !== data.default_locale) : []),
    [data],
  )

  const [locale, setLocale] = useState('')
  const [edits, setEdits] = useState<EditMap>(() => new Map())
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (open) {
      setEdits(new Map())
      setLocale('')
    }
  }, [open])

  useEffect(() => {
    if (!locale && targetLocales.length > 0) setLocale(targetLocales[0])
  }, [locale, targetLocales])

  const dirtyCount = edits.size
  const localeName = useCallback(
    (code: string) => locales?.find((l) => l.code === code)?.name ?? code,
    [locales],
  )

  const handleOpenChange = useCallback(
    async (next: boolean) => {
      if (next || dirtyCount === 0) {
        onOpenChange(next)
        return
      }
      const ok = await confirm({
        title: t('admin.translations.discard_confirm.title'),
        message: t('admin.translations.discard_confirm.message', { count: dirtyCount }),
        variant: 'destructive',
        confirmLabel: t('admin.actions.discard_changes'),
      })
      if (ok) onOpenChange(false)
    },
    [dirtyCount, onOpenChange, confirm, t],
  )

  async function handleSave() {
    if (edits.size === 0) return
    // Group flat edits into one batch entry per (resourceType, resourceId).
    const rowById = new Map(rows.map((r) => [r.resourceId, r]))
    const byResource = new Map<string, TranslationBatchEntry>()
    for (const [key, value] of edits) {
      const [resourceId, loc, field] = key.split('::')
      const row = rowById.get(resourceId)
      if (!row) continue
      let entry = byResource.get(resourceId)
      if (!entry) {
        entry = { resource_type: row.resourceType, resource_id: resourceId, values: {} }
        byResource.set(resourceId, entry)
      }
      entry.values[loc] ??= {}
      entry.values[loc][field] = value
    }

    setSaving(true)
    try {
      await adminClient.translations.batch(Array.from(byResource.values()))
      toast.success(t('admin.translations.saved'))
      setEdits(new Map())
      onSaved?.()
    } catch (err) {
      // The grid has no form to render inline errors onto, so surface the
      // server's validation message (if any) in the toast rather than the
      // generic fallback.
      const message = err instanceof SpreeError ? err.message : undefined
      toast.error(message || t('admin.translations.save_error'))
    } finally {
      setSaving(false)
    }
  }

  const localeItems = useMemo(
    () => targetLocales.map((code) => ({ value: code, label: localeName(code) })),
    [targetLocales, localeName],
  )

  return (
    <Dialog open={open} onOpenChange={handleOpenChange} modal>
      <DialogContent
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
          <div className="flex min-w-0 items-center gap-3">
            <Button
              type="button"
              size="icon-sm"
              variant="ghost"
              onClick={() => handleOpenChange(false)}
              aria-label={t('admin.actions.close')}
            >
              <XIcon />
            </Button>
            <DialogTitle className="sr-only">{t('admin.translations.title')}</DialogTitle>
            {targetLocales.length > 0 && (
              <Select items={localeItems} value={locale} onValueChange={setLocale}>
                <SelectTrigger
                  size="sm"
                  className="w-48"
                  aria-label={t('admin.translations.locale')}
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {localeItems.map((item) => (
                    <SelectItem key={item.value} value={item.value}>
                      {item.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          </div>
          <div className="flex items-center gap-2">
            {dirtyCount > 0 && (
              <span className="text-xs text-muted-foreground">
                {t('admin.translations.dirty_summary', { count: dirtyCount })}
              </span>
            )}
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={dirtyCount === 0 || saving}
              onClick={() => setEdits(new Map())}
            >
              {t('admin.actions.discard')}
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={dirtyCount === 0 || saving}
              onClick={handleSave}
            >
              {saving ? t('admin.actions.saving') : t('admin.translations.save')}
            </Button>
          </div>
        </DialogHeader>
        <DialogBody className="flex min-h-0 flex-1 flex-col overflow-auto p-0">
          {isError ? (
            <p className="p-3 text-sm text-destructive" role="alert">
              {t('admin.translations.load_error')}
            </p>
          ) : isLoading || !data ? (
            <Skeleton className="m-3 h-40" />
          ) : targetLocales.length === 0 ? (
            <p className="p-3 text-sm text-muted-foreground">
              {t('admin.translations.no_locales')}
            </p>
          ) : (
            locale && (
              <TranslationGrid
                rows={rows}
                locale={locale}
                localeName={localeName(locale)}
                fieldLabel={fieldLabel}
                edits={edits}
                setEdits={setEdits}
              />
            )
          )}
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}

function TranslationGrid({
  rows,
  locale,
  localeName,
  fieldLabel,
  edits,
  setEdits,
}: {
  rows: TranslationRow[]
  locale: string
  localeName: string
  fieldLabel: (resourceType: string, field: TranslatableField) => string
  edits: EditMap
  setEdits: React.Dispatch<React.SetStateAction<EditMap>>
}) {
  const { t } = useTranslation()

  const cellValue = useCallback(
    (row: TranslationRow, field: string): string => {
      const key = cellKey(row.resourceId, locale, field)
      if (edits.has(key)) return edits.get(key) as string
      const stored = row.translations[locale]?.[field]
      return typeof stored === 'string' ? stored : ''
    },
    [edits, locale],
  )

  const handleChange = useCallback(
    (row: TranslationRow, field: TranslatableField, next: string) => {
      setEdits((prev) => {
        const key = cellKey(row.resourceId, locale, field.key)
        const stored = row.translations[locale]?.[field.key]
        const baseline = typeof stored === 'string' ? stored : ''
        const unchanged = field.type === 'html' ? sameRichText(next, baseline) : next === baseline
        const out = new Map(prev)
        if (unchanged) out.delete(key)
        else out.set(key, next)
        return out
      })
    },
    [setEdits, locale],
  )

  return (
    <table className="w-full table-fixed border-collapse text-sm">
      <colgroup>
        <col className="w-56" />
        <col />
        <col />
      </colgroup>
      <thead className="sticky top-0 z-10 bg-muted/40">
        <tr className="text-left text-xs text-muted-foreground">
          <th className="border-b border-r px-3 py-2 font-medium" />
          <th className="border-b border-r px-3 py-2 font-medium">
            {t('admin.translations.original')}
          </th>
          <th className="border-b px-3 py-2 font-medium">{localeName}</th>
        </tr>
      </thead>
      <tbody>
        {rows.flatMap((row) =>
          row.fields.map((field) => {
            // Stable cell identifier for aria-label / testid. Root rows are
            // identified by the field key (`name`); child rows (whose field key
            // repeats, e.g. `label`) by their source label so each is unique.
            const cellName =
              row.indent === 0 ? field.key : (row.rowLabel ?? field.source ?? field.key)
            return (
              <tr key={`${row.resourceId}.${field.key}`}>
                <th
                  className="border-b border-r px-3 py-2 text-left align-top font-medium"
                  style={{ paddingLeft: `${0.75 + row.indent * 1}rem` }}
                >
                  {row.rowLabel ?? fieldLabel(row.resourceType, field)}
                </th>
                <td
                  className="border-b border-r px-3 py-2 align-top text-muted-foreground"
                  data-testid={`source-${cellName}`}
                >
                  {stripHtml(field.source ?? '')}
                </td>
                <td
                  className={cn(
                    'relative border-b p-0 align-top',
                    'focus-within:z-10 focus-within:ring-1 focus-within:ring-ring focus-within:ring-inset',
                  )}
                >
                  {field.type === 'html' ? (
                    <RichTextEditor
                      ariaLabel={`${cellName} ${locale}`}
                      className="rounded-none border-0 bg-transparent shadow-none focus-within:border-0 focus-within:shadow-none [&_.tiptap]:min-h-20"
                      value={cellValue(row, field.key)}
                      onChange={(next: string) => handleChange(row, field, next)}
                    />
                  ) : (
                    <Textarea
                      aria-label={`${cellName} ${locale}`}
                      rows={1}
                      className="min-h-0 resize-none rounded-none border-0 bg-transparent px-3 py-2 shadow-none focus:border-transparent focus:shadow-none focus-visible:ring-0"
                      value={cellValue(row, field.key)}
                      onChange={(e) => handleChange(row, field, e.target.value)}
                    />
                  )}
                </td>
              </tr>
            )
          }),
        )}
      </tbody>
    </table>
  )
}

/** Flattens the matrix tree (root + nested children) into ordered rows.
 *  A child's left-column label is its own source value (e.g. "Small"), so the
 *  grid reads as a hierarchy; the root's rows use the field i18n labels. */
function flattenTree(data: ResourceTranslations): TranslationRow[] {
  const rows: TranslationRow[] = []

  const pushNode = (node: ResourceTranslations | ResourceTranslationsNode, indent: number) => {
    rows.push({
      resourceType: node.resource_type,
      resourceId: node.resource_id,
      indent,
      fields: node.fields,
      translations: node.translations,
      // Children typically have a single field; label the row by its source so
      // the hierarchy reads naturally ("Size" → "Small", "Medium").
      rowLabel: indent > 0 ? (node.fields[0]?.source ?? undefined) : undefined,
    })
    for (const child of node.children ?? []) pushNode(child, indent + 1)
  }

  pushNode(data, 0)
  return rows
}

// Plain text of an HTML fragment. DOMParser handles nested/malformed tags
// correctly — a single-pass regex strip can leak tags via patterns like
// `<scr<script>ipt>` (CodeQL js/incomplete-multi-character-sanitization).
function stripHtml(html: string): string {
  return (new DOMParser().parseFromString(html, 'text/html').body.textContent ?? '').trim()
}

// Equal markup, or both empty-equivalent (`""`, `<p></p>`, `<p><br></p>`) — the
// latter prevents the rich-text editor's mount-time `<p></p>` emission from
// registering as a change against an empty baseline.
function sameRichText(a: string, b: string): boolean {
  return a === b || (!stripHtml(a) && !stripHtml(b))
}
