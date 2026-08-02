import { zodResolver } from '@hookform/resolvers/zod'
import type { ProductType } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
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
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
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
})

type ProductTypeFormValues = z.infer<typeof productTypeFormSchema>

const PRODUCT_TYPE_DEFAULTS: ProductTypeFormValues = {
  name: '',
  fulfillment_types: ['shipping'],
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
      await createMutation.mutateAsync(values)
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
      })
    }
  }, [productType, form])

  async function onSubmit(values: ProductTypeFormValues) {
    try {
      await updateMutation.mutateAsync(values)
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

function ProductTypeFormFields({ form }: { form: UseFormReturn<ProductTypeFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

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
              {FULFILLMENT_TYPES.map((fulfillmentType) => {
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
                    {t(`admin.delivery_methods.fulfillment_types.${fulfillmentType}`)}
                  </label>
                )
              })}
            </div>
          )}
        />
        <FieldError errors={[errors.fulfillment_types]} />
      </Field>
    </FieldGroup>
  )
}
