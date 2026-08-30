import { zodResolver } from '@hookform/resolvers/zod'
import type { Catalog, CatalogAssignment, PriceList } from '@spree/admin-sdk'
import {
  adminClient,
  mapSpreeErrorsToForm,
  PageHeader,
  ResourceCombobox,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  ErrorState,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, TrashIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { DeferredProductMembershipCard } from '../../../../../components/spree/deferred-product-membership-card'
import { ProductMembershipStagingProvider } from '../../../../../components/spree/product-membership-staging'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import {
  useAssignCatalog,
  useCatalog,
  useCatalogProducts,
  useDeleteCatalog,
  useImportCatalogPriceListProducts,
  useSaveCatalog,
  useUnassignCatalog,
} from '../../../../../hooks/use-catalogs'
import { spreeJsonLinkResolver } from '../../../../../lib/json-link-resolver'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogFormSchema,
  catalogValuesToParams,
} from '../../../../../schemas/catalog'

/** One catalog: its assortment, pricing and the audiences that see it. */
export const Route = createFileRoute('/_authenticated/$storeId/products/catalogs/$catalogId')({
  component: CatalogDetailPage,
})

function CatalogDetailPage() {
  const { t } = useTranslation()
  const { catalogId } = Route.useParams()
  const { data: catalog, isLoading, error, refetch } = useCatalog(catalogId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !catalog) {
    return (
      <ErrorState
        title={t('admin.catalogs.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CatalogBody key={catalog.id} catalog={catalog} />
}

/**
 * The whole page is one form, saved from the header: catalog settings and
 * the staged assortment changes flush together, so removing a product is
 * not final until Save — the same model as the price list editor.
 * Assignments stay immediate (their dialog is its own explicit commit).
 */
function CatalogBody({ catalog }: { catalog: Catalog }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCatalog()
  const saveMutation = useSaveCatalog(catalog.id)

  const canEdit = permissions.can('update', Subject.Catalog)

  const form = useForm<CatalogFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(catalogFormSchema) as any,
    defaultValues: CATALOG_DEFAULTS,
  })

  // Hydrate (and re-baseline after save) from the source row, unless the
  // merchant has unsaved edits in flight: importing from the price list
  // refetches the catalog mid-edit, and an unguarded reset would drop both
  // the settings being typed and any staged product changes.
  useEffect(() => {
    if (form.formState.isDirty) return
    form.reset({
      name: catalog.name,
      active: catalog.active,
      price_list_id: catalog.price_list_id ?? '',
      staged_products: { adds: [], removes: [] },
    })
  }, [catalog, form])

  async function handleDelete() {
    await deleteMutation.mutateAsync(catalog.id)
    navigate({ to: '/$storeId/products/catalogs', params: { storeId } })
  }

  async function handleSave(values: CatalogFormValues) {
    try {
      await saveMutation.mutateAsync({
        attributes: catalogValuesToParams(values),
        addProductIds: values.staged_products.adds.map((product) => product.id),
        removeProductIds: values.staged_products.removes,
      })
      form.reset({ ...values, staged_products: { adds: [], removes: [] } })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <ProductMembershipStagingProvider form={form} name="staged_products">
      <form onSubmit={form.handleSubmit(handleSave)}>
        <ResourceLayout
          header={
            <PageHeader
              title={catalog.name}
              badges={
                catalog.active ? undefined : (
                  <Badge variant="secondary">{t('admin.common.inactive')}</Badge>
                )
              }
              backTo="products/catalogs"
              resource={{ id: catalog.id }}
              jsonPreview={{
                title: `Catalog ${catalog.name}`,
                fetch: () => adminClient.catalogs.get(catalog.id, { expand: ['assignments'] }),
                endpoint: `/api/v3/admin/catalogs/${catalog.id}`,
                resolveLink: spreeJsonLinkResolver(storeId),
              }}
              onDelete={permissions.can('destroy', Subject.Catalog) ? handleDelete : undefined}
              deleteLabel={t('admin.catalogs.detail.delete_label')}
              actions={
                canEdit ? (
                  <Button
                    type="submit"
                    disabled={form.formState.isSubmitting || !form.formState.isDirty}
                  >
                    {form.formState.isSubmitting
                      ? t('admin.actions.saving')
                      : t('admin.actions.save')}
                  </Button>
                ) : undefined
              }
            />
          }
          main={
            <>
              {form.formState.errors.root?.message && (
                <p
                  className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
                  role="alert"
                >
                  {form.formState.errors.root.message}
                </p>
              )}
              <DeferredProductMembershipCard
                parentId={catalog.id}
                storeId={storeId}
                canEdit={canEdit}
                useProducts={useCatalogProducts}
                translationNamespace="admin.catalogs"
              />
            </>
          }
          sidebar={
            <>
              <CatalogSettingsCard catalog={catalog} form={form} canEdit={canEdit} />
              <CatalogAssignmentsCard catalog={catalog} canEdit={canEdit} />
            </>
          }
        />
      </form>
    </ProductMembershipStagingProvider>
  )
}

function CatalogSettingsCard({
  catalog,
  form,
  canEdit,
}: {
  catalog: Catalog
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const importMutation = useImportCatalogPriceListProducts(catalog.id)

  const { errors } = form.formState

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.detail.settings')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="catalog-name">{t('admin.fields.name.label')}</FieldLabel>
            <Input
              id="catalog-name"
              disabled={!canEdit}
              aria-invalid={!!errors.name || undefined}
              {...form.register('name')}
            />
            <FieldError errors={[errors.name]} />
          </Field>

          <Field>
            <FieldLabel>{t('admin.fields.catalog.price_list.label')}</FieldLabel>
            <Controller
              control={form.control}
              name="price_list_id"
              render={({ field }) => (
                <ResourceCombobox<PriceList>
                  queryKey="catalog-price-lists"
                  // Only lists that are actually available: unowned ones,
                  // plus the one this catalog already holds. A list another
                  // catalog owns is refused server-side, so offering it
                  // would only produce a confusing error.
                  search={(q) =>
                    adminClient.priceLists.list({
                      name_cont: q,
                      catalog_id_null: true,
                      limit: 10,
                    })
                  }
                  hydrate={(ids) => adminClient.priceLists.list({ id_in: ids, limit: ids.length })}
                  getOptionLabel={(list) => list.name}
                  placeholder={t('admin.fields.catalog.price_list.placeholder')}
                  emptyText={t('admin.fields.catalog.price_list.empty')}
                  disabled={!canEdit}
                  value={field.value || undefined}
                  onChange={(id) => field.onChange(id ?? '')}
                />
              )}
            />
            <FieldDescription>{t('admin.fields.catalog.price_list.help')}</FieldDescription>
            {canEdit && catalog.price_list_id && (
              <div>
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={importMutation.isPending}
                  onClick={() => importMutation.mutate()}
                >
                  {importMutation.isPending
                    ? t('admin.actions.saving')
                    : t('admin.catalogs.import_from_price_list')}
                </Button>
              </div>
            )}
          </Field>

          <Controller
            control={form.control}
            name="active"
            render={({ field }) => (
              <label htmlFor="catalog-active" className="flex items-center gap-2 text-sm">
                <Checkbox
                  id="catalog-active"
                  checked={field.value}
                  onCheckedChange={field.onChange}
                  disabled={!canEdit}
                />
                {t('admin.fields.active.label')}
              </label>
            )}
          />
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

const ASSIGNABLE_TYPES = ['company', 'customer_group'] as const
type AssignableType = (typeof ASSIGNABLE_TYPES)[number]

function CatalogAssignmentsCard({ catalog, canEdit }: { catalog: Catalog; canEdit: boolean }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const unassignMutation = useUnassignCatalog(catalog.id)
  const [addOpen, setAddOpen] = useState(false)

  const assignments = catalog.assignments ?? []

  async function handleUnassign(assignment: CatalogAssignment) {
    const ok = await confirm({
      title: t('admin.catalogs.assignments.remove_confirm.title'),
      message: t('admin.catalogs.assignments.remove_confirm.message', {
        name: assignment.assignable_name ?? assignment.assignable_id,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await unassignMutation.mutateAsync(assignment.id).catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.assignments.title')}</CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" type="button" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.catalogs.assignments.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent>
        {assignments.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('admin.catalogs.assignments.empty')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {assignments.map((assignment) => (
              <div key={assignment.id} className="flex items-center justify-between gap-2">
                <span className="flex min-w-0 items-center gap-2">
                  <Badge variant="outline">
                    {t(`admin.catalogs.assignable_types.${assignment.assignable_type}`)}
                  </Badge>
                  <span className="truncate text-foreground text-sm">
                    {assignment.assignable_name ?? assignment.assignable_id}
                  </span>
                </span>
                {canEdit && (
                  <Button
                    variant="ghost"
                    size="icon-xs"
                    type="button"
                    onClick={() => handleUnassign(assignment)}
                    aria-label={t('admin.actions.delete')}
                  >
                    <TrashIcon className="size-4" />
                  </Button>
                )}
              </div>
            ))}
          </div>
        )}
      </CardContent>

      {addOpen && <AssignCatalogDialog catalogId={catalog.id} open onOpenChange={setAddOpen} />}
    </Card>
  )
}

interface AssignableOption {
  id: string
  name?: string | null
  email?: string | null
}

function assignableSearch(type: AssignableType) {
  switch (type) {
    case 'company':
      return {
        search: (q: string) => adminClient.companies.list({ name_cont: q, limit: 10 }),
        hydrate: (ids: string[]) => adminClient.companies.list({ id_in: ids, limit: ids.length }),
      }
    case 'customer_group':
      return {
        search: (q: string) => adminClient.customerGroups.list({ name_cont: q, limit: 10 }),
        hydrate: (ids: string[]) =>
          adminClient.customerGroups.list({ id_in: ids, limit: ids.length }),
      }
  }
}

function AssignCatalogDialog({
  catalogId,
  open,
  onOpenChange,
}: {
  catalogId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const assignMutation = useAssignCatalog(catalogId)
  const [assignableType, setAssignableType] = useState<AssignableType>('company')
  const [assignableId, setAssignableId] = useState('')

  const typeOptions = ASSIGNABLE_TYPES.map((type) => ({
    value: type,
    label: t(`admin.catalogs.assignable_types.${type}`),
  }))

  const { search, hydrate } = assignableSearch(assignableType)

  async function handleSubmit() {
    if (!assignableId) return
    await assignMutation
      .mutateAsync({ assignable_type: assignableType, assignable_id: assignableId })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.catalogs.assignments.add_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.catalogs.assignments.dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.catalogs.assignments.type_label')}</FieldLabel>
              <Select
                items={typeOptions}
                value={assignableType}
                onValueChange={(value) => {
                  setAssignableType(value as AssignableType)
                  setAssignableId('')
                }}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {typeOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel>{t('admin.catalogs.assignments.audience_label')}</FieldLabel>
              <ResourceCombobox<AssignableOption>
                key={assignableType}
                queryKey={`catalog-assignables-${assignableType}`}
                search={search}
                hydrate={hydrate}
                getOptionLabel={(option) => option.name ?? option.email ?? option.id}
                placeholder={t('admin.catalogs.assignments.audience_placeholder')}
                emptyText={t('admin.catalogs.assignments.audience_empty')}
                value={assignableId || undefined}
                onChange={(id) => setAssignableId(id ?? '')}
              />
              {assignableType === 'company' && (
                <FieldDescription>
                  {t('admin.catalogs.assignments.company_subtree_help')}
                </FieldDescription>
              )}
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={assignMutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={assignMutation.isPending || !assignableId}
            onClick={handleSubmit}
          >
            {assignMutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
