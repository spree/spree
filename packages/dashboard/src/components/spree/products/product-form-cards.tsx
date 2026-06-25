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
import type { Product, Variant } from '@spree/admin-sdk'
import {
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
  Field,
  FieldError,
  FieldLabel,
  Input,
  RichTextEditor,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { ImagePlusIcon, Loader2Icon, PencilIcon, TrashIcon } from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Controller, type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { ProductBulkPriceEditor } from '@/components/spree/bulk-price-editor/product-bulk-price-editor'
import { InventorySection } from '@/components/spree/products/inventory-section'
import { MediaEditSheet } from '@/components/spree/products/media-edit-sheet'
import { VariantsSection } from '@/components/spree/products/variants-section'
import { categoryAutocompleteProps, useCategories } from '@/hooks/use-categories'
import { useDeleteProductMedia } from '@/hooks/use-product-media'
import { useTaxCategories } from '@/hooks/use-tax-categories'
import type { ProductFormValues } from '@/schemas/product'

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
              <RichTextEditor
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

export function VariantsCard({ form }: FormCardProps) {
  return <VariantsSection form={form} />
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
                previewUrl: preview,
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
          toast.error(t('admin.products.media.upload_failed', { name: file.name, message }))
        }
      }
    },
    [directUpload, form, t],
  )

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      if (e.dataTransfer.files.length > 0) handleFiles(e.dataTransfer.files)
    },
    [handleFiles],
  )

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
  }, [])

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
          toast.error(t('admin.errors.failed_to_delete'))
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
                      alt={media.alt ?? ''}
                      onEdit={() => setEditingIndex(index)}
                      onDelete={() => handleDelete(index)}
                    />
                  ))}
                  {pending.map((upload) => (
                    <div
                      key={upload.id}
                      className="relative aspect-square overflow-hidden rounded-lg border border-border bg-muted"
                    >
                      <img
                        src={upload.preview}
                        alt=""
                        className="size-full object-cover opacity-60"
                      />
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
            accept="image/*"
            multiple
            className="hidden"
            onChange={(e) => e.target.files && handleFiles(e.target.files)}
          />
        </CardContent>
      </Card>
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
  onEdit,
  onDelete,
}: {
  sortableId: string
  previewUrl: string | null
  alt: string
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
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      className={`group relative aspect-square cursor-grab overflow-hidden rounded-md border border-border bg-muted touch-none active:cursor-grabbing ${
        isDragging ? 'opacity-40 ring-2 ring-primary/40' : ''
      }`}
    >
      {previewUrl ? (
        <img
          src={previewUrl}
          alt={alt}
          draggable={false}
          className="pointer-events-none size-full object-cover"
        />
      ) : (
        <div className="flex size-full items-center justify-center text-muted-foreground">
          <ImagePlusIcon className="size-6" />
        </div>
      )}

      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-10 flex justify-end gap-1 p-1.5 opacity-0 translate-y-1 transition-all duration-200 ease-out group-hover:pointer-events-auto group-hover:opacity-100 group-hover:translate-y-0 group-focus-within:pointer-events-auto group-focus-within:opacity-100 group-focus-within:translate-y-0">
        <Button
          type="button"
          variant="outline"
          size="icon-sm"
          aria-label={t('admin.a11y.edit_media')}
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => {
            e.stopPropagation()
            onEdit()
          }}
          className="shadow-sm"
        >
          <PencilIcon />
        </Button>
        <Button
          type="button"
          variant="outline"
          size="icon-sm"
          aria-label={t('admin.a11y.delete_image')}
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => {
            e.stopPropagation()
            onDelete()
          }}
          className="shadow-sm hover:text-destructive"
        >
          <TrashIcon />
        </Button>
      </div>
    </div>
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
  const statusItems = [
    { value: 'draft', label: t('admin.pages.products.status_options.draft') },
    { value: 'active', label: t('admin.pages.products.status_options.active') },
    { value: 'archived', label: t('admin.pages.products.status_options.archived') },
  ]
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.fields.status.label')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>{t('admin.fields.status.label')}</FieldLabel>
          <Controller
            name="status"
            control={form.control}
            render={({ field }) => (
              <Select
                items={statusItems as never}
                value={field.value}
                onValueChange={field.onChange}
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {statusItems.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
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

// ---------------------------------------------------------------------------
// Categorization
// ---------------------------------------------------------------------------

export function CategorizationCard({ form }: FormCardProps) {
  const { t } = useTranslation()
  const { data: categoriesData } = useCategories()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_categorization')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
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
