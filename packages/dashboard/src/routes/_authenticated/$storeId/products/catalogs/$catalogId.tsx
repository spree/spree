import { zodResolver } from '@hookform/resolvers/zod'
import type { Catalog } from '@spree/admin-sdk'
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
  Textarea,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, TrashIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CatalogPricingFields } from '../../../../../components/spree/catalog-pricing-fields'
import {
  CatalogTermsCard,
  catalogTermColumns,
  stagedTermsHaveErrors,
  stagedTermsToParams,
  termsToFormValues,
} from '../../../../../components/spree/catalog-terms-card'
import { DeferredProductMembershipCard } from '../../../../../components/spree/deferred-product-membership-card'
import {
  ProductMembershipStagingProvider,
  useProductMembershipStaging,
} from '../../../../../components/spree/product-membership-staging'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import {
  useCatalog,
  useCatalogProducts,
  useCatalogProductTerms,
  useDeleteCatalog,
  useSaveCatalog,
} from '../../../../../hooks/use-catalogs'
import { spreeJsonLinkResolver } from '../../../../../lib/json-link-resolver'
import type { AssignmentEntry } from '../../../../../schemas/catalog'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogFormSchema,
  catalogPricingValues,
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
  const { data: productTermsData } = useCatalogProductTerms(catalog.id)
  const productTerms = useMemo(() => productTermsData?.data ?? [], [productTermsData])

  const canEdit = permissions.can('update', Subject.Catalog)

  // The mode as last saved, not as currently selected: switching away from
  // hand-entered prices has to clear them, and the warning has to know a
  // switch is what is about to happen.
  const savedPricingMode = catalogPricingValues(catalog.price_list).pricing_mode

  const form = useForm<CatalogFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(catalogFormSchema) as any,
    defaultValues: CATALOG_DEFAULTS,
  })

  // Hydrate (and re-baseline after save) from the source row, unless the
  // merchant has unsaved edits in flight: entering prices refetches the
  // catalog mid-edit, and an unguarded reset would drop both the settings
  // being typed and any staged product changes.
  useEffect(() => {
    if (form.formState.isDirty) return
    form.reset({
      name: catalog.name,
      description: catalog.description ?? '',
      active: catalog.active,
      minimum_order_quantity: catalog.minimum_order_quantity?.toString() ?? '',
      order_multiple: catalog.order_multiple?.toString() ?? '',
      assignments: (catalog.assignments ?? []).map((assignment) => ({
        id: assignment.id,
        assignable_type: assignment.assignable_type as AssignmentEntry['assignable_type'],
        assignable_id: assignment.assignable_id,
        assignable_name: assignment.assignable_name,
      })),
      order_minimums: (catalog.order_minimums ?? []).map((minimum) => ({
        id: minimum.id,
        currency: minimum.currency,
        amount: minimum.amount,
      })),
      ...catalogPricingValues(catalog.price_list),
      staged_products: { adds: [], removes: [] },
      staged_terms: termsToFormValues(productTerms),
    })
  }, [catalog, productTerms, form])

  async function handleDelete() {
    await deleteMutation.mutateAsync(catalog.id)
    navigate({ to: '/$storeId/products/catalogs', params: { storeId } })
  }

  async function handleSave(values: CatalogFormValues) {
    // Refused here rather than normalized away: an unusable cell would be
    // sent as null, which the API reads as "clear this override", so the
    // merchant's rule would disappear instead of being corrected.
    if (stagedTermsHaveErrors(values.staged_terms ?? {})) {
      form.setError('root', { message: t('admin.catalogs.terms.validation.fix_terms') })
      return
    }

    try {
      // A product on its way out takes its terms with it, so its cells are
      // dropped rather than sent — the save would otherwise re-create rows
      // the removal just cleared.
      const removed = new Set(values.staged_products.removes)
      const terms = Object.fromEntries(
        Object.entries(values.staged_terms ?? {}).filter(([productId]) => !removed.has(productId)),
      )

      await saveMutation.mutateAsync({
        attributes: catalogValuesToParams(values, savedPricingMode),
        addProductIds: values.staged_products.adds.map((product) => product.id),
        removeProductIds: values.staged_products.removes,
        productTerms: stagedTermsToParams(terms),
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
                fetch: () =>
                  adminClient.catalogs.get(catalog.id, {
                    expand: ['assignments', 'price_list', 'price_list.price_rules'],
                  }),
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
                // Quantity terms are stated per product, so they belong on
                // the rows the products are already on rather than in a
                // second list beside this one.
                extraColumns={catalogTermColumns({
                  form,
                  canEdit,
                  headers: {
                    // Short column headers — the card's own title already
                    // says these are quantity terms. The full names stay as
                    // the inputs' accessible labels.
                    minimum: t('admin.catalogs.terms.column_minimum'),
                    multiple: t('admin.catalogs.terms.column_multiple'),
                    minimumLabel: t('admin.fields.minimum_order_quantity.label'),
                    multipleLabel: t('admin.fields.order_multiple.label'),
                    minimumHelp: t('admin.catalogs.terms.help.minimum'),
                    multipleHelp: t('admin.catalogs.terms.help.multiple'),
                    invalid: t('admin.catalogs.terms.validation.positive_integer'),
                    mixed: t('admin.catalogs.terms.mixed'),
                    defaultHint: t('admin.catalogs.terms.inherits'),
                  },
                })}
              />
            </>
          }
          sidebar={
            <>
              <CatalogSettingsCard form={form} canEdit={canEdit} />
              <CatalogPricingCard catalog={catalog} form={form} canEdit={canEdit} />
              <CatalogTermsCard form={form} canEdit={canEdit} />
              <CatalogAssignmentsCard form={form} canEdit={canEdit} />
            </>
          }
        />
      </form>
    </ProductMembershipStagingProvider>
  )
}

/**
 * What the agreement pays. Its own card rather than a field on the settings
 * card: pricing is the consequential half of a catalog, and burying it under
 * the name reads as an afterthought.
 */
function CatalogPricingCard({
  catalog,
  form,
  canEdit,
}: {
  catalog: Catalog
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  // A product staged for removal still has its prices on the list until
  // Save, so the spreadsheet would invite pricing something on its way out.
  const { removes, dirty: stagedProducts } = useProductMembershipStaging()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.detail.pricing')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <CatalogPricingFields
            form={form}
            canEdit={canEdit}
            priceList={catalog.price_list}
            savedMode={catalogPricingValues(catalog.price_list).pricing_mode}
            excludeProductIds={removes}
            hasStagedProducts={stagedProducts}
          />
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

function CatalogSettingsCard({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()

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
            <FieldLabel htmlFor="catalog-description">
              {t('admin.fields.catalog.description.label')}
            </FieldLabel>
            <Textarea
              id="catalog-description"
              rows={3}
              disabled={!canEdit}
              placeholder={t('admin.fields.catalog.description.placeholder')}
              {...form.register('description')}
            />
            <FieldDescription>{t('admin.fields.catalog.description.help')}</FieldDescription>
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

function CatalogAssignmentsCard({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const assignments: AssignmentEntry[] = form.watch('assignments') ?? []

  function update(next: AssignmentEntry[]) {
    form.setValue('assignments', next, { shouldDirty: true })
  }

  // Removal needs no confirm: nothing is written until Save, and Discard
  // puts it back — the same reason the assortment rows drop theirs.
  function remove(index: number) {
    update(assignments.filter((_, i) => i !== index))
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
            {assignments.map((assignment, index) => (
              <div
                key={`${assignment.assignable_type}-${assignment.assignable_id}`}
                className="flex items-center justify-between gap-2"
              >
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
                    onClick={() => remove(index)}
                    aria-label={t('admin.actions.remove')}
                  >
                    <TrashIcon className="size-4" />
                  </Button>
                )}
              </div>
            ))}
          </div>
        )}
      </CardContent>

      {addOpen && (
        <AssignCatalogDialog
          open
          onOpenChange={setAddOpen}
          assigned={assignments}
          onAdd={(entry) => update([...assignments, entry])}
        />
      )}
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
  open,
  onOpenChange,
  assigned,
  onAdd,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Already staged, so the same audience cannot be added twice. */
  assigned: AssignmentEntry[]
  onAdd: (entry: AssignmentEntry) => void
}) {
  const { t } = useTranslation()
  const [assignableType, setAssignableType] = useState<AssignableType>('company')
  const [assignableId, setAssignableId] = useState('')
  const [assignableName, setAssignableName] = useState<string | null>(null)

  const typeOptions = ASSIGNABLE_TYPES.map((type) => ({
    value: type,
    label: t(`admin.catalogs.assignable_types.${type}`),
  }))

  const { search, hydrate } = assignableSearch(assignableType)

  const duplicate = assigned.some(
    (entry) => entry.assignable_type === assignableType && entry.assignable_id === assignableId,
  )

  function handleSubmit() {
    if (!assignableId || duplicate) return

    onAdd({
      assignable_type: assignableType,
      assignable_id: assignableId,
      assignable_name: assignableName,
    })
    onOpenChange(false)
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
                // The record, not just the id: a staged row has to render a
                // name before the assignment exists server-side.
                onChange={(id, record) => {
                  setAssignableId(id ?? '')
                  setAssignableName(record ? (record.name ?? record.email ?? null) : null)
                }}
              />
              {duplicate && (
                <FieldError>{t('admin.catalogs.assignments.already_assigned')}</FieldError>
              )}
              {assignableType === 'company' && (
                <FieldDescription>
                  {t('admin.catalogs.assignments.company_subtree_help')}
                </FieldDescription>
              )}
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" disabled={!assignableId || duplicate} onClick={handleSubmit}>
            {t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
