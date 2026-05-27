import { CheckIcon, ImagePlusIcon, Loader2Icon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useProductMedia, useUpdateProductMedia } from '@/hooks/use-product-media'
import { useVariantMedia } from '@/hooks/use-variant-media'

type Props = {
  productId: string
  variantId: string
  triggerLabel?: string
  triggerVariant?: 'default' | 'outline' | 'ghost' | 'destructive' | 'link'
}

export function VariantMediaPicker({
  productId,
  variantId,
  triggerLabel = 'Select from product gallery',
  triggerVariant = 'outline',
}: Props) {
  const [open, setOpen] = useState(false)
  const [selectedMediaIds, setSelectedMediaIds] = useState<Set<string>>(new Set())

  const productMediaQuery = useProductMedia(productId)
  const variantMediaQuery = useVariantMedia(productId, variantId)
  const updateMedia = useUpdateProductMedia(productId)

  const productMedia = productMediaQuery.data?.data ?? []
  const variantLinkedMediaIds = useMemo(
    () => new Set((variantMediaQuery.data?.data ?? []).map((m) => m.id)),
    [variantMediaQuery.data],
  )

  const linkable = productMedia.filter((m) => !variantLinkedMediaIds.has(m.id))

  const toggle = (mediaId: string) => {
    setSelectedMediaIds((prev) => {
      const next = new Set(prev)
      if (next.has(mediaId)) {
        next.delete(mediaId)
      } else {
        next.add(mediaId)
      }
      return next
    })
  }

  const handleAdd = async () => {
    await Promise.all(
      Array.from(selectedMediaIds).map((mediaId) => {
        const asset = productMedia.find((m) => m.id === mediaId)
        const next = new Set(asset?.variant_ids ?? [])
        next.add(variantId)
        return updateMedia.mutateAsync({ id: mediaId, variant_ids: Array.from(next) })
      }),
    )
    setSelectedMediaIds(new Set())
    setOpen(false)
  }

  return (
    <>
      <Button variant={triggerVariant} size="sm" onClick={() => setOpen(true)}>
        {triggerLabel}
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Select from product gallery</DialogTitle>
          </DialogHeader>
          <DialogBody>
            {productMediaQuery.isLoading ? (
              <div className="flex items-center justify-center py-12 text-muted-foreground">
                <Loader2Icon className="size-5 animate-spin" />
              </div>
            ) : linkable.length === 0 ? (
              <div className="flex flex-col items-center justify-center gap-2 py-12 text-muted-foreground">
                <ImagePlusIcon className="size-6" />
                <p className="text-sm">
                  {productMedia.length === 0
                    ? 'No product media yet — upload images on the product first.'
                    : 'All product media is already linked to this variant.'}
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
                {linkable.map((mediaItem) => {
                  const selected = selectedMediaIds.has(mediaItem.id)
                  const url = mediaItem.small_url || mediaItem.mini_url || mediaItem.original_url
                  return (
                    <button
                      key={mediaItem.id}
                      type="button"
                      onClick={() => toggle(mediaItem.id)}
                      aria-pressed={selected}
                      className={`group relative aspect-square overflow-hidden rounded-lg border-2 transition-colors ${
                        selected ? 'border-primary' : 'border-border hover:border-muted-foreground'
                      }`}
                    >
                      {url ? (
                        <img
                          src={url}
                          alt={mediaItem.alt ?? ''}
                          className="size-full object-cover"
                        />
                      ) : (
                        <div className="flex size-full items-center justify-center bg-muted text-muted-foreground">
                          <ImagePlusIcon className="size-6" />
                        </div>
                      )}
                      {selected && (
                        <span className="absolute top-1.5 right-1.5 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground size-5 shadow-sm">
                          <CheckIcon className="size-3" />
                        </span>
                      )}
                    </button>
                  )
                })}
              </div>
            )}
          </DialogBody>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={handleAdd}
              disabled={selectedMediaIds.size === 0 || updateMedia.isPending}
            >
              {updateMedia.isPending ? (
                <>
                  <Loader2Icon className="size-4 animate-spin" />
                  Adding…
                </>
              ) : (
                `Add ${selectedMediaIds.size || ''}`.trim()
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}
