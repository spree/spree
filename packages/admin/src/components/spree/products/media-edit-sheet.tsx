import type { Media, Variant } from '@spree/admin-sdk'
import { CheckIcon, DownloadIcon, ExternalLinkIcon, ImagePlusIcon, Loader2Icon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Field, FieldLabel } from '@/components/ui/field'
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Textarea } from '@/components/ui/textarea'
import { useUpdateProductMedia } from '@/hooks/use-product-media'

type Props = {
  productId: string
  mediaItem: Media | null
  variants: Variant[]
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function MediaEditSheet({ productId, mediaItem, variants, open, onOpenChange }: Props) {
  const updateMedia = useUpdateProductMedia(productId)

  const [alt, setAlt] = useState('')
  const [selectedVariantIds, setSelectedVariantIds] = useState<Set<string>>(new Set())

  // Sync local state to mediaItem so switching assets doesn't leak edits.
  useEffect(() => {
    if (mediaItem) {
      setAlt(mediaItem.alt ?? '')
      setSelectedVariantIds(new Set(mediaItem.variant_ids ?? []))
    }
  }, [mediaItem])

  const initialAlt = mediaItem?.alt ?? ''
  const initialVariantIds = mediaItem?.variant_ids ?? []
  const altChanged = alt !== initialAlt
  const variantsChanged =
    initialVariantIds.length !== selectedVariantIds.size ||
    initialVariantIds.some((id) => !selectedVariantIds.has(id))

  const toggleVariant = (variantId: string) => {
    setSelectedVariantIds((prev) => {
      const next = new Set(prev)
      if (next.has(variantId)) next.delete(variantId)
      else next.add(variantId)
      return next
    })
  }

  const handleSave = async () => {
    if (!mediaItem) return

    try {
      const patch: { id: string; alt?: string; variant_ids?: string[] } = { id: mediaItem.id }
      if (altChanged) patch.alt = alt
      if (variantsChanged) patch.variant_ids = Array.from(selectedVariantIds)
      await updateMedia.mutateAsync(patch)

      toast.success('Media updated')
      onOpenChange(false)
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to update image'
      toast.error(message)
    }
  }

  // Prefer the largest pre-rendered variant for the in-sheet preview; fall back
  // to the original. The full-size link points at original_url; download_url
  // is the same blob with disposition=attachment so cloud storage saves instead
  // of inlines.
  const previewUrl =
    mediaItem?.large_url ||
    mediaItem?.medium_url ||
    mediaItem?.small_url ||
    mediaItem?.original_url ||
    null
  const fullSizeUrl = mediaItem?.original_url ?? null
  const downloadUrl = mediaItem?.download_url ?? null

  const dirty = altChanged || variantsChanged

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" showCloseButton className="flex flex-col">
        <SheetHeader>
          <SheetTitle>Edit media</SheetTitle>
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
            {(fullSizeUrl || downloadUrl) && (
              <div className="absolute bottom-2 right-2 flex gap-1.5 opacity-0 transition-opacity group-hover:opacity-100">
                {fullSizeUrl && (
                  <a
                    href={fullSizeUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 rounded-md bg-background/90 px-2 py-1 text-xs font-medium text-foreground shadow-sm hover:bg-background"
                  >
                    <ExternalLinkIcon className="size-3" />
                    View full size
                  </a>
                )}
                {downloadUrl && (
                  <a
                    href={downloadUrl}
                    className="inline-flex items-center gap-1 rounded-md bg-background/90 px-2 py-1 text-xs font-medium text-foreground shadow-sm hover:bg-background"
                  >
                    <DownloadIcon className="size-3" />
                    Download
                  </a>
                )}
              </div>
            )}
          </div>

          <Field>
            <FieldLabel htmlFor="media-alt">Alt text</FieldLabel>
            <Textarea
              id="media-alt"
              value={alt}
              onChange={(e) => setAlt(e.target.value)}
              rows={3}
              placeholder="Describe the image for accessibility and SEO"
            />
          </Field>

          {variants.length > 0 && (
            <Field>
              <FieldLabel>Assigned variants</FieldLabel>
              <p className="text-xs text-muted-foreground">
                Pick the variants this image represents. Leave blank to apply to all variants.
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
          <Button
            variant="ghost"
            onClick={() => onOpenChange(false)}
            disabled={updateMedia.isPending}
          >
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={!dirty || updateMedia.isPending}>
            {updateMedia.isPending ? (
              <>
                <Loader2Icon className="size-4 animate-spin" />
                Saving…
              </>
            ) : (
              'Save'
            )}
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
