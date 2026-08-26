import {
  DndContext,
  type DragEndEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  rectSortingStrategy,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Media, Product, Variant } from '@spree/admin-sdk'
import {
  adminClient,
  MediaPickerSheet,
  ResourceMultiAutocomplete,
  TagCombobox,
  useDirectUpload,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
  DragHandle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusCard as SharedStatusCard,
  Textarea,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  DownloadIcon,
  FilmIcon,
  ImagePlusIcon,
  LibraryIcon,
  Loader2Icon,
  PencilIcon,
  PlayIcon,
  TrashIcon,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { type Control, Controller, type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { categoryAutocompleteProps, useCategories } from '../../../hooks/use-categories'
import { collectionAutocompleteProps, useCollections } from '../../../hooks/use-collections'
import { useDeliveryProfiles } from '../../../hooks/use-delivery-profiles'
import { useOptionTypesByIds } from '../../../hooks/use-option-types'
import { useDeleteProductMedia } from '../../../hooks/use-product-media'
import { useProductType, useProductTypes } from '../../../hooks/use-product-types'
import { useTaxCategories } from '../../../hooks/use-tax-categories'
import { parseVideoUrl } from '../../../lib/video-url'
import type { MediaType, ProductFormValues } from '../../../schemas/product'
import { ProductBulkPriceEditor } from '../bulk-price-editor/product-bulk-price-editor'
import { MediaRichTextEditor } from '../media-rich-text-editor'
import { AddVideoDialog } from './add-video-dialog'
import { InventorySection } from './inventory-section'
import { MediaEditSheet } from './media-edit-sheet'
import { VariantsSection } from './variants-section'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type FormCardProps = { form: UseFormReturn<ProductFormValues, any, any> }

// ---------------------------------------------------------------------------
// General
// ---------------------------------------------------------------------------

export function GeneralCard({ form }: FormCardProps) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_basics')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel htmlFor="product-name">{t('admin.fields.name.label')}</FieldLabel>
          <Input
            id="product-name"
            placeholder={t('admin.fields.product.name.placeholder')}
            aria-invalid={!!errors.name || undefined}
            {...form.register('name')}
          />
          <FieldError errors={[errors.name]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="product-description">
            {t('admin.fields.description.label')}
          </FieldLabel>
          <Controller
            name="description"
            control={form.control}
            render={({ field }) => (
              <MediaRichTextEditor
                id="product-description"
                ariaLabel={t('admin.fields.description.label')}
                value={field.value}
                onChange={field.onChange}
                placeholder={t('admin.fields.product.description.placeholder')}
              />
            )}
          />
        </Field>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Variants (just a passthrough so the page composition reads top-down)
// ---------------------------------------------------------------------------

export function VariantsCard({ form, seedFromType }: FormCardProps & { seedFromType?: boolean }) {
  return <VariantsSection form={form} seedFromType={seedFromType} />
}

// ---------------------------------------------------------------------------
// Prices — inline form-backed editor. Mirrors InventoryCard: a Card around a
// section that reads/writes form state directly. Save rides the parent
// product form's Save button; no modal, no snapshot, no separate
// save/discard. Currency switching is a view-only change because the form
// already holds every currency's prices for every variant.
// ---------------------------------------------------------------------------

export function PricesCard({ form, productName }: FormCardProps & { productName: string }) {
  const { t } = useTranslation()
  const { currencies, defaultCurrency } = useStore()
  const [currency, setCurrency] = useState(defaultCurrency)

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0">
        <CardTitle>{t('admin.common.prices')}</CardTitle>
        {currencies.length > 1 && (
          <Select value={currency} onValueChange={setCurrency}>
            <SelectTrigger size="sm" className="w-24">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {currencies.map((c) => (
                <SelectItem key={c} value={c}>
                  {c}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      </CardHeader>
      <CardContent>
        <ProductBulkPriceEditor form={form} currency={currency} productName={productName} />
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Media — edit-only. On create, render a "save first" empty state so the
// merchant sees where uploads will go but can't trigger them.
// ---------------------------------------------------------------------------

interface PendingUpload {
  id: string
  file: File
  preview: string
  progress: 'uploading' | 'attaching' | 'done' | 'error'
}

// What the gallery accepts. `accept` on the file input only constrains the OS
// picker — a drop bypasses it entirely, so handleDrop filters against the same
// list or an unsupported file uploads and then fails the whole product save.
const ACCEPTED_MEDIA = ['image/', 'video/mp4', 'video/webm', 'video/quicktime']

function isAcceptedMedia(file: File): boolean {
  return ACCEPTED_MEDIA.some((type) =>
    type.endsWith('/') ? file.type.startsWith(type) : file.type === type,
  )
}

// Unified, form-backed media card. Single source of truth: form.media.
// Both new and edit pages use the same component; the only difference is
// whether form.media starts empty (new) or pre-hydrated from the persisted
// product (edit, via productToFormValues). Uploads, alt edits, reorders,
// and variant_ids assignments all live in form state and ride the same
// product POST/PATCH. The dedicated DELETE /media endpoint stays — we
// don't ship deletes inline (no implicit-omission semantics).
export function MediaCard({
  productId,
  variants,
  form,
}: {
  productId?: string
  // The MediaEditSheet's "assign to variant" pill row needs the list of
  // server-persisted variants — only those have an id that can ride the
  // PATCH's media[].variant_ids. Form-state variants without a server id
  // can't be assigned until the merchant saves.
  variants?: Variant[]
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
}) {
  const { t } = useTranslation()
  const directUpload = useDirectUpload()
  const deleteMedia = useDeleteProductMedia(productId ?? '')
  const confirm = useConfirm()
  const [pending, setPending] = useState<PendingUpload[]>([])
  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const [addingVideo, setAddingVideo] = useState(false)
  const [pickingFromLibrary, setPickingFromLibrary] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const items = useWatch({ control: form.control, name: 'media' }) ?? []

  // dnd-kit needs a stable id per row. Persisted items have one; new uploads
  // get their uploadId (assigned at completion). signed_id is fine as a
  // fallback for items hydrated server-side without an uploadId.
  const sortableIds = useMemo(
    () => items.map((m, i) => m.id ?? m.uploadId ?? m.signed_id ?? `idx-${i}`),
    [items],
  )

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event
      if (!over || active.id === over.id) return
      const current = form.getValues('media') ?? []
      const fromIndex = sortableIds.indexOf(String(active.id))
      const toIndex = sortableIds.indexOf(String(over.id))
      if (fromIndex === -1 || toIndex === -1) return
      const next = [...current]
      const [moved] = next.splice(fromIndex, 1)
      next.splice(toIndex, 0, moved)
      form.setValue(
        'media',
        next.map((m, i) => ({ ...m, position: i + 1 })),
        { shouldDirty: true },
      )
    },
    [form, sortableIds],
  )

  const handleFiles = useCallback(
    async (files: FileList | File[]) => {
      const fileArray = Array.from(files)
      for (const file of fileArray) {
        const uploadId = crypto.randomUUID()
        const preview = URL.createObjectURL(file)
        setPending((prev) => [...prev, { id: uploadId, file, preview, progress: 'uploading' }])
        try {
          const result = await directUpload.mutateAsync(file)
          const current = form.getValues('media') ?? []
          form.setValue(
            'media',
            [
              ...current,
              {
                signed_id: result.signedId,
                alt: file.name,
                position: current.length + 1,
                media_type: file.type.startsWith('video/')
                  ? ('video' as const)
                  : ('image' as const),
                previewUrl: preview,
                // Lets an uploaded video play in the editor before it is saved.
                videoUrl: file.type.startsWith('video/') ? preview : null,
                uploadId,
              },
            ],
            { shouldDirty: true },
          )
          setPending((prev) => prev.filter((p) => p.id !== uploadId))
        } catch (err) {
          console.error(`Upload failed for ${file.name}:`, err)
          setPending((prev) =>
            prev.map((p) => (p.id === uploadId ? { ...p, progress: 'error' as const } : p)),
          )
          const message = err instanceof Error ? err.message : t('admin.errors.unexpected')
          toastManager.add({
            type: 'error',
            title: t('admin.products.media.upload_failed', { name: file.name, message }),
          })
        }
      }
    },
    [directUpload, form, t],
  )

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      const accepted = Array.from(e.dataTransfer.files).filter(isAcceptedMedia)
      const rejected = e.dataTransfer.files.length - accepted.length

      if (rejected > 0)
        toastManager.add({
          type: 'error',
          title: t('admin.products.media.unsupported_file', { count: rejected }),
        })
      if (accepted.length > 0) handleFiles(accepted)
    },
    [handleFiles, t],
  )

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
  }, [])

  // An external video has no file to upload — it goes straight into form state
  // with its link, and the provider's own still stands in as the preview.
  const handleAddVideo = useCallback(
    (url: string) => {
      const current = form.getValues('media') ?? []
      form.setValue(
        'media',
        [
          ...current,
          {
            media_type: 'external_video' as const,
            external_video_url: url,
            position: current.length + 1,
            previewUrl: parseVideoUrl(url)?.thumbnailUrl ?? undefined,
            uploadId: crypto.randomUUID(),
          },
        ],
        { shouldDirty: true },
      )
    },
    [form],
  )

  // Files picked from the library become ordinary form entries carrying the
  // source's id. The product save places them, sharing the file rather than
  // uploading a second copy.
  const handleAddFromLibrary = useCallback(
    (picked: Media[]) => {
      const current = form.getValues('media') ?? []
      form.setValue(
        'media',
        [
          ...current,
          ...picked.map((media, index) => ({
            source_media_id: media.id,
            alt: media.alt ?? undefined,
            media_type: (media.media_type ?? 'image') as MediaType,
            position: current.length + index + 1,
            previewUrl: media.small_url ?? media.original_url ?? undefined,
            videoUrl: media.video_url ?? null,
            posterUrl: media.poster_url ?? null,
            uploadId: crypto.randomUUID(),
          })),
        ],
        { shouldDirty: true },
      )
    },
    [form],
  )

  const handleDelete = useCallback(
    async (index: number) => {
      const current = form.getValues('media') ?? []
      const entry = current[index]
      if (!entry) return
      const confirmed = await confirm({
        message: t('admin.products.media.delete_confirm'),
        variant: 'destructive',
        confirmLabel: t('admin.actions.delete'),
      })
      if (!confirmed) return

      // Persisted entries call the dedicated DELETE endpoint first so we
      // don't drop the form-state entry until the server actually removed it.
      // Pre-save entries (signed_id only, no id) just disappear from form.
      if (entry.id && productId) {
        try {
          await deleteMedia.mutateAsync(entry.id)
        } catch {
          toastManager.add({ type: 'error', title: t('admin.errors.failed_to_delete') })
          return
        }
      }

      // Release the Blob URL we created at upload time so the browser can
      // reclaim its backing memory. Server-served previewUrls aren't blob:
      // URLs and don't need revocation.
      if (entry.previewUrl?.startsWith('blob:')) URL.revokeObjectURL(entry.previewUrl)

      const next = current.filter((_, i) => i !== index).map((m, i) => ({ ...m, position: i + 1 }))
      form.setValue('media', next, { shouldDirty: true })

      // Close or shift the edit sheet so it can't reference a stale index.
      // If the deleted row was being edited, close. If the deleted row was
      // BEFORE the open one, shift down by one.
      setEditingIndex((current) => {
        if (current == null) return current
        if (current === index) return null
        if (current > index) return current - 1
        return current
      })
    },
    [form, productId, deleteMedia, confirm, t],
  )

  // Revoke any remaining blob: previewUrls when the card unmounts (the
  // merchant navigated away mid-edit without saving). form.getValues is a
  // stable RHF method — listing it in deps wouldn't change effect timing
  // but it keeps the linter happy.
  useEffect(() => {
    return () => {
      const current = form.getValues('media') ?? []
      for (const m of current) {
        if (m.previewUrl?.startsWith('blob:')) URL.revokeObjectURL(m.previewUrl)
      }
    }
  }, [form])

  const editingEntry = editingIndex !== null ? items[editingIndex] : null

  return (
    <>
      <Card className="scroll-mt-[calc(var(--spacing-header-height)*2+1.5rem)]">
        <CardHeader>
          <CardTitle>{t('admin.pages.products.section_media')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {(items.length > 0 || pending.length > 0) && (
            <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
              <SortableContext items={sortableIds} strategy={rectSortingStrategy}>
                <div className="grid grid-cols-4 gap-3">
                  {items.map((media, index) => (
                    <SortableMediaThumbnail
                      key={sortableIds[index]}
                      sortableId={sortableIds[index]}
                      previewUrl={media.previewUrl ?? null}
                      downloadUrl={media.downloadUrl}
                      alt={media.alt ?? ''}
                      mediaType={media.media_type ?? 'image'}
                      onEdit={() => setEditingIndex(index)}
                      onDelete={() => handleDelete(index)}
                    />
                  ))}
                  {pending.map((upload) => (
                    <div
                      key={upload.id}
                      className="relative aspect-square overflow-hidden rounded-lg border border-border bg-muted"
                    >
                      {upload.file.type.startsWith('video/') ? (
                        <video
                          src={upload.preview}
                          muted
                          playsInline
                          preload="metadata"
                          className="size-full object-cover opacity-60"
                        />
                      ) : (
                        <img
                          src={upload.preview}
                          alt=""
                          className="size-full object-cover opacity-60"
                        />
                      )}
                      <div className="absolute inset-0 flex items-center justify-center">
                        {upload.progress === 'error' ? (
                          <span className="text-xs text-destructive font-medium">
                            {t('admin.products.media.upload_status_failed')}
                          </span>
                        ) : (
                          <Loader2Icon className="size-5 animate-spin text-muted-foreground" />
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </SortableContext>
            </DndContext>
          )}

          <button
            type="button"
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            className="flex w-full flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border p-6 text-center transition-colors hover:border-foreground/30 cursor-pointer"
            onClick={() => fileInputRef.current?.click()}
          >
            <ImagePlusIcon className="size-8 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">{t('admin.products.media.drop_hint')}</p>
            <p className="text-xs text-muted-foreground">
              {t('admin.products.media.file_types_hint')}
            </p>
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept={ACCEPTED_MEDIA.map((type) => (type.endsWith('/') ? `${type}*` : type)).join(
              ',',
            )}
            multiple
            className="hidden"
            onChange={(e) => e.target.files && handleFiles(e.target.files)}
          />

          <div className="flex flex-wrap gap-2 self-start">
            <Button type="button" variant="outline" onClick={() => setPickingFromLibrary(true)}>
              <LibraryIcon />
              {t('admin.products.media.add_from_library')}
            </Button>

            <Button type="button" variant="outline" onClick={() => setAddingVideo(true)}>
              <FilmIcon />
              {t('admin.products.media.add_video')}
            </Button>
          </div>
        </CardContent>
      </Card>
      <AddVideoDialog open={addingVideo} onOpenChange={setAddingVideo} onAdd={handleAddVideo} />
      <MediaPickerSheet<Media>
        open={pickingFromLibrary}
        onOpenChange={setPickingFromLibrary}
        queryKey="product-media-library"
        search={(query) =>
          adminClient.media.list({
            limit: 48,
            ...(query ? { filename_cont: query } : {}),
          })
        }
        onConfirm={handleAddFromLibrary}
      />
      {editingEntry && editingIndex !== null && (
        <MediaEditSheet
          form={form}
          mediaIndex={editingIndex}
          variants={variants ?? []}
          open
          onOpenChange={(open) => {
            if (!open) setEditingIndex(null)
          }}
        />
      )}
    </>
  )
}

function SortableMediaThumbnail({
  sortableId,
  previewUrl,
  alt,
  mediaType,
  downloadUrl,
  onEdit,
  onDelete,
}: {
  sortableId: string
  previewUrl: string | null
  alt: string
  mediaType: MediaType
  /** Absent until the row is saved — a pre-save upload has no server URL. */
  downloadUrl?: string | null
  onEdit: () => void
  onDelete: () => void
}) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: sortableId,
  })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  return (
    <ContextMenu>
      <ContextMenuTrigger
        render={
          // Clicking opens the edit sheet; dragging is the corner grip's job.
          // The whole tile being the drag surface left no way to click it.
          // biome-ignore lint/a11y/useSemanticElements: the grip inside rules out a <button>
          <div
            ref={setNodeRef}
            style={style}
            data-slot="media-thumbnail"
            role="button"
            tabIndex={0}
            onClick={onEdit}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault()
                onEdit()
              }
            }}
            className={`group relative aspect-square cursor-pointer bg-muted overflow-hidden rounded-md border border-border transition-colors hover:border-muted-foreground focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-offset-2 ${
              isDragging ? 'opacity-40 ring-2 ring-primary/40' : ''
            }`}
          />
        }
      >
        {previewUrl && mediaType === 'video' ? (
          // An uploaded video has no still until a poster is set, so its own
          // first frame stands in — an <img> would render a broken icon.
          <video
            src={previewUrl}
            muted
            playsInline
            preload="metadata"
            className="pointer-events-none size-full object-cover"
          />
        ) : previewUrl ? (
          <img
            src={previewUrl}
            alt={alt}
            draggable={false}
            className="pointer-events-none size-full object-cover"
          />
        ) : (
          <div className="flex size-full items-center justify-center text-muted-foreground">
            {mediaType === 'image' ? (
              <ImagePlusIcon className="size-6" />
            ) : (
              <FilmIcon className="size-6" />
            )}
          </div>
        )}

        {mediaType !== 'image' && (
          <span className="pointer-events-none absolute left-1.5 top-1.5 z-10 flex size-6 items-center justify-center rounded-full bg-black/60 text-white">
            <PlayIcon className="size-3 fill-current" />
          </span>
        )}

        <DragHandle
          attributes={attributes}
          listeners={listeners}
          // Stop the click reaching the tile behind it, or picking the grip up
          // would also open the sheet. touch-none lets a touch drag start
          // without the browser treating it as a scroll.
          onClick={(e) => e.stopPropagation()}
          className="absolute right-1.5 top-1.5 z-10 h-auto w-auto touch-none rounded-md bg-background/80 p-1 opacity-0 shadow-sm backdrop-blur transition-opacity group-hover:opacity-100 group-focus-within:opacity-100"
        />
      </ContextMenuTrigger>

      {/* Right-click is the way in here; clicking a tile drags it, and the
          edit sheet is reachable from this menu. */}
      <ContextMenuContent>
        <ContextMenuItem onClick={onEdit}>
          <PencilIcon />
          {t('admin.actions.edit')}
        </ContextMenuItem>
        {downloadUrl && (
          // The URL carries a Content-Disposition attachment header, so
          // navigating to it downloads rather than opening a page.
          <ContextMenuItem
            onClick={() => {
              window.location.href = downloadUrl
            }}
          >
            <DownloadIcon />
            {t('admin.media_library.download')}
          </ContextMenuItem>
        )}
        <ContextMenuSeparator />
        <ContextMenuItem variant="destructive" onClick={onDelete}>
          <TrashIcon />
          {t('admin.actions.delete')}
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  )
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

export function InventoryCard({ form, storeId }: FormCardProps & { storeId: string }) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_inventory')}</CardTitle>
      </CardHeader>
      <CardContent>
        <InventorySection form={form} storeId={storeId} />
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Custom Fields — edit-only placeholder ("save first")
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// SEO
// ---------------------------------------------------------------------------

export function SEOCard({ form, product }: FormCardProps & { product?: Product }) {
  const { t } = useTranslation()
  const slug = form.watch('slug')
  const metaTitle = form.watch('meta_title')
  const metaDescription = form.watch('meta_description')
  const name = form.watch('name')
  const { errors } = form.formState

  const previewTitle = metaTitle || product?.name || name || ''
  const previewSlug =
    slug || product?.slug || t('admin.pages.products.new.preview_slug_placeholder')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_seo')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="rounded-lg border border-border p-4 space-y-1">
          <p className="text-sm font-medium text-blue-700 truncate">{previewTitle}</p>
          <p className="text-xs text-green-700 truncate">example.com/products/{previewSlug}</p>
          {metaDescription && (
            <p className="text-xs text-muted-foreground line-clamp-2">{metaDescription}</p>
          )}
        </div>

        <Field>
          <FieldLabel htmlFor="product-slug">{t('admin.fields.slug.label')}</FieldLabel>
          <Input
            id="product-slug"
            placeholder={t('admin.products.seo.slug_placeholder')}
            aria-invalid={!!errors.slug || undefined}
            {...form.register('slug')}
          />
          <FieldError errors={[errors.slug]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="product-meta-title">{t('admin.fields.meta_title.label')}</FieldLabel>
          <Input
            id="product-meta-title"
            placeholder={t('admin.products.seo.meta_title_placeholder')}
            aria-invalid={!!errors.meta_title || undefined}
            {...form.register('meta_title')}
          />
          <FieldError errors={[errors.meta_title]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="product-meta-description">
            {t('admin.fields.meta_description.label')}
          </FieldLabel>
          <Textarea
            id="product-meta-description"
            rows={3}
            placeholder={t('admin.products.seo.meta_description_placeholder')}
            aria-invalid={!!errors.meta_description || undefined}
            {...form.register('meta_description')}
          />
          <FieldError errors={[errors.meta_description]} />
        </Field>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

export function StatusCard({ form }: FormCardProps) {
  const { t } = useTranslation()

  return (
    <SharedStatusCard<ProductFormValues>
      control={form.control as Control<ProductFormValues>}
      name="status"
      title={t('admin.fields.status.label')}
      label={t('admin.fields.status.label')}
      options={['draft', 'active', 'archived'].map((value) => ({
        value,
        label: t(`admin.pages.products.status_options.${value}`),
      }))}
    />
  )
}

// ---------------------------------------------------------------------------
// Categorization
// ---------------------------------------------------------------------------

export function CategorizationCard({ form }: FormCardProps) {
  const { t } = useTranslation()
  const { data: categoriesData } = useCategories()
  const { data: collectionsData } = useCollections()
  const { data: productTypesData } = useProductTypes()
  const productTypes = productTypesData?.data ?? []
  const { data: deliveryProfilesData } = useDeliveryProfiles()
  const deliveryProfiles = useMemo(() => deliveryProfilesData?.data ?? [], [deliveryProfilesData])
  // A product with no profile of its own ships on the store default, so the
  // select shows that rather than an empty trigger the merchant has to guess at.
  const defaultDeliveryProfileId = deliveryProfiles.find((profile) => profile.default)?.id
  const selectedProductTypeId = form.watch('product_type_id') as string | null | undefined
  const { data: selectedProductType } = useProductType(selectedProductTypeId ?? undefined)
  // Resolved by id: the type may reference option types beyond the first page
  // of the global list, which would otherwise drop out of the hint.
  const { data: typeOptionTypesData } = useOptionTypesByIds(selectedProductType?.option_type_ids)
  const optionTypes = useMemo(() => typeOptionTypesData?.data ?? [], [typeOptionTypesData])

  // The server seeds the type's categories onto the product when it is saved.
  // Prefilling them here means the merchant sees what they are about to get and
  // can still edit the list first. Additive, like the server: nothing they
  // already picked is removed.
  // Named rather than counted: on a product that already has variants the
  // builder won't surface these, so the name is the only signal the merchant
  // gets about what the type contributes.
  const typeOptionTypeNames = useMemo(() => {
    const ids = selectedProductType?.option_type_ids ?? []
    return ids
      .map((id) => optionTypes.find((optionType) => optionType.id === id))
      .filter((optionType) => optionType !== undefined)
      .map((optionType) => optionType.label ?? optionType.name ?? '')
      .filter(Boolean)
  }, [selectedProductType?.option_type_ids, optionTypes])

  useEffect(() => {
    const categoryIds = selectedProductType?.category_ids
    if (!categoryIds?.length) return

    const current = (form.getValues('category_ids') as string[] | undefined) ?? []
    const missing = categoryIds.filter((id) => !current.includes(id))
    if (missing.length === 0) return

    form.setValue('category_ids', [...current, ...missing], { shouldDirty: true })
  }, [selectedProductType, form])
  // Automatic collections rebuild their members from rules, so a hand-picked
  // membership would be dropped on the next regeneration — offer manual only.
  // Memoized: `initialItems` feeds a useEffect + useMemo inside
  // ResourceMultiAutocomplete, so a fresh array each render would re-run both
  // on every keystroke in the product form.
  const manualCollections = useMemo(
    () => collectionsData?.data.filter((collection) => !collection.automatic),
    [collectionsData],
  )
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_categorization')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>{t('admin.fields.product.product_type_id.label')}</FieldLabel>
          <Controller
            name="product_type_id"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value ?? ''} onValueChange={(v) => field.onChange(v || null)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder={t('admin.products.product_type_placeholder')}>
                    {(v) =>
                      productTypes.find((pt) => pt.id === v)?.name ??
                      t('admin.products.product_type_placeholder')
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {productTypes.map((productType) => (
                    <SelectItem key={productType.id} value={productType.id}>
                      {productType.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          <span className="text-muted-foreground text-xs">
            {t('admin.fields.product.product_type_id.help')}
          </span>
          {typeOptionTypeNames.length > 0 && (
            <span className="text-muted-foreground text-xs">
              {t('admin.products.product_type_adds_options', {
                options: typeOptionTypeNames.join(', '),
                count: typeOptionTypeNames.length,
              })}
            </span>
          )}
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.product.delivery_profile_id.label')}</FieldLabel>
          <Controller
            name="delivery_profile_id"
            control={form.control}
            render={({ field }) => (
              <Select
                value={field.value ?? defaultDeliveryProfileId ?? ''}
                onValueChange={(v) => field.onChange(v || null)}
              >
                <SelectTrigger className="w-full">
                  <SelectValue>
                    {(v) => deliveryProfiles.find((profile) => profile.id === v)?.name ?? ''}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {deliveryProfiles.map((profile) => (
                    <SelectItem key={profile.id} value={profile.id}>
                      {profile.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          <span className="text-muted-foreground text-xs">
            {t('admin.fields.product.delivery_profile_id.help')}
          </span>
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.product.category_ids.label')}</FieldLabel>
          <Controller
            name="category_ids"
            control={form.control}
            render={({ field }) => (
              <ResourceMultiAutocomplete
                {...categoryAutocompleteProps('product-edit-category-picker')}
                initialItems={categoriesData?.data}
                value={field.value ?? []}
                onChange={field.onChange}
              />
            )}
          />
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.product.collection_ids.label')}</FieldLabel>
          <Controller
            name="collection_ids"
            control={form.control}
            render={({ field }) => (
              <ResourceMultiAutocomplete
                {...collectionAutocompleteProps('product-edit-collection-picker')}
                initialItems={manualCollections}
                value={field.value ?? []}
                onChange={field.onChange}
              />
            )}
          />
          <span className="text-muted-foreground text-xs">
            {t('admin.fields.product.collection_ids.help')}
          </span>
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.product.tags.label')}</FieldLabel>
          <Controller
            name="tags"
            control={form.control}
            render={({ field }) => (
              <TagCombobox
                taggableType="Spree::Product"
                value={field.value ?? []}
                onChange={field.onChange}
              />
            )}
          />
        </Field>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Tax
// ---------------------------------------------------------------------------

export function TaxCard({ form }: FormCardProps) {
  const { t } = useTranslation()
  const { data: taxCategoriesResponse } = useTaxCategories()
  const taxCategories = taxCategoriesResponse?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.fields.tax.label')}</CardTitle>
      </CardHeader>
      <CardContent>
        <Field>
          <FieldLabel>{t('admin.fields.tax_category_id.label')}</FieldLabel>
          <Controller
            name="tax_category_id"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value ?? ''} onValueChange={(v) => field.onChange(v || null)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder={t('admin.products.tax_category_placeholder')}>
                    {(v) =>
                      taxCategories.find((c) => c.id === v)?.name ??
                      t('admin.products.tax_category_placeholder')
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {taxCategories.map((cat) => (
                    <SelectItem key={cat.id} value={cat.id}>
                      {cat.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </Field>
      </CardContent>
    </Card>
  )
}
