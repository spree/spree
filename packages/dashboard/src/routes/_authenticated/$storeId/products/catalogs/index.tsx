import { zodResolver } from '@hookform/resolvers/zod'
import type { Catalog } from '@spree/admin-sdk'
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
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useCreateCatalog, useDeleteCatalog } from '../../../../../hooks/use-catalogs'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogFormSchema,
  catalogValuesToParams,
} from '../../../../../schemas/catalog'
import '../../../../../tables/catalogs'

const catalogsSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/catalogs/')({
  validateSearch: catalogsSearchSchema,
  component: CatalogsPage,
})

function CatalogsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof catalogsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCatalog()
  const { permissions } = usePermissions()

  const isCreating = !!search.new

  function openEdit(id: string) {
    navigate({
      to: '/$storeId/products/catalogs/$catalogId',
      params: { storeId, catalogId: id },
    })
  }

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  useRowClickBridge('data-catalog-id', openEdit)

  async function handleDelete(catalog: Catalog) {
    const ok = await confirm({
      title: t('admin.catalogs.delete_confirm.title'),
      message: t('admin.catalogs.delete_confirm.message', { name: catalog.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(catalog.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Catalog>
        tableKey="catalogs"
        queryKey="catalogs"
        queryFn={(params) => adminClient.catalogs.list(params)}
        searchParams={search}
        rowActions={(catalog) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(catalog.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Catalog),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(catalog),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Catalog}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.catalogs.add_cta')}
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.catalogs.update(id, { position })
          },
        }}
      />

      {isCreating && <CreateCatalogSheet open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateCatalogSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateCatalog()
  const form = useForm<CatalogFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(catalogFormSchema) as any,
    defaultValues: CATALOG_DEFAULTS,
  })

  // A new catalog has no assortment or audience yet, and both live on its
  // detail page — so that is where the merchant is headed.
  async function onSubmit(values: CatalogFormValues) {
    try {
      const catalog = await createMutation.mutateAsync(catalogValuesToParams(values))
      form.reset(CATALOG_DEFAULTS)
      onOpenChange(false)
      navigate({
        to: '/$storeId/products/catalogs/$catalogId',
        params: { storeId, catalogId: catalog.id },
      })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(CATALOG_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.catalogs.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.catalogs.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="catalog-name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="catalog-name"
                  autoFocus
                  placeholder={t('admin.fields.catalog.name.placeholder')}
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.catalogs.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
