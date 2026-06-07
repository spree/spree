import type { Variant } from '@spree/admin-sdk'
import { useTranslation } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldLabel,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Textarea,
} from '@spree/dashboard-ui'
import { CheckIcon, ImagePlusIcon } from 'lucide-react'
import { useCallback, useEffect, useRef } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import type { ProductFormValues } from '@/schemas/product'

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  mediaIndex: number
  variants: Variant[]
  open: boolean
  onOpenChange: (open: boolean) => void
}

// Form-backed media editor. The sheet edits `form.media[index]` directly —
// changes ride the parent product PATCH/POST, no per-asset API calls.
// Cancel restores a snapshot taken on open; Done closes (parent form Save
// commits). Same model as the per-variant Sheet.
export function MediaEditSheet({ form, mediaIndex, variants, open, onOpenChange }: Props) {
  const { t } = useTranslation()

  // Snapshot on open so Cancel can restore. Re-snapshot if mediaIndex changes
  // while the sheet remains open (user switches between rows).
  //
  // Capture the row's stable identity (server `id`, or pre-save `signed_id`,
  // or in-flight `uploadId`) alongside the values. Reordering the media grid
  // while the sheet is open shifts what lives at `mediaIndex`, so cancel /
  // save resolve the target row by id rather than trusting the index. For a
  // freshly-uploaded row that has no id yet we fall back to the current
  // index — uploads don't surface a drag handle so the race is impossible.
  type MediaRow = NonNullable<ProductFormValues['media']>[number]
  const snapshotRef = useRef<{
    alt: string | null
    variant_ids: string[]
    key: string | null
  } | null>(null)
  const rowKey = useCallback(
    (m: MediaRow): string | null => m.id ?? m.signed_id ?? m.uploadId ?? null,
    [],
  )

  useEffect(() => {
    if (!open) {
      snapshotRef.current = null
      return
    }
    const current = form.getValues('media') ?? []
    const row = current[mediaIndex]
    if (!row) return
    snapshotRef.current = {
      alt: row.alt ?? null,
      variant_ids: [...(row.variant_ids ?? [])],
      key: rowKey(row),
    }
  }, [open, mediaIndex, form, rowKey])

  const entry = form.watch(`media.${mediaIndex}`)
  if (!entry) return null

  const previewUrl = entry.previewUrl ?? null
  const alt = entry.alt ?? ''
  const selectedVariantIds = new Set(entry.variant_ids ?? [])

  const setAlt = (value: string) => {
    form.setValue(`media.${mediaIndex}.alt`, value, { shouldDirty: true })
  }

  const toggleVariant = (variantId: string) => {
    const next = new Set(selectedVariantIds)
    if (next.has(variantId)) next.delete(variantId)
    else next.add(variantId)
    form.setValue(`media.${mediaIndex}.variant_ids`, Array.from(next), { shouldDirty: true })
  }

  const handleCancel = () => {
    const snap = snapshotRef.current
    if (snap) {
      // Resolve the row by stable key — the media array may have reordered
      // while the sheet was open. Skip the restore if the row vanished
      // (e.g. delete from the grid) so we don't write the snapshot onto a
      // different image's alt/variant_ids.
      let targetIndex = mediaIndex
      if (snap.key) {
        const all = form.getValues('media') ?? []
        const found = all.findIndex((m) => rowKey(m) === snap.key)
        if (found === -1) return onOpenChange(false)
        targetIndex = found
      }
      // Restore the two fields the sheet writes to (`alt`, `variant_ids`)
      // from the open-time snapshot. We deliberately scope to those keys
      // rather than overwriting the whole `media` array — a sibling card
      // might have appended a new upload while the sheet was open.
      //
      // Use setValue with `shouldDirty: false` to write the snapshot
      // value back; the UI updates immediately via the form.watch
      // subscriptions. We accept that the parent form's isDirty bit may
      // stay true if the user typed and then cancelled (it'll clear on
      // the parent form's Save round-trip).
      form.setValue(`media.${targetIndex}.alt`, snap.alt, {
        shouldDirty: false,
        shouldTouch: false,
      })
      form.setValue(`media.${targetIndex}.variant_ids`, snap.variant_ids, {
        shouldDirty: false,
        shouldTouch: false,
      })
    }
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={(o) => (o ? onOpenChange(o) : handleCancel())}>
      <SheetContent side="right" showCloseButton={false} className="flex flex-col">
        <SheetHeader>
          <SheetTitle>{t('admin.products.media.edit_title')}</SheetTitle>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-5">
          <div className="group relative overflow-hidden rounded-lg border border-border bg-muted">
            {previewUrl ? (
              <img src={previewUrl} alt={alt} className="w-full max-h-[60vh] object-contain" />
            ) : (
              <div className="flex aspect-square w-full items-center justify-center text-muted-foreground">
                <ImagePlusIcon className="size-8" />
              </div>
            )}
          </div>

          <Field>
            <FieldLabel htmlFor="media-alt">{t('admin.fields.media.alt.label')}</FieldLabel>
            <Textarea
              id="media-alt"
              value={alt}
              onChange={(e) => setAlt(e.target.value)}
              rows={3}
              placeholder={t('admin.fields.media.alt.placeholder')}
            />
          </Field>

          {variants.length > 0 && (
            <Field>
              <FieldLabel>{t('admin.products.media.assigned_variants_label')}</FieldLabel>
              <p className="text-xs text-muted-foreground">
                {t('admin.products.media.assigned_variants_help')}
              </p>
              <div className="flex flex-wrap gap-2 pt-2">
                {variants.map((v) => {
                  const id = v.id
                  if (!id) return null
                  const selected = selectedVariantIds.has(id)
                  const label = variantLabel(v)
                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => toggleVariant(id)}
                      aria-pressed={selected}
                      className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                        selected
                          ? 'border-primary bg-primary text-primary-foreground'
                          : 'border-border bg-background text-muted-foreground hover:border-muted-foreground hover:text-foreground'
                      }`}
                    >
                      {selected && <CheckIcon className="size-3" />}
                      {label}
                    </button>
                  )
                })}
              </div>
            </Field>
          )}
        </div>

        <SheetFooter>
          <Button type="button" variant="ghost" onClick={handleCancel}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function variantLabel(v: Variant): string {
  const named = v as { options_text?: string; name?: string; sku?: string | null }
  return named.options_text || named.name || named.sku || v.id || 'Variant'
}
