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
import { zodResolver } from '@hookform/resolvers/zod'
import { type Media, type Product, SpreeError, type Variant } from '@spree/admin-sdk'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldError,
  FieldLabel,
  FormActions,
  Input,
  MetadataCard,
  ResourceLayout,
  RichTextEditor,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  StatusBadge,
  Textarea,
  useConfirm,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import { ImagePlusIcon, Loader2Icon, PencilIcon, TrashIcon } from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { BulkPriceEditorDialog } from '@/components/spree/bulk-price-editor/bulk-price-editor-dialog'
import { CustomFieldsCard } from '@/components/spree/custom-fields/custom-fields-card'
import { PageHeader } from '@/components/spree/page-header'
import { InventorySection } from '@/components/spree/products/inventory-section'
import { MediaEditSheet } from '@/components/spree/products/media-edit-sheet'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { StoreDatePicker } from '@/components/spree/store-date-picker'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { categoryAutocompleteProps } from '@/hooks/use-categories'
import { useDirectUpload } from '@/hooks/use-direct-upload'
import { useDeleteProduct, useProduct, useUpdateProduct } from '@/hooks/use-product'
import {
  useCreateProductMedia,
  useDeleteProductMedia,
  useProductMedia,
  useUpdateProductMedia,
} from '@/hooks/use-product-media'
import { useTaxCategories } from '@/hooks/use-tax-categories'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { type ProductFormValues, productFormSchema } from '@/schemas/product'

// Purchasable attributes (sku, barcode, prices, weight, dimensions, stock,
// track_inventory) live on variants in API v3. The product form no longer
// exposes top-level master fields; see docs/plans/6.0-remove-master-variant.md.

export const Route = createFileRoute('/_authenticated/$storeId/products/$productId')({
  component: ProductDetailPage,
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function variantInventoryFromVariant(variant: Variant) {
  return {
    id: variant.id,
    sku: variant.sku ?? null,
    options_text: variant.options_text ?? null,
    stock_items: (variant.stock_items ?? []).map((si) => ({
      stock_location_id: si.stock_location_id ?? si.stock_location?.id ?? '',
      stock_location_name: si.stock_location?.name ?? 'Unknown location',
      count_on_hand: si.count_on_hand,
      backorderable: si.backorderable,
    })),
  }
}

function productToFormValues(product: Product): ProductFormValues {
  const hasVariants = (product.variant_count ?? 0) > 0
  const inventorySource = hasVariants
    ? (product.variants ?? [])
    : product.default_variant
      ? [product.default_variant]
      : []

  return {
    name: product.name,
    description: product.description ?? '',
    status: (product.status as ProductFormValues['status']) ?? 'draft',
    make_active_at: product.make_active_at ?? null,
    available_on: product.available_on ?? null,
    discontinue_on: product.discontinue_on ?? null,
    category_ids: product.categories?.map((t) => t.id) ?? [],
    tags: product.tags ?? [],
    tax_category_id: product.tax_category_id ?? null,
    meta_title: product.meta_title ?? '',
    meta_description: product.meta_description ?? '',
    slug: product.slug ?? '',
    variants_inventory: inventorySource.map(variantInventoryFromVariant),
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function ProductDetailPage() {
  const { t } = useTranslation()
  const { productId } = Route.useParams()
  const { data: product, isLoading, error, refetch } = useProduct(productId)

  if (isLoading) return <ProductSkeleton />
  if (error || !product) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_product')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <ProductForm product={product as Product} />
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

function ProductForm({ product }: { product: Product }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { productId, storeId } = Route.useParams()
  const router = useRouter()
  const updateProduct = useUpdateProduct()
  const deleteProduct = useDeleteProduct()
  const hasVariants = (product.variant_count ?? 0) > 0
  const [editPricesOpen, setEditPricesOpen] = useState(false)

  const form = useForm<ProductFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productFormSchema) as any,
    defaultValues: productToFormValues(product),
  })

  useEffect(() => {
    form.reset(productToFormValues(product))
  }, [product, form])

  const onSubmit = async (data: ProductFormValues) => {
    const { variants_inventory, ...rest } = data
    const payload: Record<string, unknown> = { ...rest }

    if (variants_inventory && variants_inventory.length > 0) {
      payload.variants = variants_inventory.map((v) => ({
        id: v.id,
        stock_items: v.stock_items.map((si) => ({
          stock_location_id: si.stock_location_id,
          count_on_hand: si.count_on_hand,
          backorderable: si.backorderable,
        })),
      }))
    }

    try {
      await updateProduct.mutateAsync({ id: productId, ...payload })
      toast.success(t('admin.messages.product_saved'))
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(t('admin.errors.failed_to_save'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const handleDelete = async () => {
    const confirmed = await confirm({
      message: t('admin.products.delete_confirm'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!confirmed) return
    try {
      await deleteProduct.mutateAsync(productId)
      toast.success(t('admin.messages.product_deleted'))
      await router.navigate({
        to: '/$storeId/products',
        params: { storeId },
        search: { filters: [], columns: [] },
      })
    } catch {
      toast.error(t('admin.errors.failed_to_delete'))
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      {form.formState.errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {form.formState.errors.root.message}
        </p>
      )}
      <ResourceLayout
        header={
          <PageHeader
            title={product.name}
            backTo="products"
            badges={<StatusBadge status={product.status} />}
            actions={
              <>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setEditPricesOpen(true)}
                >
                  {t('admin.pages.products.price_lists.edit_prices_cta')}
                </Button>
                <FormActions form={form} saveLabel={t('admin.products.save_label')} />
              </>
            }
            resource={{ id: product.id }}
            onDelete={handleDelete}
            deleteLabel={t('admin.products.delete_label')}
            jsonPreview={{
              title: `Product ${product.name}`,
              queryKey: ['json', 'product', productId],
              queryFn: () => adminClient.products.get(productId),
              endpoint: `/api/v3/admin/products/${productId}`,
            }}
          />
        }
        main={
          <>
            <GeneralCard form={form} />
            <MediaCard productId={productId} variants={product.variants ?? []} />
            <InventoryCard form={form} storeId={storeId} hasVariants={hasVariants} />
            <CustomFieldsCard
              ownerType="Spree::Product"
              ownerId={productId}
              resourceLabel="products"
            />
            <MetadataCard metadata={product.metadata} />
          </>
        }
        sidebar={
          <>
            <StatusCard form={form} />
            <CategorizationCard form={form} />
            <TaxCard form={form} />
            <SEOCard form={form} product={product} />
          </>
        }
      />
      <BulkPriceEditorDialog
        open={editPricesOpen}
        onOpenChange={setEditPricesOpen}
        scope={{ kind: 'product', product: { id: product.id, name: product.name } }}
      />
    </form>
  )
}

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type FormCardProps = {
  form: UseFormReturn<ProductFormValues, any, any>
}

// ---------------------------------------------------------------------------
// General
// ---------------------------------------------------------------------------

function GeneralCard({ form }: FormCardProps) {
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
          <FieldLabel>{t('admin.fields.description.label')}</FieldLabel>
          <Controller
            name="description"
            control={form.control}
            render={({ field }) => (
              <RichTextEditor
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
// Media
// ---------------------------------------------------------------------------

interface PendingUpload {
  id: string
  file: File
  preview: string
  progress: 'uploading' | 'attaching' | 'done' | 'error'
}

function MediaCard({ productId, variants }: { productId: string; variants: Variant[] }) {
  const { t } = useTranslation()
  const { data: mediaResponse } = useProductMedia(productId)
  const createMedia = useCreateProductMedia(productId)
  const updateMedia = useUpdateProductMedia(productId)
  const deleteMedia = useDeleteProductMedia(productId)
  const directUpload = useDirectUpload()
  const confirm = useConfirm()
  const [pending, setPending] = useState<PendingUpload[]>([])
  const [editingMediaId, setEditingMediaId] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const mediaItems = mediaResponse?.data ?? []
  const editingMedia = useMemo(
    () => mediaItems.find((m) => m.id === editingMediaId) ?? null,
    [mediaItems, editingMediaId],
  )

  // dnd-kit sensors: pointer for mouse/touch, keyboard for accessibility (Space
  // to grab, arrow keys to move, Space to drop). distance:5 prevents the grip
  // button from hijacking single clicks elsewhere on the thumbnail.
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  // dnd-kit gives us source + destination indices in the array; convert to a
  // 1-indexed position that acts_as_list on Spree::Asset can act on. Server
  // shifts siblings; we only PATCH the moved item.
  const handleDragEnd = useCallback(
    async (event: DragEndEvent) => {
      const { active, over } = event
      if (!over || active.id === over.id) return

      const fromIndex = mediaItems.findIndex((m) => m.id === active.id)
      const toIndex = mediaItems.findIndex((m) => m.id === over.id)
      if (fromIndex === -1 || toIndex === -1) return

      const newPosition = toIndex + 1
      try {
        await updateMedia.mutateAsync({ id: String(active.id), position: newPosition })
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Reorder failed'
        toast.error(message)
      }
    },
    [mediaItems, updateMedia],
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

          setPending((prev) =>
            prev.map((p) => (p.id === uploadId ? { ...p, progress: 'attaching' as const } : p)),
          )

          await createMedia.mutateAsync({
            signed_id: result.signedId,
            alt: file.name,
            position: mediaItems.length + fileArray.indexOf(file) + 1,
          })

          setPending((prev) => prev.filter((p) => p.id !== uploadId))
          URL.revokeObjectURL(preview)
        } catch (err) {
          console.error(`Upload failed for ${file.name}:`, err)
          setPending((prev) =>
            prev.map((p) => (p.id === uploadId ? { ...p, progress: 'error' as const } : p)),
          )
          const message = err instanceof Error ? err.message : 'Unknown error'
          toast.error(`Failed to upload ${file.name}: ${message}`)
        }
      }
    },
    [directUpload, createMedia, mediaItems.length],
  )

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      if (e.dataTransfer.files.length > 0) {
        handleFiles(e.dataTransfer.files)
      }
    },
    [handleFiles],
  )

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
  }, [])

  const handleDeleteMedia = async (mediaId: string) => {
    const confirmed = await confirm({
      message: t('admin.products.media.delete_confirm'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!confirmed) return

    try {
      await deleteMedia.mutateAsync(mediaId)
      toast.success(t('admin.common.deleted'))
    } catch {
      toast.error(t('admin.errors.failed_to_delete'))
    }
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.products.section_media')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {/* Media grid — sortable items first, pending uploads appended after */}
          {(mediaItems.length > 0 || pending.length > 0) && (
            <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
              <SortableContext items={mediaItems.map((m) => m.id)} strategy={rectSortingStrategy}>
                <div className="grid grid-cols-4 gap-3">
                  {mediaItems.map((mediaItem) => (
                    <SortableMediaThumbnail
                      key={mediaItem.id}
                      mediaItem={mediaItem as unknown as Media}
                      onEdit={() => setEditingMediaId(mediaItem.id)}
                      onDelete={() => handleDeleteMedia(mediaItem.id)}
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
                          <span className="text-xs text-destructive font-medium">Failed</span>
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

          {/* Drop zone */}
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
      <MediaEditSheet
        productId={productId}
        mediaItem={editingMedia as unknown as Media}
        variants={variants}
        open={!!editingMediaId}
        onOpenChange={(open) => {
          if (!open) setEditingMediaId(null)
        }}
      />
    </>
  )
}

function SortableMediaThumbnail({
  mediaItem,
  onEdit,
  onDelete,
}: {
  mediaItem: Media
  onEdit: () => void
  onDelete: () => void
}) {
  const { t } = useTranslation()
  // The whole thumbnail is the drag source — listeners/attributes attach to
  // the wrapper. PointerSensor's distance:5 on the parent DndContext lets
  // brief clicks on the action buttons fall through without starting a drag.
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: mediaItem.id,
  })
  const imageUrl = mediaItem.small_url || mediaItem.mini_url || mediaItem.original_url

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
      {imageUrl ? (
        <img
          src={imageUrl}
          alt={mediaItem.alt ?? ''}
          draggable={false}
          className="size-full object-cover transition-transform duration-300 ease-out group-hover:scale-105"
        />
      ) : (
        <div className="flex size-full items-center justify-center text-muted-foreground">
          <ImagePlusIcon className="size-6" />
        </div>
      )}

      <div className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-end gap-1 p-1.5 opacity-0 translate-y-1 transition-all duration-200 ease-out group-hover:pointer-events-auto group-hover:opacity-100 group-hover:translate-y-0 group-focus-within:pointer-events-auto group-focus-within:opacity-100 group-focus-within:translate-y-0">
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

function InventoryCard({
  form,
  storeId,
  hasVariants,
}: FormCardProps & { storeId: string; hasVariants: boolean }) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_inventory')}</CardTitle>
      </CardHeader>
      <CardContent>
        <InventorySection form={form} storeId={storeId} hasVariants={hasVariants} />
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// SEO
// ---------------------------------------------------------------------------

function SEOCard({ form, product }: FormCardProps & { product: Product }) {
  const { t } = useTranslation()
  const slug = form.watch('slug')
  const metaTitle = form.watch('meta_title')
  const metaDescription = form.watch('meta_description')
  const { errors } = form.formState

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_seo')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {/* Preview */}
        <div className="rounded-lg border border-border p-4 space-y-1">
          <p className="text-sm font-medium text-blue-700 truncate">{metaTitle || product.name}</p>
          <p className="text-xs text-green-700 truncate">
            example.com/products/{slug || product.slug}
          </p>
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

function StatusCard({ form }: FormCardProps) {
  const { t } = useTranslation()
  const status = form.watch('status')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_status')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>{t('admin.fields.status.label')}</FieldLabel>
          <Controller
            name="status"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="draft">
                    {t('admin.pages.products.status_options.draft')}
                  </SelectItem>
                  <SelectItem value="active">
                    {t('admin.pages.products.status_options.active')}
                  </SelectItem>
                  <SelectItem value="archived">
                    {t('admin.pages.products.status_options.archived')}
                  </SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </Field>

        {status !== 'active' && (
          <Field>
            <FieldLabel>{t('admin.fields.product.make_active_at.label')}</FieldLabel>
            <Controller
              name="make_active_at"
              control={form.control}
              render={({ field }) => (
                <StoreDatePicker
                  value={field.value}
                  onChange={field.onChange}
                  placeholder={t('admin.common.pick_date')}
                  includeTime
                />
              )}
            />
          </Field>
        )}

        <Field>
          <FieldLabel>{t('admin.fields.product.available_on.label')}</FieldLabel>
          <Controller
            name="available_on"
            control={form.control}
            render={({ field }) => (
              <StoreDatePicker
                value={field.value}
                onChange={field.onChange}
                placeholder={t('admin.common.pick_date')}
                includeTime
              />
            )}
          />
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.product.discontinue_on.label')}</FieldLabel>
          <Controller
            name="discontinue_on"
            control={form.control}
            render={({ field }) => (
              <StoreDatePicker
                value={field.value}
                onChange={field.onChange}
                placeholder={t('admin.common.pick_date')}
                includeTime
              />
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

function CategorizationCard({ form }: FormCardProps) {
  const { t } = useTranslation()

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

function TaxCard({ form }: FormCardProps) {
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
                  <SelectValue placeholder={t('admin.products.tax_category_placeholder')} />
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

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function ProductSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Skeleton className="size-8 rounded-lg" />
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-5 w-16 rounded-md" />
        <div className="ml-auto flex items-center gap-2">
          <Skeleton className="h-8 w-20 rounded-lg" />
          <Skeleton className="h-8 w-16 rounded-lg" />
        </div>
      </div>
      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <Skeleton className="h-72 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-52 w-full rounded-xl" />
        </div>
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <Skeleton className="h-56 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-52 w-full rounded-xl" />
          <Skeleton className="h-24 w-full rounded-xl" />
        </div>
      </div>
    </div>
  )
}
