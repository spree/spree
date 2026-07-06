import { zodResolver } from '@hookform/resolvers/zod'
import type { TaxCategory, TaxCategoryCreateParams } from '@spree/admin-sdk'
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
  Switch,
  Textarea,
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
  useCreateTaxCategory,
  useDeleteTaxCategory,
  useTaxCategory,
  useUpdateTaxCategory,
} from '../../../../hooks/use-tax-categories'
import {
  TAX_CATEGORY_DEFAULTS,
  type TaxCategoryFormValues,
  taxCategoryFormSchema,
  taxCategoryValuesToParams,
} from '../../../../schemas/tax-category'
import '../../../../tables/tax-categories'

const taxCategoriesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/tax-categories')({
  validateSearch: taxCategoriesSearchSchema,
  component: TaxCategoriesPage,
})

function TaxCategoriesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof taxCategoriesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteTaxCategory()
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

  useRowClickBridge('data-tax-category-id', openEdit)

  async function handleDelete(taxCategory: TaxCategory) {
    const ok = await confirm({
      title: t('admin.tax_categories.delete_confirm.title'),
      message: t('admin.tax_categories.delete_confirm.message', {
        name: taxCategory.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(taxCategory.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<TaxCategory>
        tableKey="tax-categories"
        queryKey="tax-categories"
        queryFn={(params) => adminClient.taxCategories.list(params)}
        searchParams={search}
        rowActions={(taxCategory) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(taxCategory.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.TaxCategory),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(taxCategory),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.TaxCategory}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.tax_categories.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateTaxCategorySheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditTaxCategorySheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateTaxCategorySheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateTaxCategory()
  const form = useForm<TaxCategoryFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxCategoryFormSchema) as any,
    defaultValues: TAX_CATEGORY_DEFAULTS,
  })

  async function onSubmit(values: TaxCategoryFormValues) {
    try {
      await createMutation.mutateAsync(taxCategoryValuesToParams(values) as TaxCategoryCreateParams)
      form.reset(TAX_CATEGORY_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(TAX_CATEGORY_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.tax_categories.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.tax_categories.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <TaxCategoryFormFields form={form} />
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
                : t('admin.tax_categories.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditTaxCategorySheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: taxCategory, isLoading } = useTaxCategory(id)
  const updateMutation = useUpdateTaxCategory(id)

  const form = useForm<TaxCategoryFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxCategoryFormSchema) as any,
    defaultValues: TAX_CATEGORY_DEFAULTS,
  })

  useEffect(() => {
    if (taxCategory) {
      form.reset({
        name: taxCategory.name,
        tax_code: taxCategory.tax_code ?? '',
        description: taxCategory.description ?? '',
        is_default: taxCategory.is_default,
      })
    }
  }, [taxCategory, form])

  async function onSubmit(values: TaxCategoryFormValues) {
    try {
      await updateMutation.mutateAsync(taxCategoryValuesToParams(values))
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
          <SheetTitle>
            {taxCategory?.name ?? t('admin.pages.settings.tax_categories.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.tax_categories.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <TaxCategoryFormFields form={form} />
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

function TaxCategoryFormFields({ form }: { form: UseFormReturn<TaxCategoryFormValues> }) {
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
          placeholder={t('admin.fields.tax_category.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="tax_code">{t('admin.fields.tax_category.tax_code.label')}</FieldLabel>
        <Input
          id="tax_code"
          placeholder={t('admin.fields.tax_category.tax_code.placeholder')}
          aria-invalid={!!errors.tax_code || undefined}
          {...form.register('tax_code')}
        />
        <FieldError errors={[errors.tax_code]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="description">{t('admin.fields.description.label')}</FieldLabel>
        <Textarea
          id="description"
          rows={3}
          placeholder={t('admin.fields.tax_category.description.placeholder')}
          aria-invalid={!!errors.description || undefined}
          {...form.register('description')}
        />
        <FieldError errors={[errors.description]} />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="is_default" className="cursor-pointer">
              {t('admin.fields.tax_category.is_default.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.tax_category.is_default.help')}
            </span>
          </div>
          <Controller
            name="is_default"
            control={form.control}
            render={({ field }) => (
              <Switch id="is_default" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>
    </FieldGroup>
  )
}
