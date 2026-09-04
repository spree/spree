import type { Company } from '@spree/admin-sdk'
import { adminClient, ResourceCombobox, useStore } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { PlusIcon, TrashIcon, Undo2Icon, UsersIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { companyAutocompleteProps } from '../../hooks/use-companies'
import type { AssignmentEntry, CatalogFormValues } from '../../schemas/catalog'
import { CompanyComboboxOption } from './company-combobox-option'

const ASSIGNABLE_TYPES = ['company', 'customer_group'] as const
type AssignableType = (typeof ASSIGNABLE_TYPES)[number]

/** Shared so the wizard step and the editor card agree on what assigning means. */
function useCatalogAudience(form: UseFormReturn<CatalogFormValues>) {
  const assignments: AssignmentEntry[] = form.watch('assignments') ?? []

  function update(next: AssignmentEntry[]) {
    form.setValue('assignments', next, { shouldDirty: true })
  }

  function restore(index: number) {
    update(assignments.map((row, i) => (i === index ? { ...row, removed: false } : row)))
  }

  // A saved row is marked rather than dropped, so it stays visible with an
  // undo; one just added has nothing to undo back to. No confirm either way —
  // Save is what writes, Discard is the undo.
  function remove(index: number) {
    const entry = assignments[index]
    if (!entry.id) {
      update(assignments.filter((_, i) => i !== index))
      return
    }

    update(assignments.map((row, i) => (i === index ? { ...row, removed: true } : row)))
  }

  // Re-picking a withdrawn audience restores it: still assigned server-side,
  // so a second row would render twice and re-create what Save left alone.
  function add(entry: AssignmentEntry) {
    const staged = assignments.findIndex(
      (row) =>
        row.assignable_type === entry.assignable_type && row.assignable_id === entry.assignable_id,
    )
    if (staged >= 0) {
      restore(staged)
      return
    }

    update([...assignments, entry])
  }

  return { assignments, add, remove, restore }
}

function AudienceList({
  assignments,
  canEdit,
  onRemove,
  onRestore,
}: {
  assignments: AssignmentEntry[]
  canEdit: boolean
  onRemove: (index: number) => void
  onRestore: (index: number) => void
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  return (
    <div className="flex flex-col gap-2">
      {assignments.map((assignment, index) => (
        <div
          key={`${assignment.assignable_type}-${assignment.assignable_id}`}
          className={cn(
            'flex items-center justify-between gap-2',
            assignment.removed && 'opacity-60',
          )}
        >
          <span
            className={cn('flex min-w-0 items-center gap-2', assignment.removed && 'line-through')}
          >
            <Badge variant="outline">
              {t(`admin.catalogs.assignable_types.${assignment.assignable_type}`)}
            </Badge>
            {/* Only companies have a page to open; a customer group is
                managed from a list, so its name stays plain text. */}
            {assignment.assignable_type === 'company' && !assignment.removed ? (
              <Link
                to="/$storeId/companies/$companyId"
                params={{ storeId, companyId: assignment.assignable_id }}
                className="truncate text-sm hover:underline"
              >
                {assignment.assignable_name ?? assignment.assignable_id}
              </Link>
            ) : (
              <span className="truncate text-foreground text-sm">
                {assignment.assignable_name ?? assignment.assignable_id}
              </span>
            )}
          </span>
          {canEdit &&
            (assignment.removed ? (
              <Button
                variant="ghost"
                size="icon-xs"
                type="button"
                onClick={() => onRestore(index)}
                aria-label={t('admin.actions.restore')}
              >
                <Undo2Icon className="size-4" />
              </Button>
            ) : (
              <Button
                variant="ghost"
                size="icon-xs"
                type="button"
                onClick={() => onRemove(index)}
                aria-label={t('admin.actions.remove')}
              >
                <TrashIcon className="size-4" />
              </Button>
            ))}
        </div>
      ))}
    </div>
  )
}

function AudiencePrecedenceNote({ assignments }: { assignments: AssignmentEntry[] }) {
  const { t } = useTranslation()
  const hasGroup = assignments.some(
    (entry) => !entry.removed && entry.assignable_type === 'customer_group',
  )

  if (!hasGroup) return null

  return (
    <p className="text-muted-foreground text-sm">
      {t('admin.catalogs.assignments.customer_group_precedence')}
    </p>
  )
}

function AudienceEmpty({ canEdit, onAssign }: { canEdit: boolean; onAssign: () => void }) {
  const { t } = useTranslation()

  return (
    <Empty className="border">
      <EmptyHeader>
        <EmptyMedia variant="icon">
          <UsersIcon />
        </EmptyMedia>
        <EmptyTitle>{t('admin.catalogs.assignments.empty')}</EmptyTitle>
        <EmptyDescription>{t('admin.catalogs.assignments.empty_description')}</EmptyDescription>
      </EmptyHeader>
      {canEdit && (
        <Button size="sm" variant="outline" type="button" onClick={onAssign}>
          <PlusIcon className="size-4" />
          {t('admin.catalogs.assignments.add_cta')}
        </Button>
      )}
    </Empty>
  )
}

/** The wizard's step: a page of its own, so the assign form opens inline. */
export function CatalogAudienceStep({
  form,
  assigning,
  onAssigningChange,
}: {
  form: UseFormReturn<CatalogFormValues>
  /** Owned by the wizard, whose heading row carries the Assign button. */
  assigning: boolean
  onAssigningChange: (assigning: boolean) => void
}) {
  const { t } = useTranslation()
  const { assignments, add, remove, restore } = useCatalogAudience(form)
  const setAssigning = onAssigningChange

  return (
    <div className="flex flex-col gap-3">
      {assignments.length === 0 ? (
        <AudienceEmpty canEdit onAssign={() => setAssigning(true)} />
      ) : (
        <>
          <AudienceList assignments={assignments} canEdit onRemove={remove} onRestore={restore} />
          <AudiencePrecedenceNote assignments={assignments} />
        </>
      )}

      {assigning && (
        <div className="flex flex-col gap-4 rounded-md border p-4">
          <div>
            <h3 className="font-medium text-sm">{t('admin.catalogs.assignments.add_title')}</h3>
            <p className="text-muted-foreground text-sm">
              {t('admin.catalogs.assignments.dialog_description')}
            </p>
          </div>
          <AssignCatalogForm
            assigned={assignments}
            onCancel={() => setAssigning(false)}
            onAdd={(entry) => {
              add(entry)
              setAssigning(false)
            }}
          />
        </div>
      )}
    </div>
  )
}

/** The editor's sidebar card, which has no room to grow a form inline. */
export function CatalogAudienceCard({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const [assigning, setAssigning] = useState(false)
  const { assignments, add, remove, restore } = useCatalogAudience(form)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.assignments.title')}</CardTitle>
        {canEdit && assignments.length > 0 && (
          <CardAction>
            <Button size="sm" variant="outline" type="button" onClick={() => setAssigning(true)}>
              <PlusIcon className="size-4" />
              {t('admin.catalogs.assignments.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent>
        {assignments.length === 0 ? (
          <AudienceEmpty canEdit={canEdit} onAssign={() => setAssigning(true)} />
        ) : (
          <div className="flex flex-col gap-3">
            <AudienceList
              assignments={assignments}
              canEdit={canEdit}
              onRemove={remove}
              onRestore={restore}
            />
            <AudiencePrecedenceNote assignments={assignments} />
          </div>
        )}
      </CardContent>

      {assigning && (
        <AssignCatalogDialog open onOpenChange={setAssigning} assigned={assignments} onAdd={add} />
      )}
    </Card>
  )
}

interface AssignableOption {
  id: string
  name?: string | null
  email?: string | null
}

/** Picking one audience. Its host decides whether this sits inline or in a dialog. */
function AssignCatalogForm({
  assigned,
  onAdd,
  onCancel,
}: {
  /** Already staged, so the same audience cannot be added twice. */
  assigned: AssignmentEntry[]
  onAdd: (entry: AssignmentEntry) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const [assignableType, setAssignableType] = useState<AssignableType>('company')
  const [assignableId, setAssignableId] = useState('')
  const [assignableName, setAssignableName] = useState<string | null>(null)

  const typeOptions = ASSIGNABLE_TYPES.map((type) => ({
    value: type,
    label: t(`admin.catalogs.assignable_types.${type}`),
  }))

  // A row staged for withdrawal is not a duplicate — picking it again is how
  // the merchant takes the removal back.
  const duplicate = assigned.some(
    (entry) =>
      !entry.removed &&
      entry.assignable_type === assignableType &&
      entry.assignable_id === assignableId,
  )

  function handleSubmit() {
    if (!assignableId || duplicate) return

    onAdd({
      assignable_type: assignableType,
      assignable_id: assignableId,
      assignable_name: assignableName,
    })
    // Closed either way: the row that appears in the list above is the
    // confirmation, and a form still sitting open under it reads as though
    // the add had not taken.
    onCancel()
  }

  return (
    <>
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
          {assignableType === 'company' ? (
            <ResourceCombobox<Company>
              key="company"
              {...companyAutocompleteProps('catalog-assignables-company')}
              renderOption={(company) => <CompanyComboboxOption company={company} />}
              value={assignableId || undefined}
              onChange={(id, record) => {
                setAssignableId(id ?? '')
                setAssignableName(record ? (record.name ?? null) : null)
              }}
            />
          ) : (
            <ResourceCombobox<AssignableOption>
              key="customer_group"
              queryKey="catalog-assignables-customer_group"
              search={(q) =>
                adminClient.customerGroups.list({ name_cont: q, limit: 100, sort: 'name' })
              }
              hydrate={(ids) => adminClient.customerGroups.list({ id_in: ids, limit: ids.length })}
              getOptionLabel={(group) => group.name ?? group.id}
              placeholder={t('admin.catalogs.assignments.audience_placeholder')}
              emptyText={t('admin.catalogs.assignments.audience_empty')}
              value={assignableId || undefined}
              onChange={(id, record) => {
                setAssignableId(id ?? '')
                setAssignableName(record ? (record.name ?? record.email ?? null) : null)
              }}
            />
          )}
          {duplicate && <FieldError>{t('admin.catalogs.assignments.already_assigned')}</FieldError>}
          <FieldDescription>
            {assignableType === 'company'
              ? t('admin.catalogs.assignments.company_subtree_help')
              : t('admin.catalogs.assignments.customer_group_help')}
          </FieldDescription>
        </Field>
      </FieldGroup>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onCancel}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" disabled={!assignableId || duplicate} onClick={handleSubmit}>
          {t('admin.actions.add')}
        </Button>
      </div>
    </>
  )
}

function AssignCatalogDialog({
  open,
  onOpenChange,
  assigned,
  onAdd,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  assigned: AssignmentEntry[]
  onAdd: (entry: AssignmentEntry) => void
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.catalogs.assignments.add_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.catalogs.assignments.dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <AssignCatalogForm
            assigned={assigned}
            onAdd={onAdd}
            onCancel={() => onOpenChange(false)}
          />
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}
