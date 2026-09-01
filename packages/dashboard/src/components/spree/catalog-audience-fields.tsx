import { adminClient, ResourceCombobox } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
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
import { PlusIcon, TrashIcon, Undo2Icon, UsersIcon } from 'lucide-react'
import { useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { AssignmentEntry, CatalogFormValues } from '../../schemas/catalog'

const ASSIGNABLE_TYPES = ['company', 'customer_group'] as const
type AssignableType = (typeof ASSIGNABLE_TYPES)[number]

export function CatalogAudienceFields({
  form,
  canEdit,
  showAddButton = true,
  inlineAssign = false,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
  /**
   * False where the host already offers Assign in its own header — the card
   * on the agreement editor does. The empty state keeps its button either
   * way: with no rows there is nothing for a header button to sit above.
   */
  showAddButton?: boolean
  /**
   * Render the assign form in the flow instead of a dialog. The wizard's
   * Audience step is a page of its own, and a dialog inside a dialog is a
   * stack with nothing to gain from it.
   */
  inlineAssign?: boolean
}) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const assignments: AssignmentEntry[] = form.watch('assignments') ?? []

  function update(next: AssignmentEntry[]) {
    form.setValue('assignments', next, { shouldDirty: true })
  }

  // Removal needs no confirm: nothing is written until Save, and Discard
  // puts it back — the same reason the assortment rows drop theirs.
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
  function addAssignment(entry: AssignmentEntry) {
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

  function restore(index: number) {
    update(assignments.map((row, i) => (i === index ? { ...row, removed: false } : row)))
  }

  return (
    <>
      {/* Nothing assigned reads as a state to act on rather than a sentence
          under a button in the corner: the one thing to do is offered in the
          middle of the space it will fill. */}
      {assignments.length === 0 ? (
        <Empty className="border">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <UsersIcon />
            </EmptyMedia>
            <EmptyTitle>{t('admin.catalogs.assignments.empty')}</EmptyTitle>
            <EmptyDescription>{t('admin.catalogs.assignments.empty_description')}</EmptyDescription>
          </EmptyHeader>
          {canEdit && (
            <Button size="sm" variant="outline" type="button" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.catalogs.assignments.add_cta')}
            </Button>
          )}
        </Empty>
      ) : (
        <div className="flex flex-col gap-3">
          {canEdit && showAddButton && (
            <div className="flex justify-end">
              <Button size="sm" variant="outline" type="button" onClick={() => setAddOpen(true)}>
                <PlusIcon className="size-4" />
                {t('admin.catalogs.assignments.add_cta')}
              </Button>
            </div>
          )}
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
                  className={cn(
                    'flex min-w-0 items-center gap-2',
                    assignment.removed && 'line-through',
                  )}
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
                      onClick={() => restore(index)}
                      aria-label={t('admin.actions.restore')}
                    >
                      <Undo2Icon className="size-4" />
                    </Button>
                  ) : (
                    <Button
                      variant="ghost"
                      size="icon-xs"
                      type="button"
                      onClick={() => remove(index)}
                      aria-label={t('admin.actions.remove')}
                    >
                      <TrashIcon className="size-4" />
                    </Button>
                  ))}
              </div>
            ))}
          </div>
        </div>
      )}

      {addOpen &&
        (inlineAssign ? (
          <div className="flex flex-col gap-4 rounded-md border p-4">
            <div>
              <h3 className="font-medium text-sm">{t('admin.catalogs.assignments.add_title')}</h3>
              <p className="text-muted-foreground text-sm">
                {t('admin.catalogs.assignments.dialog_description')}
              </p>
            </div>
            <AssignCatalogForm
              inline
              assigned={assignments}
              onCancel={() => setAddOpen(false)}
              onAdd={addAssignment}
            />
          </div>
        ) : (
          <AssignCatalogDialog
            open
            onOpenChange={setAddOpen}
            assigned={assignments}
            onAdd={addAssignment}
          />
        ))}
    </>
  )
}

/**
 * The audience as a card, for the agreement editor's sidebar. The wizard
 * renders the same fields inside its own step card, so the two surfaces
 * cannot drift — there is one place a catalog's audience is edited
 * (docs/plans/6.0-catalog-agreement-rework.md).
 */
export function CatalogAudienceCard({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.assignments.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <CatalogAudienceFields form={form} canEdit={canEdit} />
      </CardContent>
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
  inline,
}: {
  /** Already staged, so the same audience cannot be added twice. */
  assigned: AssignmentEntry[]
  onAdd: (entry: AssignmentEntry) => void
  onCancel: () => void
  inline?: boolean
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
    // Inline the form stays open for a second pick, so it is reset rather
    // than dismissed; in a dialog the close is the reset.
    if (inline) {
      setAssignableId('')
      setAssignableName(null)
    } else {
      onCancel()
    }
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
