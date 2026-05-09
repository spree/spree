import type { CustomFieldOwnerType } from '@spree/admin-sdk'
import { ArrowLeftIcon, CheckCircle2Icon, Loader2Icon, PlusIcon } from 'lucide-react'
import { type ReactNode, useEffect, useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { EmptyState } from '@/components/spree/empty-state'
import { Button } from '@/components/ui/button'
import { Field, FieldLabel } from '@/components/ui/field'
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import {
  useCreateCustomField,
  useCustomFieldDefinitions,
  useCustomFields,
  useDeleteCustomField,
  useUpdateCustomField,
} from '@/hooks/use-custom-fields'
import { DefinitionForm } from './definition-form'
import { ValueInput } from './value-input'

type View = 'values' | 'new-definition' | 'definition-created'

interface CustomFieldsDrawerProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  ownerType: CustomFieldOwnerType
  ownerId: string
  /** Display name for the resource type (e.g., "products"). */
  resourceLabel: string
}

export function CustomFieldsDrawer({
  open,
  onOpenChange,
  ownerType,
  ownerId,
  resourceLabel,
}: CustomFieldsDrawerProps) {
  const [view, setView] = useState<View>('values')
  const [lastCreatedDefinitionId, setLastCreatedDefinitionId] = useState<string | null>(null)

  // Reset to values view when the drawer reopens
  useEffect(() => {
    if (open) setView('values')
  }, [open])

  const header =
    view === 'values' ? (
      <SheetTitle>Custom fields</SheetTitle>
    ) : (
      <SheetTitle className="flex gap-2 items-center">
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          onClick={() => setView('values')}
          aria-label="Back"
        >
          <ArrowLeftIcon className="size-4" />
        </Button>
        {view === 'new-definition' ? 'New custom field' : 'Definition created'}
      </SheetTitle>
    )

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" showCloseButton className="overflow-hidden">
        {view === 'values' && (
          <ValuesView
            ownerType={ownerType}
            ownerId={ownerId}
            resourceLabel={resourceLabel}
            onAddDefinition={() => setView('new-definition')}
            highlightedDefinitionId={lastCreatedDefinitionId}
            onClearHighlight={() => setLastCreatedDefinitionId(null)}
            onClose={() => onOpenChange(false)}
            header={header}
          />
        )}
        {view === 'new-definition' && (
          <NewDefinitionView
            resourceType={ownerType}
            header={header}
            onCancel={() => setView('values')}
            onSuccess={(id) => {
              setLastCreatedDefinitionId(id)
              setView('definition-created')
              toast.success('Definition created')
            }}
          />
        )}
        {view === 'definition-created' && (
          <>
            <SheetHeader>{header}</SheetHeader>
            <div className="flex-1 overflow-y-auto p-4">
              <DefinitionCreatedView
                onAddAnother={() => setView('new-definition')}
                onSetValues={() => setView('values')}
              />
            </div>
          </>
        )}
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// New-definition view — owns the SheetHeader, body, and SheetFooter so the
// submit button is inside the same <form> as the inputs (no cross-DOM tricks).
// ---------------------------------------------------------------------------

function NewDefinitionView({
  resourceType,
  header,
  onCancel,
  onSuccess,
}: {
  resourceType: CustomFieldOwnerType
  header: React.ReactNode
  onCancel: () => void
  onSuccess: (id: string) => void
}) {
  return (
    <DefinitionForm
      resourceType={resourceType}
      onSuccess={onSuccess}
      renderShell={({ fields, submitButton }) => (
        <>
          <SheetHeader className="h-13 py-3">{header}</SheetHeader>
          <div className="flex-1 overflow-y-auto p-4">{fields}</div>
          <SheetFooter>
            <Button type="button" variant="outline" size="sm" onClick={onCancel}>
              Cancel
            </Button>
            {submitButton}
          </SheetFooter>
        </>
      )}
    />
  )
}

// ---------------------------------------------------------------------------
// Values view
// ---------------------------------------------------------------------------

interface ValuesViewProps {
  ownerType: CustomFieldOwnerType
  ownerId: string
  resourceLabel: string
  onAddDefinition: () => void
  highlightedDefinitionId: string | null
  onClearHighlight: () => void
  onClose: () => void
  header: ReactNode
}

function ValuesView({
  ownerType,
  ownerId,
  resourceLabel,
  onAddDefinition,
  highlightedDefinitionId,
  onClearHighlight,
  onClose,
  header,
}: ValuesViewProps) {
  const { data: definitionsResp, isLoading: defsLoading } = useCustomFieldDefinitions(ownerType)
  const { data: valuesResp, isLoading: valsLoading } = useCustomFields(ownerType, ownerId)
  const createValue = useCreateCustomField(ownerType, ownerId)
  const updateValue = useUpdateCustomField(ownerType, ownerId)
  const deleteValue = useDeleteCustomField(ownerType, ownerId)

  const definitions = useMemo(() => definitionsResp?.data ?? [], [definitionsResp])
  const values = useMemo(() => valuesResp?.data ?? [], [valuesResp])

  // Build a map: definitionId → value record
  const valueByDefinition = useMemo(
    () => new Map(values.map((v) => [v.custom_field_definition_id, v])),
    [values],
  )

  // Default values keyed by definition id
  const defaultFormValues = useMemo(() => {
    const next: Record<string, unknown> = {}
    for (const def of definitions) {
      next[def.id] = valueByDefinition.get(def.id)?.value ?? null
    }
    return next
  }, [definitions, valueByDefinition])

  const form = useForm<Record<string, unknown>>({
    defaultValues: defaultFormValues,
  })

  // Reset form when definitions or stored values change
  useEffect(() => {
    form.reset(defaultFormValues)
  }, [defaultFormValues, form])

  const isLoading = defsLoading || valsLoading
  const isSaving = createValue.isPending || updateValue.isPending || deleteValue.isPending

  if (isLoading) {
    return (
      <>
        <SheetHeader>{header}</SheetHeader>
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            <Skeleton className="h-20 w-full rounded-md" />
            <Skeleton className="h-20 w-full rounded-md" />
          </div>
        </div>
      </>
    )
  }

  if (definitions.length === 0) {
    return (
      <>
        <SheetHeader>{header}</SheetHeader>
        <div className="flex-1 overflow-y-auto p-4">
          <EmptyState
            title={`No custom fields defined for ${resourceLabel}`}
            description="Define a custom field to store typed, structured information alongside your records."
            action={
              <Button type="button" size="sm" onClick={onAddDefinition}>
                <PlusIcon className="size-4" />
                Create definition
              </Button>
            }
          />
        </div>
      </>
    )
  }

  const onSubmit = form.handleSubmit(async (formValues) => {
    const tasks: Promise<unknown>[] = []
    for (const def of definitions) {
      const submitted = formValues[def.id]
      const existing = valueByDefinition.get(def.id)
      const isEmpty = submitted === null || submitted === undefined || submitted === ''

      if (existing) {
        if (isEmpty) {
          tasks.push(deleteValue.mutateAsync(existing.id))
        } else if (submitted !== existing.value) {
          tasks.push(updateValue.mutateAsync({ id: existing.id, value: submitted }))
        }
      } else if (!isEmpty) {
        tasks.push(
          createValue.mutateAsync({
            custom_field_definition_id: def.id,
            value: submitted,
          }),
        )
      }
    }

    if (tasks.length === 0) {
      onClose()
      return
    }

    try {
      await Promise.all(tasks)
      toast.success('Custom fields saved')
      onClose()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to save custom fields'
      toast.error(message)
    }
  })

  return (
    <form
      onSubmit={(e) => {
        // The drawer is portaled out of the DOM but React bubbles synthetic
        // events through the React tree, so without this guard the outer
        // product form's onSubmit also fires. Hard-stop here.
        e.stopPropagation()
        onSubmit(e)
      }}
      className="flex h-full flex-col"
    >
      <SheetHeader>{header}</SheetHeader>
      <div className="flex-1 overflow-y-auto p-4">
        <div className="flex flex-col gap-5">
          {definitions.map((def) => {
            const isHighlighted = def.id === highlightedDefinitionId
            return (
              <Field
                key={def.id}
                className={
                  isHighlighted
                    ? 'rounded-md ring-2 ring-primary/40 ring-offset-2 transition-shadow'
                    : undefined
                }
              >
                <div className="flex items-baseline justify-between">
                  <FieldLabel htmlFor={`cf-${def.id}`}>
                    <span className="font-medium">{def.label}</span>{' '}
                    <code className="text-xs text-muted-foreground">
                      {def.namespace}.{def.key}
                    </code>
                  </FieldLabel>
                  {!def.storefront_visible && (
                    <span className="text-xs text-muted-foreground">Admin only</span>
                  )}
                </div>
                <ValueInput
                  control={form.control}
                  name={def.id}
                  fieldType={def.field_type}
                  id={`cf-${def.id}`}
                />
              </Field>
            )
          })}
        </div>

        <div className="mt-6 flex items-center justify-start border-t pt-4">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => {
              onClearHighlight()
              onAddDefinition()
            }}
          >
            <PlusIcon className="size-4" />
            Add another field
          </Button>
        </div>
      </div>

      <SheetFooter>
        <Button type="button" variant="outline" onClick={onClose}>
          Cancel
        </Button>
        <Button type="submit" disabled={isSaving}>
          {isSaving && <Loader2Icon className="size-4 animate-spin" />}
          Save
        </Button>
      </SheetFooter>
    </form>
  )
}

// ---------------------------------------------------------------------------
// Definition created view
// ---------------------------------------------------------------------------

function DefinitionCreatedView({
  onAddAnother,
  onSetValues,
}: {
  onAddAnother: () => void
  onSetValues: () => void
}) {
  return (
    <div className="flex flex-col items-center gap-4 py-8 text-center">
      <CheckCircle2Icon className="size-10 text-emerald-500" />
      <div className="flex flex-col gap-1">
        <p className="text-base font-medium">Definition created</p>
        <p className="text-sm text-muted-foreground">
          You can set its value now or define another field first.
        </p>
      </div>
      <div className="mt-2 flex gap-2">
        <Button type="button" variant="outline" size="sm" onClick={onAddAnother}>
          <PlusIcon className="size-4" />
          Create another
        </Button>
        <Button type="button" size="sm" onClick={onSetValues}>
          Set values
        </Button>
      </div>
    </div>
  )
}
