import type { PreferenceField, SellerRequirement, SellerRequirementType } from '@spree/admin-sdk'
import type { ResourceFilterConfig } from '@spree/dashboard-core'
import {
  adminClient,
  Can,
  defaultPreferences,
  PreferencesForm,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  typeDescription,
  typeLabel,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
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
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  Textarea,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { customFieldDefinitionAutocompleteProps } from '../../../../hooks/use-custom-field-definitions'
import {
  useCreateSellerRequirement,
  useDeleteSellerRequirement,
  useSellerRequirements,
  useSellerRequirementTypes,
  useUpdateSellerRequirement,
} from '../../../../hooks/use-seller-requirements'
import '../../../../tables/seller-requirements'

const searchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/seller-requirements')({
  validateSearch: searchSchema,
  component: SellerRequirementsPage,
})

/**
 * What this marketplace asks of a seller before it will let them trade.
 * The operator composes the checklist here: add a requirement, word it, order
 * it, and decide whether it blocks approval or is merely recommended.
 */
function SellerRequirementsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof searchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSellerRequirement()
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

  useRowClickBridge('data-seller-requirement-id', openEdit)

  async function handleDelete(requirement: SellerRequirement) {
    const ok = await confirm({
      title: t('admin.seller_requirements.delete_confirm.title'),
      message: t('admin.seller_requirements.delete_confirm.message', {
        name: requirement.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(requirement.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<SellerRequirement>
        tableKey="seller-requirements"
        queryKey="seller-requirements"
        queryFn={(params) => adminClient.sellerRequirements.list(params)}
        searchParams={search}
        rowActions={(requirement) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(requirement.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Seller),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(requirement),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Seller}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.seller_requirements.add_cta')}
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.sellerRequirements.update(id, { position })
            queryClient.invalidateQueries({ queryKey: ['seller-requirements'] })
          },
        }}
      />

      {isCreating && <CreateRequirementSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditRequirementSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateRequirementSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateSellerRequirement()
  const { data: typesResponse, isLoading } = useSellerRequirementTypes()
  const types = useMemo(() => typesResponse?.data ?? [], [typesResponse])

  const [type, setType] = useState<string>('')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [required, setRequired] = useState(true)
  const [preferences, setPreferences] = useState<Record<string, unknown>>({})
  const [associationIds, setAssociationIds] = useState<string[]>([])
  const [saveError, setSaveError] = useState<string | null>(null)

  const selected: SellerRequirementType | undefined = useMemo(
    () => types.find((entry) => entry.type === type),
    [types, type],
  )

  // The server decides what can be added — a kind that answers one question is
  // offered once — so the picker reads `addable` rather than restating the rule.
  const available = useMemo(() => types.filter((entry) => entry.addable), [types])

  // Base UI renders the trigger label from `items`, not from the selected
  // <SelectItem>'s children — without these pairs the trigger shows the slug.
  const selectItems = useMemo(
    () =>
      available.map((entry) => ({
        label: typeLabel('seller_requirement', entry.type, entry.name),
        value: entry.type,
      })),
    [available],
  )

  function handleTypeChange(value: string) {
    setType(value)
    const entry = types.find((candidate) => candidate.type === value)
    setPreferences(
      entry ? defaultPreferences(entry.preference_schema as unknown as PreferenceField[]) : {},
    )
  }

  async function handleSave() {
    if (!type) return

    setSaveError(null)
    try {
      await createMutation.mutateAsync({
        type,
        name: name || undefined,
        description: description || undefined,
        required,
        preferences,
        ...associationParams(selected, associationIds),
      })
      onOpenChange(false)
    } catch (error) {
      // The sheet stays open carrying what the operator typed: a validation
      // failure is something to correct, not a reason to lose the form.
      // `useResourceMutation` suppresses its own toast for 422s, expecting
      // the form to show the message.
      setSaveError(error instanceof Error ? error.message : String(error))
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.seller_requirements.add_title')}</SheetTitle>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {saveError && (
            // `role="alert"`: the message appears after a failed save, so a
            // screen reader has to be told rather than the operator being
            // expected to notice new text.
            <p role="alert" className="text-destructive text-sm">
              {saveError}
            </p>
          )}
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.seller_requirements.fields.kind.label')}</FieldLabel>
              <Select items={selectItems} value={type} onValueChange={handleTypeChange}>
                <SelectTrigger disabled={isLoading}>
                  <SelectValue
                    placeholder={t('admin.seller_requirements.fields.kind.placeholder')}
                  />
                </SelectTrigger>
                <SelectContent>
                  {available.map((entry) => (
                    <SelectItem key={entry.type} value={entry.type}>
                      {typeLabel('seller_requirement', entry.type, entry.name)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {selected &&
                typeDescription('seller_requirement', selected.type, selected.description) && (
                  <p className="text-muted-foreground text-xs">
                    {typeDescription('seller_requirement', selected.type, selected.description)}
                  </p>
                )}
            </Field>

            {selected && (
              <RequirementFields
                kindEntry={selected}
                values={{ name, description, required, preferences, associationIds }}
                onChange={{
                  setName,
                  setDescription,
                  setRequired,
                  setPreferences,
                  setAssociationIds,
                }}
              />
            )}
          </FieldGroup>
        </div>
        <SheetFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button onClick={handleSave} disabled={!type || createMutation.isPending}>
            {t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function EditRequirementSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { data: typesResponse } = useSellerRequirementTypes()
  // Reads the list already in cache rather than firing a request for one row.
  const { data: listResponse } = useSellerRequirements()

  const requirement = useMemo(
    () => listResponse?.data?.find((row: SellerRequirement) => row.id === id),
    [listResponse, id],
  )
  const kindEntry = useMemo(
    () => typesResponse?.data?.find((entry) => entry.type === requirement?.kind),
    [typesResponse, requirement],
  )

  // The form seeds its fields from the record once, so it must not mount
  // before the record is there — a form seeded from `undefined` would render
  // blank and then save those blanks over the requirement.
  if (!requirement) return null

  return (
    <EditRequirementForm
      requirement={requirement}
      kindEntry={kindEntry}
      open={open}
      onOpenChange={onOpenChange}
    />
  )
}

function EditRequirementForm({
  requirement,
  kindEntry,
  open,
  onOpenChange,
}: {
  requirement: SellerRequirement
  kindEntry: SellerRequirementType | undefined
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateSellerRequirement(requirement.id)

  const [name, setName] = useState(requirement?.name ?? '')
  const [description, setDescription] = useState(requirement?.description ?? '')
  const [required, setRequired] = useState(requirement?.required ?? true)
  const [active, setActive] = useState(requirement?.active ?? true)
  const [preferences, setPreferences] = useState<Record<string, unknown>>(
    (requirement?.preferences as Record<string, unknown>) ?? {},
  )
  const [associationIds, setAssociationIds] = useState<string[]>(
    requirement?.custom_field_definition_ids ?? [],
  )
  const [saveError, setSaveError] = useState<string | null>(null)

  async function handleSave() {
    setSaveError(null)
    try {
      await updateMutation.mutateAsync({
        name: name || undefined,
        description: description || undefined,
        required,
        active,
        preferences,
        ...associationParams(kindEntry, associationIds),
      })
      onOpenChange(false)
    } catch (error) {
      setSaveError(error instanceof Error ? error.message : String(error))
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{requirement?.name ?? t('admin.seller_requirements.edit_title')}</SheetTitle>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {saveError && (
            // `role="alert"`: the message appears after a failed save, so a
            // screen reader has to be told rather than the operator being
            // expected to notice new text.
            <p role="alert" className="text-destructive text-sm">
              {saveError}
            </p>
          )}
          <FieldGroup>
            {kindEntry && (
              <RequirementFields
                kindEntry={kindEntry}
                values={{ name, description, required, preferences, associationIds }}
                onChange={{
                  setName,
                  setDescription,
                  setRequired,
                  setPreferences,
                  setAssociationIds,
                }}
              />
            )}

            <SettingSwitch
              label={t('admin.seller_requirements.fields.active.label')}
              description={t('admin.seller_requirements.fields.active.help')}
              value={active}
              onChange={setActive}
            />
          </FieldGroup>
        </div>
        <SheetFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button onClick={handleSave} disabled={updateMutation.isPending}>
            {t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

// Which picker an association-backed field gets. Keyed by the field name the
// types endpoint reports, so a kind that names records is configured with a
// real picker rather than a text box — and a kind the dashboard has not been
// taught about still renders its preference schema.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const ASSOCIATION_PICKERS: Record<string, (queryKey: string) => ResourceFilterConfig<any>> = {
  custom_field_definition_ids: customFieldDefinitionAutocompleteProps('Spree::Seller'),
}

/**
 * Sends the chosen records under the field name the kind declared, so a new
 * kind naming a different association needs no change here.
 */
function associationParams(
  kindEntry: SellerRequirementType | undefined,
  ids: string[],
): Record<string, string[]> {
  const field = kindEntry?.association_fields?.[0]
  if (!field || !ASSOCIATION_PICKERS[field]) return {}

  return { [field]: ids }
}

const CONTENT_TYPE_LABELS: Record<string, string> = {
  'application/pdf': 'PDF',
  'image/jpeg': 'JPEG',
  'image/png': 'PNG',
  'image/heic': 'HEIC',
  'image/webp': 'WebP',
  'application/msword': 'Word',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'Word',
}

/** MIME types as a person would name them, in order, without repeats. */
function formatContentTypes(types: string[]): string {
  const labels = types.map((type) => CONTENT_TYPE_LABELS[type] ?? type)

  return [...new Set(labels)].join(', ')
}

interface RequirementValues {
  name: string
  description: string
  required: boolean
  preferences: Record<string, unknown>
  associationIds: string[]
}

interface RequirementSetters {
  setName: (value: string) => void
  setDescription: (value: string) => void
  setRequired: (value: boolean) => void
  setPreferences: (value: Record<string, unknown>) => void
  setAssociationIds: (value: string[]) => void
}

/**
 * The part of the form both sheets share: how the requirement is worded, what
 * its kind takes as configuration, and whether it blocks approval.
 */
function RequirementFields({
  kindEntry,
  values,
  onChange,
}: {
  kindEntry: SellerRequirementType
  values: RequirementValues
  onChange: RequirementSetters
}) {
  const { t } = useTranslation()
  const associationPicker = ASSOCIATION_PICKERS[kindEntry.association_fields?.[0] ?? '']

  return (
    <>
      <Field>
        {/* A kind that can appear more than once has nothing else to tell it
            apart by, so its label is the operator's own wording. */}
        <FieldLabel>
          {kindEntry.allow_multiple
            ? t('admin.seller_requirements.fields.name.label_required')
            : t('admin.seller_requirements.fields.name.label')}
        </FieldLabel>
        <Input
          value={values.name}
          onChange={(event) => onChange.setName(event.target.value)}
          placeholder={typeLabel('seller_requirement', kindEntry.type, kindEntry.name)}
        />
        <p className="text-muted-foreground text-xs">
          {t('admin.seller_requirements.fields.name.help')}
        </p>
      </Field>

      <Field>
        <FieldLabel>{t('admin.seller_requirements.fields.description.label')}</FieldLabel>
        <Textarea
          value={values.description}
          onChange={(event) => onChange.setDescription(event.target.value)}
          placeholder={t('admin.seller_requirements.fields.description.placeholder')}
        />
      </Field>

      {kindEntry.preference_schema.length > 0 && (
        <PreferencesForm
          schema={kindEntry.preference_schema as unknown as PreferenceField[]}
          values={values.preferences}
          onChange={onChange.setPreferences}
        />
      )}

      {associationPicker && (
        <Field>
          <FieldLabel>{t('admin.seller_requirements.fields.custom_fields.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...associationPicker(`seller-requirement-${kindEntry.type}`)}
            value={values.associationIds}
            onChange={onChange.setAssociationIds}
          />
          <p className="text-muted-foreground text-xs">
            {t('admin.seller_requirements.fields.custom_fields.help')}
          </p>
        </Field>
      )}

      {/* Stated, not asked: what a scan or a certificate arrives as is the
          same for every marketplace, and typing MIME types is a way to get
          `image/jpg` wrong and accept nothing. */}
      {kindEntry.accepted_content_types.length > 0 && (
        <Field>
          <FieldLabel>{t('admin.seller_requirements.fields.accepted_files.label')}</FieldLabel>
          <p className="text-muted-foreground text-xs">
            {t('admin.seller_requirements.fields.accepted_files.help', {
              types: formatContentTypes(kindEntry.accepted_content_types),
            })}
          </p>
        </Field>
      )}

      {/* Optional requirements are shown to the seller and counted in their
          progress, but never stand between them and approval. */}
      <SettingSwitch
        label={t('admin.seller_requirements.fields.required.label')}
        description={t('admin.seller_requirements.fields.required.help')}
        value={values.required}
        onChange={onChange.setRequired}
      />
    </>
  )
}

function SettingSwitch({
  label,
  description,
  value,
  onChange,
}: {
  label: string
  description: string
  value: boolean
  onChange: (value: boolean) => void
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <div className="flex flex-col">
        <span className="font-medium text-sm">{label}</span>
        <span className="text-muted-foreground text-xs">{description}</span>
      </div>
      <Switch checked={value} onCheckedChange={onChange} />
    </div>
  )
}
