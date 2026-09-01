import { adminClient, ResourceCombobox } from '@spree/dashboard-core'
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
import { useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { AssignmentEntry, CatalogFormValues } from '../../schemas/catalog'

const ASSIGNABLE_TYPES = ['company', 'customer_group'] as const
type AssignableType = (typeof ASSIGNABLE_TYPES)[number]

/**
 * The staged audience and the three things a surface does to it. Shared so
 * the wizard step and the editor card agree on what assigning means, while
 * each arranges it the way its own space wants.
 */
function useCatalogAudience(form: UseFormReturn<CatalogFormValues>) {
  const assignments: AssignmentEntry[] = form.watch('assignments') ?? []

  function update(next: AssignmentEntry[]) {
    form.setValue('assignments', next, { shouldDirty: true })
  }

  function restore(index: number) {
    update(assignments.map((row, i) => (i === index ? { ...row, removed: false } : row)))
  }

  // Removal needs no confirm: nothing is written until Save, and Discard puts
  // it back — the same reason the assortment rows drop theirs.
  //
  // A row that exists server-side is marked rather than dropped, so it stays
  // visible struck through with an undo, like a product staged for removal.
  // One the merchant only just added has nothing to undo back to, so it goes.
  function remove(index: number) {
    const entry = assignments[index]
    if (!entry.id) {
      update(assignments.filter((_, i) => i !== index))
      return
    }

    update(assignments.map((row, i) => (i === index ? { ...row, removed: true } : row)))
  }

  // Re-picking an audience staged for withdrawal restores it: it is still
  // assigned server-side, so a second row would render it twice and then
  // re-create what the save just left in place.
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

/** The assigned rows. Layout above it differs by surface; a row does not. */
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
            <span className="truncate text-foreground text-sm">
              {assignment.assignable_name ?? assignment.assignable_id}
            </span>
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

/** Nothing assigned yet, with the one thing to do offered in the middle. */
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

/**
 * The audience on the wizard's step, which is a page of its own: the assign
 * form opens inline below the list, because a dialog on top of the wizard's
 * dialog is a stack with nothing to gain from it.
 */
export function CatalogAudienceStep({ form }: { form: UseFormReturn<CatalogFormValues> }) {
  const { t } = useTranslation()
  const [assigning, setAssigning] = useState(false)
  const { assignments, add, remove, restore } = useCatalogAudience(form)

  return (
    <div className="flex flex-col gap-3">
      {assignments.length === 0 ? (
        <AudienceEmpty canEdit onAssign={() => setAssigning(true)} />
      ) : (
        <>
          <div className="flex justify-end">
            <Button size="sm" variant="outline" type="button" onClick={() => setAssigning(true)}>
              <PlusIcon className="size-4" />
              {t('admin.catalogs.assignments.add_cta')}
            </Button>
          </div>
          <AudienceList assignments={assignments} canEdit onRemove={remove} onRestore={restore} />
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

/**
 * The audience on the agreement editor, as a card in the sidebar: Assign sits
 * in the card header where every other card here puts its one action, and the
 * form opens in a dialog, since the sidebar has no room to grow one inline.
 */
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
        {/* Only once there are rows: with none, the empty state below offers
            the same action in the middle of the space it will fill. */}
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
          <AudienceList
            assignments={assignments}
            canEdit={canEdit}
            onRemove={remove}
            onRestore={restore}
          />
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

/**
 * Picking one audience. Rendered inline where there is room for it — the
 * wizard's Audience step is a whole empty page, and a dialog on top of a
 * dialog is a stack nobody asked for — and in a dialog on the agreement
 * editor, where it is one small action on an already busy page.
 */
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

  const { search, hydrate } = assignableSearch(assignableType)

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
          <ResourceCombobox<AssignableOption>
            key={assignableType}
            queryKey={`catalog-assignables-${assignableType}`}
            search={search}
            hydrate={hydrate}
            getOptionLabel={(option) => option.name ?? option.email ?? option.id}
            placeholder={t('admin.catalogs.assignments.audience_placeholder')}
            emptyText={t('admin.catalogs.assignments.audience_empty')}
            value={assignableId || undefined}
            // The record, not just the id: a staged row has to render a name
            // before the assignment exists server-side.
            onChange={(id, record) => {
              setAssignableId(id ?? '')
              setAssignableName(record ? (record.name ?? record.email ?? null) : null)
            }}
          />
          {duplicate && <FieldError>{t('admin.catalogs.assignments.already_assigned')}</FieldError>}
          {assignableType === 'company' && (
            <FieldDescription>
              {t('admin.catalogs.assignments.company_subtree_help')}
            </FieldDescription>
          )}
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
