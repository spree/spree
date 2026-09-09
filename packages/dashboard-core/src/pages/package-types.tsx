import { zodResolver } from '@hookform/resolvers/zod'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import type { PanelPackageType } from '../api-client'
import { Can } from '../components/can'
import { ResourceTable, resourceSearchSchema } from '../components/resource-table'
import {
  canDeletePackageTypes,
  canWritePackageTypes,
  listPackageTypes,
  useCreatePackageType,
  useDeletePackageType,
  usePackageType,
  useUpdatePackageType,
} from '../hooks/use-package-types'
import { mapSpreeErrorsToForm } from '../lib/form-errors'
import { Subject } from '../lib/permissions'
import { usePermissions } from '../providers/permission-provider'
import {
  PACKAGE_DIMENSION_UNITS,
  PACKAGE_TYPE_DEFAULTS,
  PACKAGE_TYPE_KINDS,
  PACKAGE_WEIGHT_UNITS,
  type PackageTypeFormValues,
  packageTypeFormSchema,
  packageTypeFormValuesToParams,
  packageTypeToFormValues,
} from '../schemas/package-type'
import '../tables/package-types'

/**
 * Adds `?edit=<id>` and `?new=1` on top of the standard table search schema,
 * so the create and edit sheets can be deep-linked.
 *
 * Exported because each app owns its own route file — the route path differs
 * per panel (`/$storeId/settings/...` against `/$sellerId/settings/...`) and
 * TanStack's file routes are generated per app — while everything the page
 * *does* lives here.
 */
export const packageTypesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export type PackageTypesSearch = z.infer<typeof packageTypesSearchSchema>

/**
 * Manage the packaging this panel can see: the boxes parcels ship in, the
 * cartons products are packed into, the pallets a wholesale order leaves on.
 *
 * Shared by the operator's dashboard and the marketplace seller panel. The
 * scoping is server-side — the operator's API answers with every row in the
 * store and a seller's with their own plus the marketplace's shared
 * vocabulary — so this page renders whatever it is given
 * (docs/plans/6.0-seller-package-types.md).
 *
 * One row can be listed but not written: a seller sees the marketplace's
 * packaging so they know what they may pack into, and it reports
 * `editable: false`. The operator's serializer carries no such field because
 * every row there is theirs, so an absent flag reads as editable.
 */
function noop() {}

export function PackageTypesPage({ search }: { search: PackageTypesSearch }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeletePackageType()
  const { permissions } = usePermissions()

  // A panel may register `packageTypes.list` alone for the variant editor's
  // carton picker. Reading it here keeps this page honest on such a panel:
  // no add button, no row actions, and no sheet whose save could not work.
  const writable = canWritePackageTypes()

  // Neither sheet opens on a read-only panel. No mutual exclusion needed:
  // openCreate strips `edit` and openEdit strips `new`, so a link can only
  // carry one.
  const isCreating = writable && !!search.new
  const editId = writable ? search.edit : undefined

  function closeSheet() {
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })
  }

  function openCreate() {
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, ...rest } = prev
        return { ...rest, new: true } as never
      },
    })
  }

  function openEdit(id: string) {
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return { ...rest, edit: id } as never
      },
    })
  }

  // Guarded on `writable` as well: on a read-only panel no sheet can open, so
  // a click would only push an `edit` param nothing consumes or clears.
  useRowClickBridge('data-package-type-id', writable ? openEdit : noop)

  async function handleDelete(packageType: PanelPackageType) {
    const ok = await confirm({
      title: t('admin.package_types.delete_confirm.title'),
      message: t('admin.package_types.delete_confirm.message', { name: packageType.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(packageType.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<PanelPackageType>
        tableKey="package-types"
        queryKey="package-types"
        queryFn={listPackageTypes}
        searchParams={search}
        rowActions={(packageType) => {
          // A marketplace row in a seller's list is read-only, so it gets no
          // actions at all rather than actions that 404 on click. Same for
          // every row when this panel's client registered reads only.
          if (packageType.editable === false || !writable) return null

          return (
            <RowActions
              actions={[
                {
                  key: 'edit',
                  visible: permissions.can('update', Subject.PackageType),
                  onSelect: () => openEdit(packageType.id),
                },
                {
                  key: 'delete',
                  destructive: true,
                  visible:
                    canDeletePackageTypes() && permissions.can('destroy', Subject.PackageType),
                  disabled: deleteMutation.isPending,
                  onSelect: () => handleDelete(packageType),
                },
              ]}
            />
          )
        }}
        actions={
          writable ? (
            <Can I="create" a={Subject.PackageType}>
              <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
                <PlusIcon className="size-4" />
                {t('admin.package_types.add_cta')}
              </Button>
            </Can>
          ) : null
        }
      />

      {isCreating && <CreatePackageTypeSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditPackageTypeSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreatePackageTypeSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreatePackageType()
  const form = useForm<PackageTypeFormValues>({
    resolver: zodResolver(packageTypeFormSchema),
    defaultValues: PACKAGE_TYPE_DEFAULTS,
  })

  async function onSubmit(values: PackageTypeFormValues) {
    try {
      await createMutation.mutateAsync(packageTypeFormValuesToParams(values))
      form.reset(PACKAGE_TYPE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(PACKAGE_TYPE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.package_types.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.package_types.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <PackageTypeFormFields form={form} />
          </div>
          <SheetFooter>
            <Button type="submit" disabled={createMutation.isPending}>
              {t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditPackageTypeSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: packageType } = usePackageType(id)
  const updateMutation = useUpdatePackageType(id)
  // A pasted link can name a row this panel may read but not write — the
  // marketplace's packaging in a seller's panel. Closing rather than
  // rendering a form whose save could only 404.
  const readOnly = packageType?.editable === false
  const form = useForm<PackageTypeFormValues>({
    resolver: zodResolver(packageTypeFormSchema),
    defaultValues: PACKAGE_TYPE_DEFAULTS,
    values: packageType ? packageTypeToFormValues(packageType) : undefined,
  })

  async function onSubmit(values: PackageTypeFormValues) {
    try {
      await updateMutation.mutateAsync(packageTypeFormValuesToParams(values))
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  useEffect(() => {
    if (readOnly) onOpenChange(false)
  }, [readOnly, onOpenChange])

  if (readOnly) return null

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{packageType?.name ?? t('admin.package_types.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.package_types.edit_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <PackageTypeFormFields form={form} />
          </div>
          <SheetFooter>
            <Button type="submit" disabled={updateMutation.isPending}>
              {t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function PackageTypeFormFields({ form }: { form: UseFormReturn<PackageTypeFormValues> }) {
  const { t } = useTranslation()
  const errors = form.formState.errors

  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="package-type-name">
          {t('admin.fields.package_type.name.label')}
        </FieldLabel>
        <Input id="package-type-name" {...form.register('name')} aria-invalid={!!errors.name} />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="package-type-kind">
          {t('admin.fields.package_type.kind.label')}
        </FieldLabel>
        <Controller
          control={form.control}
          name="kind"
          render={({ field }) => {
            const options = PACKAGE_TYPE_KINDS.map((kind) => ({
              value: kind,
              label: t(`admin.package_types.kinds.${kind}`),
            }))
            return (
              <Select items={options} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id="package-type-kind">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {options.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )
          }}
        />
        <FieldDescription>{t('admin.fields.package_type.kind.help')}</FieldDescription>
      </Field>

      <div className="grid grid-cols-[1fr_1fr_1fr_110px] gap-3">
        {(['length', 'width', 'height'] as const).map((side) => (
          <Field key={side}>
            <FieldLabel htmlFor={`package-type-${side}`}>
              {t(`admin.fields.package_type.${side}.label`)}
            </FieldLabel>
            <Input
              id={`package-type-${side}`}
              type="number"
              min="0"
              step="0.01"
              aria-invalid={!!errors[side]}
              {...form.register(side)}
            />
            <FieldError errors={[errors[side]]} />
          </Field>
        ))}
        <UnitField
          form={form}
          name="dimensions_unit"
          units={PACKAGE_DIMENSION_UNITS}
          label={t('admin.fields.package_type.dimensions_unit.label')}
        />
      </div>
      <FieldDescription>{t('admin.fields.package_type.dimensions.help')}</FieldDescription>

      <div className="grid grid-cols-[1fr_1fr_110px] gap-3">
        <Field>
          <FieldLabel htmlFor="package-type-weight">
            {t('admin.fields.package_type.weight.label')}
          </FieldLabel>
          <Input
            id="package-type-weight"
            type="number"
            min="0"
            step="0.01"
            aria-invalid={!!errors.weight}
            {...form.register('weight')}
          />
          <FieldError errors={[errors.weight]} />
          <FieldDescription>{t('admin.fields.package_type.weight.help')}</FieldDescription>
        </Field>
        <Field>
          <FieldLabel htmlFor="package-type-max-weight">
            {t('admin.fields.package_type.max_weight.label')}
          </FieldLabel>
          <Input
            id="package-type-max-weight"
            type="number"
            min="0"
            step="0.01"
            aria-invalid={!!errors.max_weight}
            {...form.register('max_weight')}
          />
          <FieldError errors={[errors.max_weight]} />
          <FieldDescription>{t('admin.fields.package_type.max_weight.help')}</FieldDescription>
        </Field>
        <UnitField
          form={form}
          name="weight_unit"
          units={PACKAGE_WEIGHT_UNITS}
          label={t('admin.fields.package_type.weight_unit.label')}
        />
      </div>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <FieldLabel htmlFor="package-type-default" className="cursor-pointer">
            {t('admin.fields.package_type.default.label')}
          </FieldLabel>
          <Controller
            control={form.control}
            name="default"
            render={({ field }) => (
              <Switch
                id="package-type-default"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
        <FieldDescription>{t('admin.fields.package_type.default.help')}</FieldDescription>
      </Field>
    </FieldGroup>
  )
}

function UnitField({
  form,
  name,
  units,
  label,
}: {
  form: UseFormReturn<PackageTypeFormValues>
  name: 'dimensions_unit' | 'weight_unit'
  units: readonly string[]
  label: string
}) {
  return (
    <Field>
      <FieldLabel htmlFor={`package-type-${name}`}>{label}</FieldLabel>
      <Controller
        control={form.control}
        name={name}
        render={({ field }) => {
          const options = units.map((unit) => ({ value: unit, label: unit }))
          return (
            <Select items={options} value={field.value ?? ''} onValueChange={field.onChange}>
              <SelectTrigger id={`package-type-${name}`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {options.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )
        }}
      />
    </Field>
  )
}
