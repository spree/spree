import type { Variant } from '@spree/admin-sdk'
import { ImageUploadField, useTranslation } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldLabel,
  Input,
  MediaPreview,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { CheckIcon } from 'lucide-react'
import { useCallback, useEffect, useRef } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { parseVideoUrl } from '../../../lib/video-url'
import type { ProductFormValues } from '../../../schemas/product'

// The fields this sheet edits. Snapshot, cancel-restore and the type all derive
// from this one list, so a new editable field can't reach the form and then be
// missed by the restore — which would silently keep an edit the merchant cancelled.
const EDITED_FIELDS = [
  'alt',
  'variant_ids',
  'external_video_url',
  'focal_point_x',
  'focal_point_y',
  'poster_signed_id',
  'posterUrl',
] as const

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
  type Snapshot = Pick<MediaRow, (typeof EDITED_FIELDS)[number]> & { key: string | null }
  const snapshotRef = useRef<Snapshot | null>(null)
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
      // Copy each value as-is. Normalizing to null would turn an absent
      // `poster_signed_id` — typed string | undefined — into a value the
      // schema rejects, so cancelling would break the next save.
      ...(Object.fromEntries(EDITED_FIELDS.map((field) => [field, row[field]])) as Pick<
        MediaRow,
        (typeof EDITED_FIELDS)[number]
      >),
      // Copy the array — the snapshot must not alias the row's own value.
      variant_ids: [...(row.variant_ids ?? [])],
      key: rowKey(row),
    }
  }, [open, mediaIndex, form, rowKey])

  const entry = form.watch(`media.${mediaIndex}`)
  if (!entry) return null

  // For an image this is the picture itself; for a hosted video it is the file
  // the merchant just picked (a blob URL) or the URL the API serves it at.
  const previewUrl = entry.previewUrl ?? null
  const alt = entry.alt ?? ''
  const selectedVariantIds = new Set(entry.variant_ids ?? [])

  const setAlt = (value: string) => {
    form.setValue(`media.${mediaIndex}.alt`, value, { shouldDirty: true })
  }

  const mediaType = entry.media_type ?? 'image'
  const isImage = mediaType === 'image'
  const isHostedVideo = mediaType === 'video'
  const isExternalVideo = mediaType === 'external_video'
  // Mirrors Spree::Media#playable_video? — both kinds want a poster.
  const isVideo = isHostedVideo || isExternalVideo
  const externalVideoUrl = entry.external_video_url ?? ''
  // The video file itself — a blob URL before save, the served file after.
  const videoUrl = entry.videoUrl ?? null
  const parsedVideo = parseVideoUrl(externalVideoUrl)
  const videoUrlInvalid = externalVideoUrl.length > 0 && !parsedVideo

  const focalPoint =
    entry.focal_point_x != null && entry.focal_point_y != null
      ? { x: entry.focal_point_x, y: entry.focal_point_y }
      : null

  const setExternalVideoUrl = (value: string) => {
    form.setValue(`media.${mediaIndex}.external_video_url`, value, { shouldDirty: true })
  }

  // Click the image where it should stay in frame when a storefront crops it.
  const handleFocalPointClick = (event: React.MouseEvent<HTMLElement>) => {
    if (!isImage) return

    const bounds = event.currentTarget.getBoundingClientRect()
    if (bounds.width === 0 || bounds.height === 0) return

    const round = (value: number) => Math.round(Math.min(1, Math.max(0, value)) * 1000) / 1000

    form.setValue(
      `media.${mediaIndex}.focal_point_x`,
      round((event.clientX - bounds.left) / bounds.width),
      { shouldDirty: true },
    )
    form.setValue(
      `media.${mediaIndex}.focal_point_y`,
      round((event.clientY - bounds.top) / bounds.height),
      { shouldDirty: true },
    )
  }

  // The poster is a still the merchant supplies for a video. YouTube provides
  // one, so this is how the other cases — Vimeo, uploaded files — get a tile
  // that isn't blank.
  const posterValue = {
    signedId: entry.poster_signed_id ?? null,
    previewUrl: entry.posterUrl ?? null,
    cleared: entry.poster_signed_id === '',
  }

  const setPoster = (value: {
    signedId: string | null
    previewUrl: string | null
    cleared: boolean
  }) => {
    // An empty string is how the API is told to drop the poster; `undefined`
    // would fall out of the request body and leave the old one in place.
    const next = value.cleared ? '' : (value.signedId ?? undefined)
    form.setValue(`media.${mediaIndex}.poster_signed_id`, next, { shouldDirty: true })
    form.setValue(`media.${mediaIndex}.posterUrl`, value.cleared ? null : value.previewUrl, {
      shouldDirty: true,
    })
  }

  const clearFocalPoint = () => {
    form.setValue(`media.${mediaIndex}.focal_point_x`, null, { shouldDirty: true })
    form.setValue(`media.${mediaIndex}.focal_point_y`, null, { shouldDirty: true })
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
      // Restore only the fields the sheet writes to — a sibling card might have
      // appended a new upload while the sheet was open, so overwriting the whole
      // `media` array would drop it. The parent form's isDirty bit may stay true
      // after a cancel; it clears on the next Save round-trip.
      for (const field of EDITED_FIELDS) {
        form.setValue(`media.${targetIndex}.${field}`, snap[field], {
          shouldDirty: false,
          shouldTouch: false,
        })
      }
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
          <MediaPreview
            mediaType={entry.media_type}
            previewUrl={previewUrl}
            videoUrl={videoUrl}
            embedUrl={parsedVideo?.embedUrl}
            alt={alt}
            focalPoint={focalPoint}
            onFocalPointClick={handleFocalPointClick}
          />

          {isImage && previewUrl && (
            <div className="flex items-center justify-between gap-2 -mt-3">
              <p className="text-xs text-muted-foreground">
                {t('admin.products.media.focal_point_help')}
              </p>
              {focalPoint && (
                <Button type="button" variant="ghost" size="sm" onClick={clearFocalPoint}>
                  {t('admin.products.media.focal_point_reset')}
                </Button>
              )}
            </div>
          )}

          {isExternalVideo && (
            <Field>
              <FieldLabel htmlFor="media-video-url">
                {t('admin.fields.media.external_video_url.label')}
              </FieldLabel>
              <Input
                id="media-video-url"
                value={externalVideoUrl}
                aria-invalid={videoUrlInvalid || undefined}
                onChange={(e) => setExternalVideoUrl(e.target.value)}
                placeholder={t('admin.fields.media.external_video_url.placeholder')}
              />
              {videoUrlInvalid && (
                <FieldError>{t('admin.products.media.video_url_invalid')}</FieldError>
              )}
            </Field>
          )}

          <Field>
            <FieldLabel htmlFor="media-alt">{t('admin.fields.media.alt.label')}</FieldLabel>
            <Input
              id="media-alt"
              value={alt}
              onChange={(e) => setAlt(e.target.value)}
              placeholder={t('admin.fields.media.alt.placeholder')}
            />
          </Field>

          {isVideo && (
            <Field>
              <FieldLabel>{t('admin.fields.media.poster.label')}</FieldLabel>
              <ImageUploadField
                value={posterValue}
                onChange={setPoster}
                help={t('admin.fields.media.poster.help')}
              />
            </Field>
          )}

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
          <Button type="button" variant="outline" onClick={handleCancel}>
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
  return (
    named.options_text ||
    named.name ||
    named.sku ||
    v.id ||
    i18n.t('admin.products.variants.variant_label')
  )
}
