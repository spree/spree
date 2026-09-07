import type { Supplier } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  CountryCombobox,
  ResourceTable,
  resourceSearchSchema,
  StateCombobox,
  Subject,
  useCountryStates,
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
  Textarea,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PencilIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateSupplier,
  useDeleteSupplier,
  useSupplier,
  useUpdateSupplier,
} from '../../../../hooks/use-suppliers'
import '../../../../tables/suppliers'

const suppliersSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/suppliers')({
  validateSearch: suppliersSearchSchema,
  component: SuppliersPage,
})

function SuppliersPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof suppliersSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSupplier()
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

  useRowClickBridge('data-supplier-id', openEdit)

  async function handleDelete(supplier: Supplier) {
    const ok = await confirm({
      title: t('admin.suppliers.delete_confirm.title'),
      message: t('admin.suppliers.delete_confirm.message', { name: supplier.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(supplier.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Supplier>
        tableKey="suppliers"
        queryKey="suppliers"
        queryFn={(params) => adminClient.suppliers.list(params)}
        searchParams={search}
        rowActions={(supplier) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                label: t('admin.actions.edit'),
                icon: <PencilIcon className="size-4" />,
                onSelect: () => openEdit(supplier.id),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Supplier),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(supplier),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Supplier}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.suppliers.new_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <SupplierSheet open onOpenChange={(open) => !open && closeSheet()} />}
      {editId && <SupplierSheet id={editId} open onOpenChange={(open) => !open && closeSheet()} />}
    </>
  )
}

interface SupplierFormState {
  name: string
  contact_name: string
  email: string
  phone: string
  notes: string
  address1: string
  address2: string
  city: string
  state_name: string
  state_code: string
  country_code: string
  postal_code: string
}

const EMPTY_FORM: SupplierFormState = {
  name: '',
  contact_name: '',
  email: '',
  phone: '',
  notes: '',
  address1: '',
  address2: '',
  city: '',
  state_name: '',
  state_code: '',
  country_code: '',
  postal_code: '',
}

function SupplierSheet({
  id,
  open,
  onOpenChange,
}: {
  id?: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: supplier } = useSupplier(id)
  const createMutation = useCreateSupplier()
  const updateMutation = useUpdateSupplier(id ?? '')
  const mutation = id ? updateMutation : createMutation

  const [form, setForm] = useState<SupplierFormState>(EMPTY_FORM)
  const [hydratedFor, setHydratedFor] = useState<string | undefined>(undefined)
  const { states } = useCountryStates(form.country_code)

  // The record arrives after the sheet opens, so seed the fields the first
  // time it does rather than on every render.
  if (supplier && hydratedFor !== supplier.id) {
    setHydratedFor(supplier.id)
    setForm({
      name: supplier.name,
      contact_name: supplier.contact_name ?? '',
      email: supplier.email ?? '',
      phone: supplier.phone ?? '',
      notes: supplier.notes ?? '',
      address1: supplier.address1 ?? '',
      address2: supplier.address2 ?? '',
      city: supplier.city ?? '',
      state_name: supplier.state_name ?? '',
      state_code: supplier.state_code ?? '',
      country_code: supplier.country_code ?? '',
      postal_code: supplier.postal_code ?? '',
    })
  }

  function set<K extends keyof SupplierFormState>(key: K, value: SupplierFormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  async function handleSubmit() {
    if (!form.name.trim()) return

    // Emptied fields are sent as null, not dropped: the API reads a missing
    // key as "leave it alone", so dropping them would make a cleared phone
    // number come back on the next fetch.
    const payload = Object.fromEntries(
      Object.entries(form).map(([key, value]) => [key, value.trim() || null]),
    ) as Record<string, string | null>

    const saved = await mutation
      .mutateAsync({ ...payload, name: form.name.trim() })
      .catch(() => undefined)
    if (!saved) return

    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {id ? t('admin.suppliers.edit_title') : t('admin.suppliers.new_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.suppliers.sheet_description')}</SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="supplier-name">{t('admin.fields.name.label')}</FieldLabel>
              <Input
                id="supplier-name"
                value={form.name}
                onChange={(event) => set('name', event.target.value)}
                aria-invalid={!form.name.trim() || undefined}
              />
              {!form.name.trim() && (
                <FieldError>{t('admin.suppliers.errors.name_blank')}</FieldError>
              )}
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-contact">
                {t('admin.suppliers.fields.contact_name')}
              </FieldLabel>
              <Input
                id="supplier-contact"
                value={form.contact_name}
                onChange={(event) => set('contact_name', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-email">{t('admin.fields.email.label')}</FieldLabel>
              <Input
                id="supplier-email"
                type="email"
                value={form.email}
                onChange={(event) => set('email', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-phone">{t('admin.fields.phone.label')}</FieldLabel>
              <Input
                id="supplier-phone"
                value={form.phone}
                onChange={(event) => set('phone', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-address1">
                {t('admin.suppliers.fields.address1')}
              </FieldLabel>
              <Input
                id="supplier-address1"
                value={form.address1}
                onChange={(event) => set('address1', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-address2">
                {t('admin.suppliers.fields.address2')}
              </FieldLabel>
              <Input
                id="supplier-address2"
                value={form.address2}
                onChange={(event) => set('address2', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-city">{t('admin.suppliers.fields.city')}</FieldLabel>
              <Input
                id="supplier-city"
                value={form.city}
                onChange={(event) => set('city', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-postal-code">
                {t('admin.suppliers.fields.postal_code')}
              </FieldLabel>
              <Input
                id="supplier-postal-code"
                value={form.postal_code}
                onChange={(event) => set('postal_code', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-country">{t('admin.fields.country.label')}</FieldLabel>
              <CountryCombobox
                id="supplier-country"
                value={form.country_code}
                onValueChange={(iso) => {
                  set('country_code', iso ?? '')
                  // The old state belongs to the old country; keeping it would
                  // put the supplier in a state that no longer exists.
                  set('state_code', '')
                }}
              />
            </Field>

            {form.country_code && states.length > 0 && (
              <Field>
                <FieldLabel htmlFor="supplier-state">{t('admin.fields.state.label')}</FieldLabel>
                <StateCombobox
                  id="supplier-state"
                  countryCode={form.country_code}
                  states={states}
                  value={form.state_code}
                  onValueChange={(abbr) => set('state_code', abbr)}
                />
              </Field>
            )}

            <Field>
              <FieldLabel htmlFor="supplier-notes">{t('admin.suppliers.fields.notes')}</FieldLabel>
              <Textarea
                id="supplier-notes"
                value={form.notes}
                onChange={(event) => set('notes', event.target.value)}
              />
            </Field>
          </FieldGroup>
        </div>

        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={mutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            onClick={handleSubmit}
            disabled={!form.name.trim() || mutation.isPending}
          >
            {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
