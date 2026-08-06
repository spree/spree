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
import type { ProductType } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  useCustomFieldDefinitions,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  cn,
  DragHandle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, XIcon } from 'lucide-react'
import { type CSSProperties, useEffect, useMemo } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { categoryAutocompleteProps } from '../../../../hooks/use-categories'
import { useFulfillmentProviders } from '../../../../hooks/use-delivery-methods'
import {
  useApplyProductTypeToProducts,
  useCreateProductType,
  useDeleteProductType,
  useProductType,
  useUpdateProductType,
} from '../../../../hooks/use-product-types'
import { FULFILLMENT_TYPES } from '../../../../schemas/delivery-method'
import '../../../../tables/product-types'

const productTypeFormSchema = z.object({
  name: z.string().min(1),
  fulfillment_types: z.array(z.string()).min(1),
  option_type_ids: z.array(z.string()),
  category_ids: z.array(z.string()),
  custom_field_definitions: z.array(
    z.object({
      id: z.string(),
      required: z.boolean(),
    }),
  ),
})

type ProductTypeFormValues = z.infer<typeof productTypeFormSchema>

const PRODUCT_TYPE_DEFAULTS: ProductTypeFormValues = {
  name: '',
  fulfillment_types: ['shipping'],
  option_type_ids: [],
  category_ids: [],
  custom_field_definitions: [],
}

/** Sort order is the row's index — never an input the merchant types. */
function withSortOrder(values: ProductTypeFormValues) {
  return {
    ...values,
    custom_field_definitions: values.custom_field_definitions.map((row, index) => ({
      ...row,
      sort_order: index,
    })),
  }
}

const productTypesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/product-types')({
  validateSearch: productTypesSearchSchema,
  component: ProductTypesPage,
})

function ProductTypesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof productTypesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteProductType()
  const { permissions } = usePermissions()

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

  useRowClickBridge('data-product-type-id', openEdit)

  async function handleDelete(productType: ProductType) {
    const ok = await confirm({
      title: t('admin.product_types.delete_confirm.title'),
      message: t('admin.product_types.delete_confirm.message', {
        name: productType.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(productType.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<ProductType>
        tableKey="product-types"
        queryKey="product-types"
        queryFn={(params) => adminClient.productTypes.list(params)}
        searchParams={search}
        rowActions={(productType) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(productType.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.ProductType),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(productType),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.ProductType}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.product_types.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateProductTypeSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditProductTypeSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateProductTypeSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateProductType()
  const form = useForm<ProductTypeFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productTypeFormSchema) as any,
    defaultValues: PRODUCT_TYPE_DEFAULTS,
  })

  async function onSubmit(values: ProductTypeFormValues) {
    try {
      await createMutation.mutateAsync(withSortOrder(values))
      form.reset(PRODUCT_TYPE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(PRODUCT_TYPE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.product_types.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.product_types.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <ProductTypeFormFields form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.product_types.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditProductTypeSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: productType, isLoading } = useProductType(id)
  const updateMutation = useUpdateProductType(id)

  const form = useForm<ProductTypeFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productTypeFormSchema) as any,
    defaultValues: PRODUCT_TYPE_DEFAULTS,
  })

  useEffect(() => {
    if (productType) {
      form.reset({
        name: productType.name,
        fulfillment_types: productType.fulfillment_types ?? ['shipping'],
        option_type_ids: productType.option_type_ids ?? [],
        category_ids: productType.category_ids ?? [],
        custom_field_definitions: (productType.custom_field_definitions ?? []).map(
          (definition) => ({
            id: definition.id,
            required: definition.required,
          }),
        ),
      })
    }
  }, [productType, form])

  async function onSubmit(values: ProductTypeFormValues) {
    try {
      await updateMutation.mutateAsync(withSortOrder(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{productType?.name ?? t('admin.product_types.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.product_types.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <ProductTypeFormFields form={form} />
              <ApplyToProductsSection id={id} productType={productType} />
            </div>
            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

/**
 * Type edits only shape products created from here on. This is the one action
 * that reaches back to products that already carry the type — additive, so it
 * never removes anything.
 */
function ApplyToProductsSection({
  id,
  productType,
}: {
  id: string
  productType: ProductType | undefined
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const applyMutation = useApplyProductTypeToProducts(id)
  const productsCount = productType?.products_count ?? 0

  async function handleApply() {
    const ok = await confirm({
      title: t('admin.product_types.apply_to_products.title'),
      message: t('admin.product_types.apply_to_products.message', { count: productsCount }),
      confirmLabel: t('admin.product_types.apply_to_products.confirm_label'),
    })
    if (!ok) return
    await applyMutation.mutateAsync().catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-2 rounded-md border border-dashed p-3">
      <span className="font-medium text-sm">{t('admin.product_types.affects_new_only.title')}</span>
      <span className="text-muted-foreground text-xs">
        {t('admin.product_types.affects_new_only.description')}
      </span>
      <Button
        type="button"
        variant="outline"
        size="sm"
        className="self-start"
        disabled={productsCount === 0 || applyMutation.isPending}
        onClick={handleApply}
      >
        {t('admin.product_types.apply_to_products.cta', { count: productsCount })}
      </Button>
    </div>
  )
}

function ProductTypeFormFields({ form }: { form: UseFormReturn<ProductTypeFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data: fulfillmentProviders } = useFulfillmentProviders()
  // Registry-driven: extension-registered types appear without a dashboard
  // change; the shipped const only covers the pre-fetch render.
  const registeredFulfillmentTypes = fulfillmentProviders?.fulfillment_types ?? FULFILLMENT_TYPES

  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}
      <Field>
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder={t('admin.fields.product_type.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.product_type.fulfillment_types.label')}</FieldLabel>
        <span className="text-muted-foreground text-xs">
          {t('admin.fields.product_type.fulfillment_types.help')}
        </span>
        <Controller
          name="fulfillment_types"
          control={form.control}
          render={({ field }) => (
            <div className="flex flex-col gap-2">
              {registeredFulfillmentTypes.map((fulfillmentType) => {
                const checked = field.value.includes(fulfillmentType)
                return (
                  <label
                    key={fulfillmentType}
                    htmlFor={`fulfillment-type-${fulfillmentType}`}
                    className="flex items-center gap-2 text-sm"
                  >
                    <Checkbox
                      id={`fulfillment-type-${fulfillmentType}`}
                      checked={checked}
                      onCheckedChange={(next) => {
                        field.onChange(
                          next
                            ? [...field.value, fulfillmentType]
                            : field.value.filter((value) => value !== fulfillmentType),
                        )
                      }}
                    />
                    {t(`admin.delivery_methods.fulfillment_types.${fulfillmentType}`, {
                      defaultValue: fulfillmentType,
                    })}
                  </label>
                )
              })}
            </div>
          )}
        />
        <FieldError errors={[errors.fulfillment_types]} />
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.product_type.option_types.label')}</FieldLabel>
        <span className="text-muted-foreground text-xs">
          {t('admin.fields.product_type.option_types.help')}
        </span>
        <Controller
          name="option_type_ids"
          control={form.control}
          render={({ field }) => (
            <ResourceMultiAutocomplete
              queryKey="product-type-option-types"
              value={field.value}
              onChange={field.onChange}
              search={(q) => adminClient.optionTypes.list({ name_cont: q, limit: 20 })}
              hydrate={(ids) => adminClient.optionTypes.list({ id_in: ids, limit: ids.length })}
              getOptionLabel={(optionType) => optionType.name ?? optionType.id}
              placeholder={t('admin.product_types.option_type_search_placeholder')}
              emptyText={t('admin.product_types.no_option_types')}
            />
          )}
        />
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.product_type.categories.label')}</FieldLabel>
        <span className="text-muted-foreground text-xs">
          {t('admin.fields.product_type.categories.help')}
        </span>
        <Controller
          name="category_ids"
          control={form.control}
          render={({ field }) => (
            <ResourceMultiAutocomplete
              {...categoryAutocompleteProps('product-type-categories')}
              value={field.value}
              onChange={field.onChange}
            />
          )}
        />
      </Field>

      <CustomFieldDefinitionsEditor form={form} />
    </FieldGroup>
  )
}

/**
 * Which custom fields a product of this type gets, in which order, and which
 * must be filled before it can be activated. Order is the row position — the
 * sort order is never typed in.
 */
function CustomFieldDefinitionsEditor({ form }: { form: UseFormReturn<ProductTypeFormValues> }) {
  const { t } = useTranslation()
  const { data: definitions } = useCustomFieldDefinitions('Spree::Product')
  const fieldArray = useFieldArray({ control: form.control, name: 'custom_field_definitions' })
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  // One index over the pool — this list re-renders on every drag frame.
  const definitionsById = useMemo(
    () => new Map((definitions?.data ?? []).map((definition) => [definition.id, definition])),
    [definitions?.data],
  )
  // `fieldArray.fields[].id` is React Hook Form's own row key, NOT our
  // definition id — it overwrites any `id` in the row value. Read the
  // definition ids from form state and keep the RHF key for React/dnd identity.
  const rows = (form.watch('custom_field_definitions') ??
    []) as ProductTypeFormValues['custom_field_definitions']
  const selectedIdSet = new Set(rows.map((row) => row.id))
  const available = [...definitionsById.values()].filter(
    (definition) => !selectedIdSet.has(definition.id),
  )
  const labelFor = (definitionId: string) => {
    const definition = definitionsById.get(definitionId)
    return definition?.label ?? definition?.key ?? definitionId
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return

    const from = fieldArray.fields.findIndex((row) => row.id === active.id)
    const to = fieldArray.fields.findIndex((row) => row.id === over.id)
    if (from >= 0 && to >= 0) fieldArray.move(from, to)
  }

  return (
    <Field>
      <FieldLabel>{t('admin.fields.product_type.custom_field_definitions.label')}</FieldLabel>
      <span className="text-muted-foreground text-xs">
        {t('admin.fields.product_type.custom_field_definitions.help')}
      </span>

      {fieldArray.fields.length > 0 && (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext
            items={fieldArray.fields.map((row) => row.id)}
            strategy={verticalListSortingStrategy}
          >
            <div className="flex flex-col gap-1 rounded-md border p-2">
              {fieldArray.fields.map((row, index) => (
                <SortableCustomFieldRow
                  key={row.id}
                  sortableId={row.id}
                  label={labelFor(rows[index]?.id ?? '')}
                  form={form}
                  index={index}
                  onRemove={() => fieldArray.remove(index)}
                />
              ))}
            </div>
          </SortableContext>
        </DndContext>
      )}

      {available.length > 0 && (
        <div className="flex flex-wrap gap-2 pt-2">
          {available.map((definition) => (
            <Button
              key={definition.id}
              type="button"
              variant="outline"
              size="sm"
              onClick={() => fieldArray.append({ id: definition.id, required: false })}
            >
              <PlusIcon className="size-3" />
              {definition.label ?? definition.key}
            </Button>
          ))}
        </div>
      )}
    </Field>
  )
}

function SortableCustomFieldRow({
  sortableId,
  label,
  form,
  index,
  onRemove,
}: {
  sortableId: string
  label: string
  form: UseFormReturn<ProductTypeFormValues>
  index: number
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: sortableId,
  })
  const style: CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        'flex items-center gap-2 rounded-md px-1 py-1.5 text-sm',
        isDragging && 'relative z-10 bg-card opacity-80 shadow-lg',
      )}
    >
      <span className="w-8 touch-none">
        <DragHandle attributes={attributes} listeners={listeners} />
      </span>

      <span className="flex-1 truncate">{label}</span>

      <Controller
        name={`custom_field_definitions.${index}.required` as const}
        control={form.control}
        render={({ field }) => (
          <label
            htmlFor={`cfdef-required-${sortableId}`}
            className="flex items-center gap-1.5 text-muted-foreground text-xs"
          >
            <Checkbox
              id={`cfdef-required-${sortableId}`}
              checked={field.value}
              onCheckedChange={(next) => field.onChange(!!next)}
            />
            {t('admin.fields.product_type.custom_field_definitions.required')}
          </label>
        )}
      />

      <Button type="button" variant="ghost" size="sm" onClick={onRemove}>
        <XIcon className="size-4" />
        <span className="sr-only">{t('admin.actions.remove')}</span>
      </Button>
    </div>
  )
}
