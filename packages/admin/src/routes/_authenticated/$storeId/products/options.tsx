import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { zodResolver } from '@hookform/resolvers/zod'
import type {
  OptionType,
  OptionTypeCreateParams,
  OptionValue,
  OptionValueParams,
} from '@spree/admin-sdk'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { ImageIcon, PlusIcon, Trash2Icon, UploadCloudIcon, XIcon } from 'lucide-react'
import { type CSSProperties, useEffect, useId, useRef, useState } from 'react'
import {
  type Control,
  Controller,
  type UseFormReturn,
  useFieldArray,
  useForm,
} from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { ColorPicker } from '@/components/spree/color-picker'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { DragHandle } from '@/components/spree/drag-handle'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/data-table'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Switch } from '@/components/ui/switch'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { useDirectUpload } from '@/hooks/use-direct-upload'
import {
  optionTypesQueryKey,
  useCreateOptionType,
  useDeleteOptionType,
  useOptionType,
  useUpdateOptionType,
} from '@/hooks/use-option-types'
import { Subject } from '@/lib/permissions'
import { cn } from '@/lib/utils'
import '@/tables/option-types'

const optionTypesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/options')({
  validateSearch: optionTypesSearchSchema,
  component: OptionTypesPage,
})

function OptionTypesPage() {
  const search = Route.useSearch() as z.infer<typeof optionTypesSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const editId = search.edit
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-option-type-id', openEdit)

  return (
    <>
      <ResourceTable<OptionType>
        tableKey="option-types"
        queryKey="option-types"
        queryFn={(params) => adminClient.optionTypes.list({ ...params, expand: ['option_values'] })}
        searchParams={search}
        actions={
          <Can I="create" a={Subject.OptionType}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              Add option type
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.optionTypes.update(id, { position })
            queryClient.invalidateQueries({ queryKey: optionTypesQueryKey })
          },
        }}
      />

      {isCreating && <CreateOptionTypeSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditOptionTypeSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

// ---------------------------------------------------------------------------
// Form schema
// ---------------------------------------------------------------------------

const KIND_OPTIONS = [
  { value: 'dropdown', label: 'Dropdown' },
  { value: 'color_swatch', label: 'Color swatch' },
  { value: 'buttons', label: 'Buttons' },
] as const

const HEX_RE = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/

const optionValueSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, 'Name is required'),
  label: z.string().min(1, 'Label is required'),
  color_code: z
    .string()
    .nullable()
    .optional()
    .refine((v) => !v || HEX_RE.test(v), 'Invalid hex color'),
  /** Active Storage signed_id from a fresh direct upload. Frontend-only state. */
  image_signed_id: z.string().nullable().optional(),
  /** Existing image URL (for preview only — never sent back). Frontend-only state. */
  image_url: z.string().nullable().optional(),
  /** True when the user clicks the trash icon next to an existing image. Frontend-only state. */
  image_cleared: z.boolean().optional(),
})

const formSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  label: z.string().min(1, 'Label is required'),
  kind: z.enum(['dropdown', 'color_swatch', 'buttons']),
  filterable: z.boolean(),
  option_values: z.array(optionValueSchema),
})

type FormValues = z.infer<typeof formSchema>
type OptionValueFormValue = z.infer<typeof optionValueSchema>

const DEFAULT_VALUES: FormValues = {
  name: '',
  label: '',
  kind: 'dropdown',
  filterable: false,
  option_values: [],
}

/**
 * Hydrate the form from an API option_value row. Spreads all API fields 1:1 and
 * attaches the frontend-only image upload-state fields (`image_signed_id`,
 * `image_cleared`) initialized to their resting values.
 */
function optionValueToFormRow(ov: OptionValue): OptionValueFormValue {
  return {
    ...ov,
    image_signed_id: null,
    image_cleared: false,
  }
}

/**
 * Build the API payload for a single option_value row. `index` is the row's
 * current array position; we send `position: index + 1` (1-indexed) so
 * `acts_as_list` persists the drag-reordered order. The frontend-only image
 * upload state collapses into the API's `image` field: a fresh signed_id is
 * sent, an explicit clear sends `null`, and an untouched row omits `image`
 * entirely so the existing attachment stays.
 */
function valueToParam(v: OptionValueFormValue, index: number): OptionValueParams {
  const { image_signed_id, image_url: _imageUrl, image_cleared, ...rest } = v
  return {
    ...rest,
    position: index + 1,
    ...(image_signed_id ? { image: image_signed_id } : image_cleared ? { image: null } : {}),
  }
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

function CreateOptionTypeSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const createMutation = useCreateOptionType()
  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: FormValues) {
    await createMutation.mutateAsync({
      ...values,
      option_values: values.option_values.map(valueToParam),
    } as OptionTypeCreateParams)
    form.reset(DEFAULT_VALUES)
    onOpenChange(false)
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_VALUES)
        onOpenChange(next)
      }}
    >
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>Add option type</SheetTitle>
          <SheetDescription>
            Option types group the choices a customer makes per variant — size, color, material.
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
            <OptionTypeFormFields form={form} />
            <OptionValuesFieldArray form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Creating…' : 'Create option type'}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Edit
// ---------------------------------------------------------------------------

function EditOptionTypeSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { data: optionType, isLoading } = useOptionType(id)
  const updateMutation = useUpdateOptionType(id)
  const deleteMutation = useDeleteOptionType()
  const confirm = useConfirm()

  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  useEffect(() => {
    if (optionType) {
      form.reset({
        ...optionType,
        kind: optionType.kind as FormValues['kind'],
        option_values: (optionType.option_values ?? []).map(optionValueToFormRow),
      })
    }
  }, [optionType, form])

  async function onSubmit(values: FormValues) {
    await updateMutation.mutateAsync({
      ...values,
      option_values: values.option_values.map(valueToParam),
    })
    // The sheet closes here; the `useOptionType` cache invalidation done by
    // the mutation hook re-hydrates the form via `useEffect` the next time
    // the sheet opens. Don't reset from the update response — the v3
    // serializer omits `option_values` when not expanded, and resetting with
    // `[]` flashes empty rows during the closing animation.
    onOpenChange(false)
  }

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete option type?',
      message: `${optionType?.name ?? 'This option type'} and its option values will be removed. Variants currently using it will lose those option assignments.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>{optionType?.name ?? 'Edit option type'}</SheetTitle>
          <SheetDescription>
            Update the option type and its values. Drag rows to reorder. Values omitted from this
            list will be removed.
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
              <OptionTypeFormFields form={form} />
              <OptionValuesFieldArray form={form} />
            </div>
            <SheetFooter>
              <Can I="destroy" a={Subject.OptionType}>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={onDelete}
                  disabled={form.formState.isSubmitting || deleteMutation.isPending}
                  className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
                >
                  Delete
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? 'Saving…' : 'Save'}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Top-level fields
// ---------------------------------------------------------------------------

function OptionTypeFormFields({
  form,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
}) {
  return (
    <FieldGroup>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor="label">Label</FieldLabel>
          <Input
            id="label"
            autoFocus
            placeholder="e.g. Shirt size"
            {...form.register('label')}
            aria-invalid={!!form.formState.errors.label}
          />
          <p className="text-xs text-muted-foreground">Shown to customers on the storefront.</p>
          {form.formState.errors.label && (
            <p className="text-sm text-destructive">{form.formState.errors.label.message}</p>
          )}
        </Field>

        <Field>
          <FieldLabel htmlFor="name">Internal name</FieldLabel>
          <Input
            id="name"
            placeholder="e.g. shirt-size"
            {...form.register('name')}
            aria-invalid={!!form.formState.errors.name}
          />
          <p className="text-xs text-muted-foreground">
            Lowercase identifier. Must be unique across the store.
          </p>
          {form.formState.errors.name && (
            <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
          )}
        </Field>
      </div>

      <Field>
        <FieldLabel htmlFor="kind">Kind</FieldLabel>
        <Controller
          name="kind"
          control={form.control}
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="kind">
                <SelectValue>
                  {(value) =>
                    KIND_OPTIONS.find((o) => o.value === value)?.label ?? (value as string)
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {KIND_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        <p className="text-xs text-muted-foreground">
          Controls how the option renders on the storefront. Color swatch shows a hex color; buttons
          show a thumbnail image.
        </p>
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="filterable" className="cursor-pointer">
              Filterable
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              Show this option as a filter in storefront product listings.
            </span>
          </div>
          <Controller
            name="filterable"
            control={form.control}
            render={({ field }) => (
              <Switch id="filterable" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>
    </FieldGroup>
  )
}

// ---------------------------------------------------------------------------
// Nested option_values — sortable table
// ---------------------------------------------------------------------------

function OptionValuesFieldArray({
  form,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
}) {
  const valuesArray = useFieldArray<FormValues, 'option_values', '_key'>({
    control: form.control as Control<FormValues>,
    name: 'option_values',
    keyName: '_key',
  })
  const kind = form.watch('kind') as FormValues['kind']
  const showColor = kind === 'color_swatch'
  const showImage = kind === 'color_swatch' || kind === 'buttons'

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const fromIndex = valuesArray.fields.findIndex((f) => f._key === active.id)
    const toIndex = valuesArray.fields.findIndex((f) => f._key === over.id)
    if (fromIndex === -1 || toIndex === -1) return
    valuesArray.move(fromIndex, toIndex)
  }

  const dataColCount = 2 + (showColor ? 1 : 0) + (showImage ? 1 : 0)
  // grip + data cols + delete
  const totalColCount = 1 + dataColCount + 1

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="flex flex-col">
          <h3 className="text-sm font-medium">Option values</h3>
          <p className="text-xs text-muted-foreground">
            The individual choices (e.g. Small, Medium, Large). Drag rows to reorder.
          </p>
        </div>
        {valuesArray.fields.length > 0 && (
          <span className="text-xs text-muted-foreground">
            {valuesArray.fields.length === 1 ? '1 value' : `${valuesArray.fields.length} values`}
          </span>
        )}
      </div>

      <div className="overflow-hidden rounded-md border border-border bg-card">
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext
            items={valuesArray.fields.map((f) => f._key)}
            strategy={verticalListSortingStrategy}
          >
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-8" aria-label="Reorder" />
                  <TableHead>Internal name</TableHead>
                  <TableHead>Label</TableHead>
                  {showColor && <TableHead>Color</TableHead>}
                  {showImage && <TableHead>Image</TableHead>}
                  <TableHead aria-label="Actions" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {valuesArray.fields.length === 0 && (
                  <TableRow>
                    <TableCell
                      colSpan={totalColCount}
                      className="py-6 text-center text-sm text-muted-foreground"
                    >
                      No values yet. Add one to get started.
                    </TableCell>
                  </TableRow>
                )}
                {valuesArray.fields.map((field, index) => (
                  <SortableOptionValueRow
                    key={field._key}
                    sortableId={field._key}
                    form={form}
                    index={index}
                    showColor={showColor}
                    showImage={showImage}
                    onRemove={() => valuesArray.remove(index)}
                  />
                ))}
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={totalColCount} className="p-0">
                    <button
                      type="button"
                      onClick={() =>
                        valuesArray.append({
                          name: '',
                          label: '',
                          color_code: null,
                          image_signed_id: null,
                          image_url: null,
                          image_cleared: false,
                        })
                      }
                      className="flex w-full items-center justify-center gap-2 px-3 py-3 text-sm font-medium text-foreground transition-colors hover:bg-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    >
                      <PlusIcon className="size-4" />
                      Add option value
                    </button>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </SortableContext>
        </DndContext>
      </div>
    </div>
  )
}

function SortableOptionValueRow({
  sortableId,
  form,
  index,
  showColor,
  showImage,
  onRemove,
}: {
  sortableId: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
  index: number
  showColor: boolean
  showImage: boolean
  onRemove: () => void
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: sortableId,
  })
  const style: CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  const errors = form.formState.errors?.option_values?.[index] as
    | Partial<Record<keyof OptionValueFormValue, { message?: string }>>
    | undefined

  return (
    <TableRow
      ref={setNodeRef}
      style={style}
      className={cn(isDragging && 'relative z-10 bg-card opacity-80 shadow-lg')}
    >
      <TableCell className="w-8 touch-none p-0">
        <DragHandle attributes={attributes} listeners={listeners} />
      </TableCell>

      <TableCell>
        <Input
          aria-label="Internal name"
          placeholder="e.g. small"
          {...form.register(`option_values.${index}.name` as const)}
          aria-invalid={!!errors?.name}
        />
        {errors?.name?.message && (
          <p className="mt-1 text-xs text-destructive">{errors.name.message}</p>
        )}
      </TableCell>

      <TableCell>
        <Input
          aria-label="Label"
          placeholder="e.g. Small"
          {...form.register(`option_values.${index}.label` as const)}
          aria-invalid={!!errors?.label}
        />
        {errors?.label?.message && (
          <p className="mt-1 text-xs text-destructive">{errors.label.message}</p>
        )}
      </TableCell>

      {showColor && (
        <TableCell>
          <Controller
            name={`option_values.${index}.color_code` as const}
            control={form.control}
            render={({ field }) => (
              <ColorPicker
                value={field.value as string | null | undefined}
                onChange={field.onChange}
                aria-invalid={!!errors?.color_code}
                compact
                panelAlign="end"
              />
            )}
          />
          {errors?.color_code?.message && (
            <p className="mt-1 text-xs text-destructive">{errors.color_code.message}</p>
          )}
        </TableCell>
      )}

      {showImage && (
        <TableCell>
          <OptionValueImageField form={form} index={index} />
        </TableCell>
      )}

      <TableCell className="w-10 text-right">
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          aria-label="Remove value"
          onPointerDown={(e) => e.stopPropagation()}
          onClick={onRemove}
          className="text-destructive hover:bg-destructive/10 hover:text-destructive"
        >
          <Trash2Icon className="size-4" />
        </Button>
      </TableCell>
    </TableRow>
  )
}

// ---------------------------------------------------------------------------
// Image upload — compact (table-cell sized) variant
// ---------------------------------------------------------------------------

function OptionValueImageField({
  form,
  index,
}: {
  form: UseFormReturn<FormValues>
  index: number
}) {
  const fileInputId = useId()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const directUpload = useDirectUpload()
  const [localPreview, setLocalPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [zoomOpen, setZoomOpen] = useState(false)
  // Track the latest blob URL so the unmount cleanup sees the current
  // value without forcing the effect to re-run (and re-create the closure)
  // on every replace.
  const localPreviewRef = useRef<string | null>(null)
  localPreviewRef.current = localPreview
  useEffect(() => {
    return () => {
      if (localPreviewRef.current) URL.revokeObjectURL(localPreviewRef.current)
    }
  }, [])

  const imageUrl = form.watch(`option_values.${index}.image_url`) as string | null | undefined
  const cleared = form.watch(`option_values.${index}.image_cleared`) as boolean | undefined

  const preview = localPreview ?? (cleared ? null : (imageUrl ?? null))

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const result = await directUpload.mutateAsync(file)
      if (localPreview) URL.revokeObjectURL(localPreview)
      setLocalPreview(result.previewUrl)
      form.setValue(`option_values.${index}.image_signed_id`, result.signedId, {
        shouldDirty: true,
      })
      form.setValue(`option_values.${index}.image_cleared`, false, { shouldDirty: true })
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Upload failed'
      toast.error(message)
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  function clear() {
    if (localPreview) {
      URL.revokeObjectURL(localPreview)
      setLocalPreview(null)
    }
    form.setValue(`option_values.${index}.image_signed_id`, null, { shouldDirty: true })
    form.setValue(`option_values.${index}.image_cleared`, true, { shouldDirty: true })
    setZoomOpen(false)
  }

  return (
    <div className="relative size-10">
      <button
        type="button"
        onPointerDown={(e) => e.stopPropagation()}
        onClick={() => (preview ? setZoomOpen(true) : fileInputRef.current?.click())}
        disabled={uploading}
        className={cn(
          'relative size-10 shrink-0 overflow-hidden rounded-md border border-border bg-muted',
          'transition-colors hover:border-foreground/30',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
          'disabled:cursor-not-allowed disabled:opacity-50',
          preview && 'cursor-zoom-in',
        )}
        aria-label={preview ? 'View image' : 'Upload image'}
      >
        {preview ? (
          <img src={preview} alt="" className="size-full object-cover" />
        ) : (
          <div className="flex size-full items-center justify-center text-muted-foreground">
            {uploading ? (
              <UploadCloudIcon className="size-4 animate-pulse" />
            ) : (
              <ImageIcon className="size-4" />
            )}
          </div>
        )}
      </button>
      <input
        ref={fileInputRef}
        id={fileInputId}
        type="file"
        accept="image/*"
        className="sr-only"
        onChange={onFileChange}
        disabled={uploading}
      />
      {preview && (
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              type="button"
              onPointerDown={(e) => e.stopPropagation()}
              onClick={clear}
              disabled={uploading}
              aria-label="Remove image"
              className={cn(
                'absolute -right-1.5 -top-1.5 flex size-4 items-center justify-center rounded-full',
                'border border-border bg-background text-muted-foreground shadow-xs',
                'transition-colors hover:bg-destructive hover:text-destructive-foreground hover:border-destructive',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                'disabled:cursor-not-allowed disabled:opacity-50',
              )}
            >
              <XIcon className="size-3" />
            </button>
          </TooltipTrigger>
          <TooltipContent>Remove image</TooltipContent>
        </Tooltip>
      )}
      {preview && (
        <Dialog open={zoomOpen} onOpenChange={setZoomOpen}>
          <DialogContent
            showCloseButton={true}
            // Full-viewport popup with no chrome so the bare image floats
            // on the backdrop and the surrounding area is dismissable.
            className="fixed inset-0 left-0 top-0 flex h-screen w-screen max-w-none translate-x-0 translate-y-0 items-center justify-center border-0 p-4 shadow-none sm:max-w-none"
            style={{ maxHeight: '100vh' }}
          >
            <img
              src={preview}
              alt=""
              className="block max-h-[90vh] max-w-[90vw] rounded-lg object-contain"
            />
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}
