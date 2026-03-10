import type { Image, Product } from '@spree/admin-sdk'
import { zodResolver } from '@hookform/resolvers/zod'
import { createFileRoute, Link, useRouter } from '@tanstack/react-router'
import {
  ArrowLeftIcon,
  ImagePlusIcon,
  Loader2Icon,
  SaveIcon,
  TrashIcon,
  XIcon,
} from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Controller, useForm, type UseFormReturn } from 'react-hook-form'
import { toast } from 'sonner'
import { StatusBadge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { DatePicker } from '@/components/ui/date-picker'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
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
import { RichTextEditor } from '@/components/ui/rich-text-editor'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { useDirectUpload } from '@/hooks/use-direct-upload'
import { useProduct, useUpdateProduct, useDeleteProduct } from '@/hooks/use-product'
import {
  useProductAssets,
  useCreateProductAsset,
  useDeleteProductAsset,
} from '@/hooks/use-product-assets'
import { useShippingCategories } from '@/hooks/use-shipping-categories'
import { useTaxCategories } from '@/hooks/use-tax-categories'
import { useCategories } from '@/hooks/use-categories'
import { productFormSchema, type ProductFormValues } from '@/schemas/product'

export const Route = createFileRoute('/_authenticated/products/$productId')({
  component: ProductDetailPage,
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function productToFormValues(product: Product): ProductFormValues {
  const master = product.master_variant

  return {
    name: product.name,
    description: product.description ?? '',
    status: (product.status as ProductFormValues['status']) ?? 'draft',
    make_active_at: product.make_active_at ?? null,
    available_on: product.available_on ?? null,
    discontinue_on: product.discontinue_on ?? null,
    category_ids: product.categories?.map((t) => t.id) ?? [],
    tags: product.tags ?? [],
    price: master?.price?.amount ? Number(master.price.amount) : undefined,
    compare_at_price: master?.original_price?.amount
      ? Number(master.original_price.amount)
      : null,
    cost_price: product.cost_price ? Number(product.cost_price) : null,
    sku: master?.sku ?? '',
    barcode: master?.barcode ?? '',
    track_inventory: master?.track_inventory ?? true,
    shipping_category_id: product.shipping_category_id ?? null,
    weight: master?.weight ?? null,
    height: master?.height ?? null,
    width: master?.width ?? null,
    depth: master?.depth ?? null,
    weight_unit: master?.weight_unit ?? null,
    dimensions_unit: master?.dimensions_unit ?? null,
    tax_category_id: product.tax_category_id ?? null,
    meta_title: product.meta_title ?? '',
    meta_description: product.meta_description ?? '',
    slug: product.slug ?? '',
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function ProductDetailPage() {
  const { productId } = Route.useParams()
  const { data: product, isLoading, error } = useProduct(productId)

  if (isLoading) return <ProductSkeleton />
  if (error || !product) {
    return <p className="text-destructive p-4">Failed to load product.</p>
  }

  return <ProductForm product={product} />
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

function ProductForm({ product }: { product: Product }) {
  const { productId } = Route.useParams()
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
    try {
      await updateProduct.mutateAsync({ id: productId, ...data })
      toast.success('Product saved')
    } catch {
      toast.error('Failed to save product')
    }
  }

  const handleDelete = async () => {
    if (!window.confirm('Are you sure you want to delete this product?')) return
    try {
      await deleteProduct.mutateAsync(productId)
      toast.success('Product deleted')
      await router.navigate({ to: '/products', search: { filters: [], columns: [] } })
    } catch {
      toast.error('Failed to delete product')
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link
          to="/products"
          search={{ filters: [], columns: [] }}
          className="inline-flex items-center justify-center rounded-lg p-1.5 text-muted-foreground hover:bg-gray-100 hover:text-foreground transition-colors"
        >
          <ArrowLeftIcon className="size-5" />
        </Link>

        <h1 className="text-2xl font-medium truncate">{product.name}</h1>
        <StatusBadge status={product.status} />

        <div className="ml-auto flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={handleDelete}
            disabled={deleteProduct.isPending}
          >
            <TrashIcon className="size-4" />
            Delete
          </Button>
          <Button
            type="submit"
            size="sm"
            disabled={updateProduct.isPending || !form.formState.isDirty}
          >
            {updateProduct.isPending ? (
              <Loader2Icon className="size-4 animate-spin" />
            ) : (
              <SaveIcon className="size-4" />
            )}
            Save
          </Button>
        </div>
      </div>

      {/* Two-column layout */}
      <div className="grid grid-cols-12 gap-6">
        {/* Left column */}
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <GeneralCard form={form} />
          <MediaCard productId={productId} />
          {!hasVariants && <PricingCard form={form} />}
          {!hasVariants && <InventoryCard form={form} />}
          <SEOCard form={form} product={product} />
        </div>

        {/* Right column */}
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <StatusCard form={form} />
          <CategorizationCard form={form} />
          <ShippingCard form={form} hasVariants={hasVariants} />
          <TaxCard form={form} />
        </div>
      </div>
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
        <div className="grid gap-2">
          <Label htmlFor="name">Name</Label>
          <Input id="name" placeholder="Product name" {...form.register('name')} />
          {form.formState.errors.name && (
            <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
          )}
        </div>

        <div className="grid gap-2">
          <Label>Description</Label>
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
        </div>
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

function MediaCard({ productId }: { productId: string }) {
  const { data: assetsResponse } = useProductAssets(productId)
  const createAsset = useCreateProductAsset(productId)
  const deleteAsset = useDeleteProductAsset(productId)
  const directUpload = useDirectUpload()
  const [pending, setPending] = useState<PendingUpload[]>([])
  const fileInputRef = useRef<HTMLInputElement>(null)

  const assets = assetsResponse?.data ?? []

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

          await createAsset.mutateAsync({
            signed_id: result.signedId,
            alt: file.name,
            position: assets.length + fileArray.indexOf(file) + 1,
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
    [directUpload, createAsset, assets.length],
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

  const handleDeleteAsset = async (assetId: string) => {
    try {
      await deleteAsset.mutateAsync(assetId)
      toast.success('Image deleted')
    } catch {
      toast.error('Failed to delete image')
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Media</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {/* Image grid */}
        {(assets.length > 0 || pending.length > 0) && (
          <div className="grid grid-cols-4 gap-3">
            {assets.map((asset) => (
              <MediaThumbnail
                key={asset.id}
                asset={asset as Image}
                onDelete={() => handleDeleteAsset(asset.id)}
              />
            ))}
            {pending.map((upload) => (
              <div
                key={upload.id}
                className="relative aspect-square overflow-hidden rounded-lg border border-gray-200 bg-gray-50"
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
                    <Loader2Icon className="size-5 animate-spin text-gray-500" />
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Drop zone */}
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          className="flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-200 p-6 text-center transition-colors hover:border-gray-300 cursor-pointer"
          onClick={() => fileInputRef.current?.click()}
          onKeyDown={(e) => e.key === 'Enter' && fileInputRef.current?.click()}
          role="button"
          tabIndex={0}
        >
          <ImagePlusIcon className="size-8 text-gray-400" />
          <p className="text-sm text-gray-600">
            Drag & drop images here, or click to browse
          </p>
          <p className="text-xs text-gray-400">PNG, JPG, WebP up to 10MB</p>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            className="hidden"
            onChange={(e) => e.target.files && handleFiles(e.target.files)}
          />
        </div>
      </CardContent>
    </Card>
  )
}

function MediaThumbnail({
  asset,
  onDelete,
}: {
  asset: Image
  onDelete: () => void
}) {
  const imageUrl = asset.small_url || asset.mini_url || asset.original_url

  return (
    <div className="group relative aspect-square overflow-hidden rounded-lg border border-gray-200 bg-gray-50">
      {imageUrl ? (
        <img src={imageUrl} alt={asset.alt ?? ''} className="size-full object-cover" />
      ) : (
        <div className="flex size-full items-center justify-center text-gray-400">
          <ImagePlusIcon className="size-6" />
        </div>
      )}
      <button
        type="button"
        onClick={onDelete}
        className="absolute top-1.5 right-1.5 hidden group-hover:inline-flex items-center justify-center rounded-md size-6 bg-white/90 text-gray-600 hover:text-destructive hover:bg-white shadow-sm transition-colors"
      >
        <XIcon className="size-3.5" />
      </button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Pricing
// ---------------------------------------------------------------------------

function PricingCard({ form }: FormCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Pricing</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="grid gap-2">
            <Label htmlFor="price">Price</Label>
            <Input
              id="price"
              type="number"
              step="0.01"
              min="0"
              placeholder="0.00"
              {...form.register('price')}
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="compare_at_price">Compare at price</Label>
            <Input
              id="compare_at_price"
              type="number"
              step="0.01"
              min="0"
              placeholder="0.00"
              {...form.register('compare_at_price')}
            />
            <p className="text-xs text-muted-foreground">
              Original price shown as strikethrough
            </p>
          </div>
        </div>
        <div className="grid gap-2 max-w-[50%]">
          <Label htmlFor="cost_price">Cost price</Label>
          <Input
            id="cost_price"
            type="number"
            step="0.01"
            min="0"
            placeholder="0.00"
            {...form.register('cost_price')}
          />
          <p className="text-xs text-muted-foreground">Not visible to customers</p>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

function InventoryCard({ form }: FormCardProps) {
  const trackInventory = form.watch('track_inventory')

  return (
    <Card>
      <CardHeader>
        <CardTitle>Inventory</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="grid gap-2">
            <Label htmlFor="sku">SKU</Label>
            <Input id="sku" placeholder="SKU-001" {...form.register('sku')} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="barcode">Barcode</Label>
            <Input id="barcode" placeholder="ISBN, UPC, GTIN..." {...form.register('barcode')} />
          </div>
        </div>

        <div className="flex items-center gap-3">
          <Controller
            name="track_inventory"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="track_inventory"
                checked={field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
          <Label htmlFor="track_inventory">Track inventory</Label>
        </div>

        {trackInventory && (
          <p className="text-sm text-muted-foreground">
            Stock levels are managed per stock location.
          </p>
        )}
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
        <div className="rounded-lg border border-gray-200 p-4 space-y-1">
          <p className="text-sm font-medium text-blue-700 truncate">
            {metaTitle || product.name}
          </p>
          <p className="text-xs text-green-700 truncate">
            example.com/products/{slug || product.slug}
          </p>
          {metaDescription && (
            <p className="text-xs text-muted-foreground line-clamp-2">{metaDescription}</p>
          )}
        </div>

        <div className="grid gap-2">
          <Label htmlFor="slug">URL handle</Label>
          <Input id="slug" placeholder="product-url-handle" {...form.register('slug')} />
        </div>

        <div className="grid gap-2">
          <Label htmlFor="meta_title">Meta title</Label>
          <Input id="meta_title" placeholder="SEO title" {...form.register('meta_title')} />
        </div>

        <div className="grid gap-2">
          <Label htmlFor="meta_description">Meta description</Label>
          <Textarea
            id="meta_description"
            placeholder="SEO description"
            rows={3}
            {...form.register('meta_description')}
          />
        </div>
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
        <div className="grid gap-2">
          <Label>Status</Label>
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
        </div>

        {status !== 'active' && (
          <div className="grid gap-2">
            <Label>Schedule activation</Label>
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
          </div>
        )}

        <div className="grid gap-2">
          <Label>Available on</Label>
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
        </div>

        <div className="grid gap-2">
          <Label>Discontinue on</Label>
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
        </div>
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
        <div className="grid gap-2">
          <Label>Categories</Label>
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
        </div>

        <div className="grid gap-2">
          <Label>Tags</Label>
          <Controller
            name="tags"
            control={form.control}
            render={({ field }) => (
              <TagCombobox
                value={field.value ?? []}
                onChange={field.onChange}
              />
            )}
          />
        </div>
      </CardContent>
    </Card>
  )
}

interface CategoryOption {
  id: string
  name: string
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

  return (
    <Combobox
      multiple
      value={value}
      onValueChange={onChange}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedValues: string[]) =>
            selectedValues.map((id) => (
              <ComboboxChip key={id}>
                {categories.find((c) => c.id === id)?.name ?? id}
              </ComboboxChip>
            ))
          }
        </ComboboxValue>
        <ComboboxChipsInput placeholder="Search categories..." />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxList>
          {categories.map((category) => (
            <ComboboxItem key={category.id} value={category.id}>
              {category.name}
            </ComboboxItem>
          ))}
          <ComboboxEmpty>No categories found</ComboboxEmpty>
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}

function TagCombobox({
  value,
  onChange,
}: {
  value: string[]
  onChange: (value: string[]) => void
}) {
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && inputValue.trim()) {
      e.preventDefault()
      const tag = inputValue.trim()
      if (!value.includes(tag)) {
        onChange([...value, tag])
      }
      setInputValue('')
    }
  }

  return (
    <Combobox
      multiple
      value={value}
      onValueChange={onChange}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedValues: string[]) =>
            selectedValues.map((tag) => (
              <ComboboxChip key={tag}>
                {tag}
              </ComboboxChip>
            ))
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder="Type to add tags..."
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
          onKeyDown={handleKeyDown}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxList>
          {value.map((tag) => (
            <ComboboxItem key={tag} value={tag}>
              {tag}
            </ComboboxItem>
          ))}
          {inputValue.trim() && !value.includes(inputValue.trim()) && (
            <ComboboxItem value={inputValue.trim()}>
              Create &ldquo;{inputValue.trim()}&rdquo;
            </ComboboxItem>
          )}
          <ComboboxEmpty>Type and press Enter to create a tag</ComboboxEmpty>
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}

// ---------------------------------------------------------------------------
// Shipping
// ---------------------------------------------------------------------------

function ShippingCard({ form, hasVariants }: FormCardProps & { hasVariants: boolean }) {
  const { data: shippingCategoriesResponse } = useShippingCategories()
  const shippingCategories = shippingCategoriesResponse?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>Shipping</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="grid gap-2">
          <Label>Shipping category</Label>
          <Controller
            name="shipping_category_id"
            control={form.control}
            render={({ field }) => (
              <Select value={field.value ?? ''} onValueChange={(v) => field.onChange(v || null)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Select shipping category" />
                </SelectTrigger>
                <SelectContent>
                  {shippingCategories.map((cat) => (
                    <SelectItem key={cat.id} value={cat.id}>
                      {cat.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </div>

        {!hasVariants && (
          <>
            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-2">
                <Label htmlFor="weight">Weight</Label>
                <Input
                  id="weight"
                  type="number"
                  step="any"
                  placeholder="0.0"
                  {...form.register('weight')}
                />
              </div>
              <div className="grid gap-2">
                <Label>Unit</Label>
                <Controller
                  name="weight_unit"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      value={field.value ?? ''}
                      onValueChange={(v) => field.onChange(v || null)}
                    >
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Unit" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="oz">oz</SelectItem>
                        <SelectItem value="lb">lb</SelectItem>
                        <SelectItem value="g">g</SelectItem>
                        <SelectItem value="kg">kg</SelectItem>
                      </SelectContent>
                    </Select>
                  )}
                />
              </div>
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div className="grid gap-2">
                <Label htmlFor="height">H</Label>
                <Input
                  id="height"
                  type="number"
                  step="any"
                  placeholder="0.0"
                  {...form.register('height')}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="width">W</Label>
                <Input
                  id="width"
                  type="number"
                  step="any"
                  placeholder="0.0"
                  {...form.register('width')}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="depth">D</Label>
                <Input
                  id="depth"
                  type="number"
                  step="any"
                  placeholder="0.0"
                  {...form.register('depth')}
                />
              </div>
            </div>

            <div className="grid gap-2">
              <Label>Dimensions unit</Label>
              <Controller
                name="dimensions_unit"
                control={form.control}
                render={({ field }) => (
                  <Select
                    value={field.value ?? ''}
                    onValueChange={(v) => field.onChange(v || null)}
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Unit" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="in">in</SelectItem>
                      <SelectItem value="ft">ft</SelectItem>
                      <SelectItem value="cm">cm</SelectItem>
                      <SelectItem value="mm">mm</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
            </div>
          </>
        )}
      </CardContent>
    </Card>
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
        <div className="grid gap-2">
          <Label>Tax category</Label>
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
        </div>
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
