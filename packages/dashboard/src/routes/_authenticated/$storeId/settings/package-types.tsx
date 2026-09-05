import { zodResolver } from '@hookform/resolvers/zod'
import type { PackageType, PackageTypeParams } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  i18n,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  requiredMessage,
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
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreatePackageType,
  useDeletePackageType,
  usePackageType,
  useUpdatePackageType,
} from '../../../../hooks/use-package-types'
import '../../../../tables/package-types'

// The vocabulary the server validates against; typing anything else could
// only fail on save.
const KINDS = ['box', 'envelope', 'carton', 'pallet', 'container'] as const
const DIMENSION_UNITS = ['mm', 'cm', 'in', 'ft'] as const
const WEIGHT_UNITS = ['g', 'kg', 'lb', 'oz'] as const

// Blank is how a merchant says "not measured", so every number is optional
// and an empty string reaches the API as null rather than zero — a box
// recorded as zero long, zero wide is not the same as one nobody measured.
const optionalNumber = z
  .union([z.string(), z.number()])
  .optional()
  .refine(
    (value) =>
      value === '' || value === undefined || (!Number.isNaN(Number(value)) && Number(value) >= 0),
    {
      error: () => i18n.t('admin.package_types.validation.non_negative'),
    },
  )

const packageTypeFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('package_type.name') }),
  kind: z.enum(KINDS),
  length: optionalNumber,
  width: optionalNumber,
  height: optionalNumber,
  dimensions_unit: z.enum(DIMENSION_UNITS).optional(),
  weight: optionalNumber,
  max_weight: optionalNumber,
  weight_unit: z.enum(WEIGHT_UNITS).optional(),
  default: z.boolean().optional(),
})

type PackageTypeFormValues = z.input<typeof packageTypeFormSchema>

// Blank erases a measurement, so it has to reach the API as an explicit null;
// undefined would leave whatever was recorded before untouched.
const NUMERIC_FIELDS = ['length', 'width', 'height', 'weight', 'max_weight'] as const

function toParams(values: PackageTypeFormValues): PackageTypeParams {
  const payload: Record<string, unknown> = { ...values }
  for (const field of NUMERIC_FIELDS) {
    const value = values[field]
    payload[field] = value === '' || value === undefined ? null : Number(value)
  }
  return payload as PackageTypeParams
}

const DEFAULT_VALUES: PackageTypeFormValues = {
  name: '',
  kind: 'box',
  length: '',
  width: '',
  height: '',
  dimensions_unit: 'cm',
  weight: '',
  max_weight: '',
  weight_unit: 'kg',
  default: false,
}

const packageTypesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/package-types')({
  validateSearch: packageTypesSearchSchema,
  component: PackageTypesPage,
})

function PackageTypesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof packageTypesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeletePackageType()
  const { permissions } = usePermissions()

  const isCreating = !!search.new
  const editId = isCreating ? undefined : search.edit

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, ...rest } = prev
        return { ...rest, new: true } as never
      },
    })

  const openEdit = (id: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return { ...rest, edit: id } as never
      },
    })

  useRowClickBridge('data-package-type-id', openEdit)

  async function handleDelete(packageType: PackageType) {
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
      <ResourceTable<PackageType>
        tableKey="package-types"
        queryKey="package-types"
        queryFn={(params) => adminClient.packageTypes.list(params)}
        searchParams={search}
        rowActions={(packageType) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(packageType.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.PackageType),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(packageType),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.PackageType}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.package_types.add_cta')}
            </Button>
          </Can>
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
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: PackageTypeFormValues) {
    try {
      await createMutation.mutateAsync(toParams(values))
      form.reset(DEFAULT_VALUES)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_VALUES)
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
  const form = useForm<PackageTypeFormValues>({
    resolver: zodResolver(packageTypeFormSchema),
    defaultValues: DEFAULT_VALUES,
    values: packageType
      ? {
          name: packageType.name,
          kind: packageType.kind as (typeof KINDS)[number],
          length: packageType.length ?? '',
          width: packageType.width ?? '',
          height: packageType.height ?? '',
          dimensions_unit: packageType.dimensions_unit as (typeof DIMENSION_UNITS)[number],
          weight: packageType.weight ?? '',
          max_weight: packageType.max_weight ?? '',
          weight_unit: packageType.weight_unit as (typeof WEIGHT_UNITS)[number],
          default: packageType.default,
        }
      : undefined,
  })

  async function onSubmit(values: PackageTypeFormValues) {
    try {
      await updateMutation.mutateAsync(toParams(values))
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

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
            const options = KINDS.map((kind) => ({
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
              {...form.register(side)}
            />
          </Field>
        ))}
        <UnitField
          form={form}
          name="dimensions_unit"
          units={DIMENSION_UNITS}
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
            {...form.register('weight')}
          />
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
            {...form.register('max_weight')}
          />
          <FieldDescription>{t('admin.fields.package_type.max_weight.help')}</FieldDescription>
        </Field>
        <UnitField
          form={form}
          name="weight_unit"
          units={WEIGHT_UNITS}
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
