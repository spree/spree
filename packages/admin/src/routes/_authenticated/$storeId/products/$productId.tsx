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
import type { Media, Product, Variant } from '@spree/admin-sdk'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import { ImagePlusIcon, Loader2Icon, PencilIcon, TrashIcon } from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CustomFieldsCard } from '@/components/spree/custom-fields/custom-fields-card'
import { FormActions, useFormSubmitShortcut } from '@/components/spree/form-actions'
import { MetadataCard } from '@/components/spree/metadata/metadata-card'
import { PageHeader } from '@/components/spree/page-header'
import { InventorySection } from '@/components/spree/products/inventory-section'
import { MediaEditSheet } from '@/components/spree/products/media-edit-sheet'
import { ResourceLayout } from '@/components/spree/resource-layout'
import { ErrorState } from '@/components/spree/route-error-boundary'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { StatusBadge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from '@/components/ui/combobox'
import { DatePicker } from '@/components/ui/date-picker'
import { Field, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { RichTextEditor } from '@/components/ui/rich-text-editor'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { useCategories } from '@/hooks/use-categories'
import { useDirectUpload } from '@/hooks/use-direct-upload'
import { useDeleteProduct, useProduct, useUpdateProduct } from '@/hooks/use-product'
import {
  useCreateProductMedia,
  useDeleteProductMedia,
  useProductMedia,
  useUpdateProductMedia,
} from '@/hooks/use-product-media'
import { useTaxCategories } from '@/hooks/use-tax-categories'
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
    tags: product.tags?.map((t: any) => t.name ?? t) ?? [],
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
  const { productId } = Route.useParams()
  const { data: product, isLoading, error, refetch } = useProduct(productId)

  if (isLoading) return <ProductSkeleton />
  if (error || !product) {
    return (
      <ErrorState
        title="Failed to load product"
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
  const confirm = useConfirm()
  const { productId, storeId } = Route.useParams()
  const router = useRouter()
  const updateProduct = useUpdateProduct()
  const deleteProduct = useDeleteProduct()
  const hasVariants = (product.variant_count ?? 0) > 0

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
      toast.success('Product saved')
    } catch {
      toast.error('Failed to save product')
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const handleDelete = async () => {
    const confirmed = await confirm({
      message: 'Are you sure you want to delete this product?',
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!confirmed) return
    try {
      await deleteProduct.mutateAsync(productId)
      toast.success('Product deleted')
      await router.navigate({
        to: '/$storeId/products',
        params: { storeId },
        search: { filters: [], columns: [] },
      })
    } catch {
      toast.error('Failed to delete product')
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={product.name}
            backTo="products"
            badges={<StatusBadge status={product.status} />}
            actions={<FormActions form={form} saveLabel="Save product" />}
            resource={{ id: product.id }}
            onDelete={handleDelete}
            deleteLabel="Delete product"
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
  return (
    <Card>
      <CardHeader>
        <CardTitle>General</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel htmlFor="name">Name</FieldLabel>
          <Input id="name" placeholder="Product name" {...form.register('name')} />
          {form.formState.errors.name && (
            <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
          )}
        </Field>

        <Field>
          <FieldLabel>Description</FieldLabel>
          <Controller
            name="description"
            control={form.control}
            render={({ field }) => (
              <RichTextEditor
                value={field.value}
                onChange={field.onChange}
                placeholder="Write a product description..."
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
      message: 'Delete this media? This cannot be undone.',
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!confirmed) return

    try {
      await deleteMedia.mutateAsync(mediaId)
      toast.success('Media deleted')
    } catch {
      toast.error('Failed to delete media')
    }
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>Media</CardTitle>
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
            <p className="text-sm text-muted-foreground">
              Drag & drop media here, or click to browse
            </p>
            <p className="text-xs text-muted-foreground">PNG, JPG, WebP up to 10MB</p>
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
          aria-label="Edit media"
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
          aria-label="Delete image"
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
  return (
    <Card>
      <CardHeader>
        <CardTitle>Inventory</CardTitle>
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
  const slug = form.watch('slug')
  const metaTitle = form.watch('meta_title')
  const metaDescription = form.watch('meta_description')

  return (
    <Card>
      <CardHeader>
        <CardTitle>SEO</CardTitle>
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
          <FieldLabel htmlFor="slug">URL handle</FieldLabel>
          <Input id="slug" placeholder="product-url-handle" {...form.register('slug')} />
        </Field>

        <Field>
          <FieldLabel htmlFor="meta_title">Meta title</FieldLabel>
          <Input id="meta_title" placeholder="SEO title" {...form.register('meta_title')} />
        </Field>

        <Field>
          <FieldLabel htmlFor="meta_description">Meta description</FieldLabel>
          <Textarea
            id="meta_description"
            placeholder="SEO description"
            rows={3}
            {...form.register('meta_description')}
          />
        </Field>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

function StatusCard({ form }: FormCardProps) {
  const status = form.watch('status')

  return (
    <Card>
      <CardHeader>
        <CardTitle>Status</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>Status</FieldLabel>
          <Controller
            name="status"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="draft">Draft</SelectItem>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="archived">Archived</SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </Field>

        {status !== 'active' && (
          <Field>
            <FieldLabel>Schedule activation</FieldLabel>
            <Controller
              name="make_active_at"
              control={form.control}
              render={({ field }) => (
                <DatePicker
                  value={field.value}
                  onChange={field.onChange}
                  placeholder="Pick a date"
                  includeTime
                />
              )}
            />
          </Field>
        )}

        <Field>
          <FieldLabel>Available on</FieldLabel>
          <Controller
            name="available_on"
            control={form.control}
            render={({ field }) => (
              <DatePicker
                value={field.value}
                onChange={field.onChange}
                placeholder="Pick a date"
                includeTime
              />
            )}
          />
        </Field>

        <Field>
          <FieldLabel>Discontinue on</FieldLabel>
          <Controller
            name="discontinue_on"
            control={form.control}
            render={({ field }) => (
              <DatePicker
                value={field.value}
                onChange={field.onChange}
                placeholder="Pick a date"
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
  const { data: categoriesResponse } = useCategories()
  const categories = categoriesResponse?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>Categorization</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>Categories</FieldLabel>
          <Controller
            name="category_ids"
            control={form.control}
            render={({ field }) => (
              <CategoryCombobox
                categories={categories}
                value={field.value ?? []}
                onChange={field.onChange}
              />
            )}
          />
        </Field>

        <Field>
          <FieldLabel>Tags</FieldLabel>
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

interface CategoryOption {
  id: string
  name: string
  pretty_name: string
}

function CategoryCombobox({
  categories,
  value,
  onChange,
}: {
  categories: CategoryOption[]
  value: string[]
  onChange: (value: string[]) => void
}) {
  const anchorRef = useComboboxAnchor()

  // Convert string[] of IDs to CategoryOption[] for the combobox
  const selectedItems = useMemo(
    () =>
      value.map((id) => categories.find((c) => c.id === id)).filter(Boolean) as CategoryOption[],
    [value, categories],
  )

  const handleChange = useCallback(
    (items: CategoryOption[]) => onChange(items.map((c) => c.id)),
    [onChange],
  )

  return (
    <Combobox
      multiple
      items={categories}
      value={selectedItems}
      onValueChange={handleChange as any}
      itemToStringLabel={(c: any) => (c as CategoryOption).pretty_name}
      itemToStringValue={(c: any) => (c as CategoryOption).id}
      isItemEqualToValue={(a: any, b: any) => (a as CategoryOption).id === (b as CategoryOption).id}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selected: CategoryOption[]) =>
            selected.map((c) => <ComboboxChip key={c.id}>{c.pretty_name}</ComboboxChip>)
          }
        </ComboboxValue>
        <ComboboxChipsInput placeholder="Search categories..." />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>No categories found</ComboboxEmpty>
        <ComboboxList>
          {(category: CategoryOption) => (
            <ComboboxItem key={category.id} value={category}>
              {category.pretty_name}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}

// ---------------------------------------------------------------------------
// Tax
// ---------------------------------------------------------------------------

function TaxCard({ form }: FormCardProps) {
  const { data: taxCategoriesResponse } = useTaxCategories()
  const taxCategories = taxCategoriesResponse?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>Tax</CardTitle>
      </CardHeader>
      <CardContent>
        <Field>
          <FieldLabel>Tax category</FieldLabel>
          <Controller
            name="tax_category_id"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value ?? ''} onValueChange={(v) => field.onChange(v || null)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Select tax category" />
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
