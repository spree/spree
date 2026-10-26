// Inline custom-fields editor — generic-context shape, three providers,
// predictable save modes (never on-blur). This is the single custom-fields
// surface across the dashboard.
//
// The card is purely presentational and reads everything from context. State
// and persistence are dependency-injected by the provider above it:
// - `FormBackedCustomFieldsProvider` keeps fields editable inline and writes
//   into a parent page form's `custom_fields[]` (products, categories) — values
//   persist only on that page's Save.
// - `DraftCustomFieldsProvider` keeps fields editable inline and holds them in
//   a `useCustomFieldsDraft` the host form saves from its own submit (settings
//   sheets, promotions, store settings).
// - `EditableApiCustomFieldsProvider` shows a read-only display with an Edit
//   button (orders, customers, sellers) and batches changed fields to the
//   /custom_fields endpoints on the card's own Save.
// None persists on blur; the provider advertises its behaviour via `mode`.
//
// The empty state opens a sheet to create the first definition in place; on
// success the sheet closes and the definitions query re-validates, so the card
// re-renders with the new field ready to edit (no redirect to settings).
//
// Composition refs:
// - state-context-interface: `{ state, actions, meta, mode }`
// - state-decouple-implementation: card never touches the form or the SDK
// - patterns-explicit-variants: named providers + a `mode` discriminator

import { zodResolver } from '@hookform/resolvers/zod'
import type { CustomField, CustomFieldDefinition, CustomFieldOwnerType } from '@spree/admin-sdk'
import type { CustomFieldFormValues } from '@spree/dashboard-core'
import {
  customFieldComponents,
  mapSpreeErrorsToForm,
  useCreateCustomField,
  useCreateCustomFieldDefinition,
  useCustomFieldDefinitions,
  useCustomFields,
  usePermissions,
  useUpdateCustomField,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldLabel,
  Input,
  RichTextEditor,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Switch,
  Textarea,
  toastManager,
} from '@spree/dashboard-ui'
import {
  Loader2Icon,
  PencilIcon,
  PlusIcon,
  SquareTextIcon,
  TagIcon,
} from '@spree/dashboard-ui/icons'
import { Link, useParams } from '@tanstack/react-router'
import { createContext, type ReactNode, useCallback, useContext, useMemo, useState } from 'react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  CUSTOM_FIELD_DEFINITION_DEFAULTS,
  type CustomFieldDefinitionFormValues,
  customFieldDefinitionSchema,
  customFieldDefinitionValuesToCreateParams,
} from '../../../schemas/custom-field-definition'
import { DefinitionFormFields } from './definition-form'

// ---------------------------------------------------------------------------
// Generic context interface — providers implement this, the card consumes it.
// ---------------------------------------------------------------------------

interface CustomFieldsState {
  /** Draft values keyed by definition id. Always reflects what the UI shows. */
  values: Record<string, unknown>
}

interface CustomFieldsActions {
  /** Update the draft value for a definition. Persistence is deferred to Save. */
  setValue: (definitionId: string, value: unknown) => void
}

interface CustomFieldsMeta {
  definitions: CustomFieldDefinition[]
  isLoading: boolean
  /**
   * Resource type the definitions belong to, by API shorthand (e.g.
   * `product`, `category`). Drives the in-place "create definition" sheet and
   * its query invalidation.
   */
  resourceType: string
  /** Plural, human-readable resource name for empty-state copy (e.g. "orders"). */
  resourceLabel?: string
  /**
   * Definitions the resource's type marks as required. Advisory only — the
   * backend never rejects a blank one (see Spree::Product), so this drives a
   * visual marker and nothing else.
   */
  requiredDefinitionIds?: string[]
  /** `false` hides the card: the endpoints need edit access even to read. */
  canEdit?: boolean
  /** The values did not load, so blank inputs would misstate what is saved. */
  loadFailed?: boolean
}

/**
 * How the card persists. Two surfaces, two predictable behaviours — never
 * on-blur:
 * - `form`: fields are always editable inline; nothing persists until the
 *   parent page form's Save (values live in `form.custom_fields[]`).
 * - `editable`: read-only display by default; an Edit button reveals inputs and
 *   a card-level Save batches all changed values to the API, then returns to
 *   display. For pages with no page-wide form (orders, customers).
 */
type CustomFieldsMode =
  | { kind: 'form' }
  | {
      kind: 'editable'
      isEditing: boolean
      saving: boolean
      startEdit: () => void
      cancel: () => void
      save: () => void
    }

interface CustomFieldsContextValue {
  state: CustomFieldsState
  actions: CustomFieldsActions
  meta: CustomFieldsMeta
  mode: CustomFieldsMode
}

const CustomFieldsContext = createContext<CustomFieldsContextValue | null>(null)

function useCustomFieldsContext() {
  const value = useContext(CustomFieldsContext)
  if (!value) {
    throw new Error('CustomFields components must be used within a CustomFieldsProvider')
  }
  return value
}

// Deep-equality check for custom-field values. Reference equality (`===`) is
// wrong for JSON custom fields because each query refetch hands back a fresh
// object reference even when the content hasn't changed — every blur would
// then re-commit a no-op mutation. Canonical JSON stringification handles
// scalars (returns the same canonical form for "a" / 1 / true / null) and
// recurses into nested objects/arrays.
function valuesEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true
  if (a == null || b == null) return false
  if (typeof a !== 'object' && typeof b !== 'object') return false
  try {
    return JSON.stringify(a) === JSON.stringify(b)
  } catch {
    return false
  }
}

// ---------------------------------------------------------------------------
// Provider A: form-backed (mode `form`).
// Reads from / writes to `form.values.custom_fields[]` via `setValue`. Nothing
// persists here — the parent page form's Save flushes everything.
// ---------------------------------------------------------------------------

// The minimal form shape the provider drives: any RHF form whose values carry a
// `custom_fields[]` array. Both ProductFormValues and CategoryFormValues satisfy
// this. The provider is generic over the concrete form type because RHF's
// `UseFormReturn` is invariant — a wider form is NOT assignable to a narrowed
// `UseFormReturn<CustomFieldsFormShape>`, so we infer `T` per call site instead
// and narrow internally for the `custom_fields`-only field operations.
export interface CustomFieldsFormShape {
  custom_fields?: CustomFieldFormValues[]
}

interface FormBackedProviderProps<T extends CustomFieldsFormShape> {
  form: UseFormReturn<T>
  resourceType: string
  /** Plural, human-readable resource name for empty-state copy. */
  resourceLabel?: string
  /**
   * Restricts and orders the rendered definitions — the product type's schema.
   * Ids not in this list are hidden; the order given is the order shown. Omit
   * to render every definition for the resource type.
   */
  definitionIds?: string[]
  /** Subset of `definitionIds` the type marks required — shown with a marker. */
  requiredDefinitionIds?: string[]
  children: ReactNode
}

export function FormBackedCustomFieldsProvider<T extends CustomFieldsFormShape>({
  form,
  resourceType,
  resourceLabel,
  definitionIds,
  requiredDefinitionIds,
  children,
}: FormBackedProviderProps<T>) {
  // The provider only ever touches the `custom_fields` field; narrow to the
  // shared shape so the field-path operations type-check uniformly regardless
  // of the concrete form `T`. Memoized on `form` so it's a stable dependency.
  const cfForm = useMemo(() => form as unknown as UseFormReturn<CustomFieldsFormShape>, [form])
  const { data: definitionsResponse, isLoading } = useCustomFieldDefinitions(resourceType)
  // Memoize against the fetched array's identity. Without this the `?? []`
  // fallback returns a fresh array on every render, which propagates into the
  // context value and triggers every consumer to re-render unnecessarily.
  const allDefinitions = useMemo(() => definitionsResponse?.data ?? [], [definitionsResponse?.data])
  // When a schema is supplied (the product's type), it decides both which
  // definitions appear and in what order.
  const definitions = useMemo(() => {
    if (!definitionIds) return allDefinitions

    return definitionIds.flatMap((id) => allDefinitions.filter((def) => def.id === id))
  }, [allDefinitions, definitionIds])

  const watchedCustomFields = cfForm.watch('custom_fields') ?? []
  const values = useMemo<Record<string, unknown>>(() => {
    const out: Record<string, unknown> = {}
    watchedCustomFields.forEach((cf) => {
      if (cf.custom_field_definition_id) out[cf.custom_field_definition_id] = cf.value
    })
    return out
  }, [watchedCustomFields])

  const setValue = useCallback(
    (definitionId: string, value: unknown) => {
      const current = cfForm.getValues('custom_fields') ?? []
      const idx = current.findIndex((cf) => cf.custom_field_definition_id === definitionId)
      const next: CustomFieldFormValues[] = [...current]
      if (idx === -1) {
        next.push({ custom_field_definition_id: definitionId, value })
      } else {
        next[idx] = { ...next[idx], value }
      }
      cfForm.setValue('custom_fields', next, { shouldDirty: true })
    },
    [cfForm],
  )

  const ctx = useMemo<CustomFieldsContextValue>(
    () => ({
      state: { values },
      actions: { setValue },
      meta: { definitions, isLoading, resourceType, resourceLabel, requiredDefinitionIds },
      mode: { kind: 'form' },
    }),
    [values, setValue, definitions, isLoading, resourceType, resourceLabel, requiredDefinitionIds],
  )

  return <CustomFieldsContext value={ctx}>{children}</CustomFieldsContext>
}

// ---------------------------------------------------------------------------
// API-backed drafts. Holds edits until `save()` batches every changed value to
// the /custom_fields endpoints (create or update per field, in parallel). Both
// API-backed providers below are built on it; a host form whose own Save
// should also persist custom fields (a settings sheet, a form page) calls
// `save()` from its submit handler and reads `isDirty` to enable that button.
// ---------------------------------------------------------------------------

export interface CustomFieldsDraft {
  ownerType: CustomFieldOwnerType
  resourceType: string
  definitions: CustomFieldDefinition[]
  isLoading: boolean
  canEdit: boolean
  loadFailed: boolean
  /** Persisted values with the unsaved edits applied, keyed by definition id. */
  values: Record<string, unknown>
  setValue: (definitionId: string, value: unknown) => void
  isDirty: boolean
  /** Drops the unsaved edits. */
  reset: () => void
  /**
   * Persists the changed values. Resolves `true` when everything saved, and
   * `false` after telling the user which fields did not — their edits are kept
   * so a retry only re-sends the failures. `announce` confirms a successful
   * save with a toast, for a host whose own record did not need saving (so its
   * own success toast never fires).
   */
  save: (options?: { announce?: boolean }) => Promise<boolean>
}

/**
 * @param ownerId empty while the owner has not been created yet; nothing loads
 *   and `save()` is a no-op until it has an id.
 */
export function useCustomFieldsDraft(
  ownerType: CustomFieldOwnerType,
  ownerId: string,
  resourceType: string = ownerType,
): CustomFieldsDraft {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const canEdit = permissions.can('update', ownerType)
  const { data: definitionsResponse, isLoading: defsLoading } =
    useCustomFieldDefinitions(resourceType)
  // Memoize against the fetched array's identity so consumers don't re-render
  // (or re-run effects) on every render.
  const definitions = useMemo(() => definitionsResponse?.data ?? [], [definitionsResponse?.data])
  // No values to read without a field to hold them, nor without edit access.
  const valuesOwnerId = canEdit && definitions.length > 0 ? ownerId : ''
  const {
    data: valuesResponse,
    isLoading: valuesLoading,
    isError: loadFailed,
    refetch,
  } = useCustomFields(ownerType, valuesOwnerId)
  const create = useCreateCustomField(ownerType, ownerId)
  const update = useUpdateCustomField(ownerType, ownerId)

  const savedValues = useMemo(() => valuesResponse?.data ?? [], [valuesResponse?.data])

  // definition id → persisted CustomField record (for update-by-id + baseline).
  const savedByDefinitionId = useMemo(() => {
    const out = new Map<string, CustomField>()
    for (const cf of savedValues) out.set(cf.custom_field_definition_id, cf)
    return out
  }, [savedValues])

  const [drafts, setDrafts] = useState<Record<string, unknown>>({})

  // A different owner (a sheet reused for the next row) starts clean.
  const [draftOwnerId, setDraftOwnerId] = useState(ownerId)
  if (draftOwnerId !== ownerId) {
    setDraftOwnerId(ownerId)
    setDrafts({})
  }

  const values = useMemo(() => {
    const out: Record<string, unknown> = {}
    savedByDefinitionId.forEach((cf, defId) => {
      out[defId] = cf.value
    })
    return { ...out, ...drafts }
  }, [savedByDefinitionId, drafts])

  // One entry per definition whose draft differs from the persisted value.
  const changedDefinitions = useMemo(
    () =>
      definitions.filter(
        (def) =>
          def.id in drafts && !valuesEqual(drafts[def.id], savedByDefinitionId.get(def.id)?.value),
      ),
    [definitions, drafts, savedByDefinitionId],
  )

  const setValue = useCallback((definitionId: string, value: unknown) => {
    setDrafts((prev) => ({ ...prev, [definitionId]: value }))
  }, [])

  const reset = useCallback(() => setDrafts({}), [])

  const save = useCallback(
    async ({ announce = false }: { announce?: boolean } = {}) => {
      if (!ownerId || loadFailed || changedDefinitions.length === 0) {
        setDrafts({})
        return true
      }

      const tasks = changedDefinitions.map((def) => {
        const draft = drafts[def.id]
        const existing = savedByDefinitionId.get(def.id)
        return existing
          ? () => update.mutateAsync({ id: existing.id, value: draft })
          : () => create.mutateAsync({ custom_field_definition_id: def.id, value: draft })
      })

      try {
        // allSettled (not all): a mid-batch failure must not orphan the fields
        // that already persisted. Refetch unconditionally so the baseline matches
        // the server, then report partial failures by field name.
        const results = await Promise.allSettled(tasks.map((task) => task()))
        await refetch()

        const failed = changedDefinitions.filter((_, i) => results[i].status === 'rejected')
        if (failed.length === 0) {
          setDrafts({})
          if (announce) {
            toastManager.add({
              type: 'success',
              title: t('admin.components.custom_fields.values_saved'),
            })
          }
          return true
        }

        toastManager.add({
          type: 'error',
          title: t('admin.components.custom_fields.values_save_partial_failed', {
            fields: failed.map((def) => def.label || def.key).join(', '),
          }),
        })
        return false
      } catch (err) {
        // refetch() itself failed (network) — the saves may still have landed.
        const message =
          err instanceof Error
            ? err.message
            : t('admin.components.custom_fields.errors.failed_to_save')
        toastManager.add({ type: 'error', title: message })
        return false
      }
    },
    [
      ownerId,
      loadFailed,
      changedDefinitions,
      drafts,
      savedByDefinitionId,
      create,
      update,
      refetch,
      t,
    ],
  )

  return useMemo(
    () => ({
      ownerType,
      resourceType,
      definitions,
      isLoading: defsLoading || (!!valuesOwnerId && valuesLoading),
      canEdit,
      loadFailed,
      values,
      setValue,
      isDirty: changedDefinitions.length > 0,
      reset,
      save,
    }),
    [
      ownerType,
      resourceType,
      definitions,
      defsLoading,
      valuesOwnerId,
      valuesLoading,
      canEdit,
      loadFailed,
      values,
      setValue,
      changedDefinitions,
      reset,
      save,
    ],
  )
}

// ---------------------------------------------------------------------------
// Provider B: host-saved API drafts (mode `form`). Fields are always editable;
// the host form's Save calls `draft.save()`. For settings sheets and form pages
// whose owner has no `custom_fields` write of its own.
// ---------------------------------------------------------------------------

interface DraftProviderProps {
  draft: CustomFieldsDraft
  /** Plural, human-readable resource name for empty-state copy. */
  resourceLabel?: string
  children: ReactNode
}

export function DraftCustomFieldsProvider({ draft, resourceLabel, children }: DraftProviderProps) {
  const ctx = useMemo<CustomFieldsContextValue>(
    () => ({
      state: { values: draft.values },
      actions: { setValue: draft.setValue },
      meta: {
        definitions: draft.definitions,
        isLoading: draft.isLoading,
        resourceType: draft.resourceType,
        resourceLabel,
        canEdit: draft.canEdit,
        loadFailed: draft.loadFailed,
      },
      mode: { kind: 'form' },
    }),
    [draft, resourceLabel],
  )

  return <CustomFieldsContext value={ctx}>{children}</CustomFieldsContext>
}

// ---------------------------------------------------------------------------
// Provider C: editable API-backed (display/edit mode).
// Default view is read-only; an explicit Edit reveals inputs and a card-level
// Save batches all changed values. No on-blur persistence — Save is the only
// write. For pages with no page-wide form (orders, customers).
// ---------------------------------------------------------------------------

interface EditableApiProviderProps {
  ownerType: CustomFieldOwnerType
  ownerId: string
  resourceType: string
  /** Plural, human-readable resource name for empty-state copy. */
  resourceLabel?: string
  children: ReactNode
}

export function EditableApiCustomFieldsProvider({
  ownerType,
  ownerId,
  resourceType,
  resourceLabel,
  children,
}: EditableApiProviderProps) {
  const draft = useCustomFieldsDraft(ownerType, ownerId, resourceType)
  const { reset, save: saveDraft } = draft

  const [isEditing, setIsEditing] = useState(false)
  const [saving, setSaving] = useState(false)

  const startEdit = useCallback(() => setIsEditing(true), [])

  const cancel = useCallback(() => {
    reset()
    setIsEditing(false)
  }, [reset])

  const save = useCallback(async () => {
    if (!draft.isDirty) {
      cancel()
      return
    }

    setSaving(true)
    try {
      // On a partial failure edit mode stays open with the drafts intact.
      if (await saveDraft({ announce: true })) setIsEditing(false)
    } finally {
      setSaving(false)
    }
  }, [draft.isDirty, cancel, saveDraft])

  const ctx = useMemo<CustomFieldsContextValue>(
    () => ({
      state: { values: draft.values },
      actions: { setValue: draft.setValue },
      meta: {
        definitions: draft.definitions,
        isLoading: draft.isLoading,
        resourceType,
        resourceLabel,
        canEdit: draft.canEdit,
        loadFailed: draft.loadFailed,
      },
      mode: { kind: 'editable', isEditing, saving, startEdit, cancel, save },
    }),
    [draft, resourceType, resourceLabel, isEditing, saving, startEdit, cancel, save],
  )

  return <CustomFieldsContext value={ctx}>{children}</CustomFieldsContext>
}

/** The card on a detail page with no page-wide form: read-only until Edit, with its own Save. */
export function ApiCustomFieldsCard({
  ownerType,
  ownerId,
  hideWhenEmpty,
}: {
  ownerType: CustomFieldOwnerType
  ownerId: string
  hideWhenEmpty?: boolean
}) {
  return (
    <EditableApiCustomFieldsProvider
      ownerType={ownerType}
      ownerId={ownerId}
      resourceType={ownerType}
    >
      <CustomFieldsInlineCard hideWhenEmpty={hideWhenEmpty} />
    </EditableApiCustomFieldsProvider>
  )
}

/** The card inside a host form that saves `draft` from its own submit. */
export function DraftCustomFieldsCard({
  draft,
  hideWhenEmpty,
}: {
  draft: CustomFieldsDraft
  hideWhenEmpty?: boolean
}) {
  return (
    <DraftCustomFieldsProvider draft={draft}>
      <CustomFieldsInlineCard hideWhenEmpty={hideWhenEmpty} />
    </DraftCustomFieldsProvider>
  )
}

// ---------------------------------------------------------------------------
// The card — implementation-agnostic. Reads context only.
// ---------------------------------------------------------------------------

interface CustomFieldsInlineCardProps {
  /**
   * Renders nothing until the store defines a field for this resource. For
   * sheets and secondary surfaces, where an empty card is clutter; fields are
   * defined in Settings, which offers every resource with an edit surface.
   */
  hideWhenEmpty?: boolean
}

export function CustomFieldsInlineCard({ hideWhenEmpty = false }: CustomFieldsInlineCardProps) {
  const { t } = useTranslation()
  const [createOpen, setCreateOpen] = useState(false)
  const {
    meta: { isLoading, definitions, resourceType, resourceLabel, canEdit, loadFailed },
    mode,
  } = useCustomFieldsContext()

  // Form mode always edits inline; editable mode edits only while `isEditing`.
  const editing = mode.kind === 'form' || mode.isEditing
  const hasDefinitions = definitions.length > 0
  const openCreate = useCallback(() => setCreateOpen(true), [])

  if (canEdit === false || (hideWhenEmpty && !hasDefinitions)) return null

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0">
        <CardTitle>
          <SquareTextIcon className="size-4" />
          {t('admin.components.custom_fields.section_title')}
        </CardTitle>
        {!isLoading && !loadFailed && hasDefinitions && <EditableHeaderActions />}
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <LoadingRows />
        ) : loadFailed ? (
          <p className="text-sm text-destructive" role="alert">
            {t('admin.components.custom_fields.errors.failed_to_load')}
          </p>
        ) : !hasDefinitions ? (
          <CustomFieldsEmptyState onSetUp={openCreate} />
        ) : editing ? (
          <FieldsEditor onSetUp={openCreate} />
        ) : (
          <FieldsDisplay />
        )}
      </CardContent>

      <CreateDefinitionSheet
        open={createOpen}
        onOpenChange={setCreateOpen}
        resourceType={resourceType}
        resourceLabel={resourceLabel}
      />
    </Card>
  )
}

// Edit / Cancel+Save buttons — only rendered in editable mode. Reads the mode
// off context so the card body stays a thin selector.
function EditableHeaderActions() {
  const { t } = useTranslation()
  const { mode } = useCustomFieldsContext()
  if (mode.kind !== 'editable') return null

  if (!mode.isEditing) {
    return (
      <Button
        variant="ghost"
        size="icon-sm"
        type="button"
        onClick={mode.startEdit}
        aria-label={t('admin.actions.edit')}
      >
        <PencilIcon className="size-4" />
      </Button>
    )
  }

  return (
    <div className="flex items-center gap-2">
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={mode.cancel}
        disabled={mode.saving}
      >
        {t('admin.actions.cancel')}
      </Button>
      <Button type="button" size="sm" onClick={mode.save} disabled={mode.saving}>
        {mode.saving && <Loader2Icon className="size-4 animate-spin" />}
        <span>{t('admin.actions.save')}</span>
      </Button>
    </div>
  )
}

function LoadingRows() {
  return (
    <div className="flex flex-col gap-2">
      <Skeleton className="h-4 w-3/4" />
      <Skeleton className="h-4 w-1/2" />
    </div>
  )
}

// No definitions yet: create one in place (sheet) or jump to the settings list.
function CustomFieldsEmptyState({ onSetUp }: { onSetUp: () => void }) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  return (
    <Empty className="border-0 p-0">
      <EmptyHeader>
        <EmptyMedia variant="icon">
          <TagIcon />
        </EmptyMedia>
        <EmptyTitle>{t('admin.components.custom_fields.empty_title')}</EmptyTitle>
        <EmptyDescription>{t('admin.components.custom_fields.empty_description')}</EmptyDescription>
      </EmptyHeader>
      <EmptyContent className="gap-1">
        <Button type="button" variant="outline" size="sm" onClick={onSetUp}>
          <PlusIcon className="size-4" />
          {t('admin.components.custom_fields.set_up')}
        </Button>
        <Button asChild type="button" variant="link" size="sm">
          <Link to="/$storeId/settings/custom-field-definitions" params={{ storeId }}>
            {t('admin.components.custom_fields.manage_in_settings')}
          </Link>
        </Button>
      </EmptyContent>
    </Empty>
  )
}

// Editable rows. In editable mode a footer lets the user define another field
// in place; form mode persists via the page's own Save, so no footer there.
function FieldsEditor({ onSetUp }: { onSetUp: () => void }) {
  const { t } = useTranslation()
  const {
    state: { values },
    actions: { setValue },
    meta: { definitions, requiredDefinitionIds },
    mode,
  } = useCustomFieldsContext()

  return (
    <div className="flex flex-col gap-4">
      {definitions.map((def) => (
        <CustomFieldRow
          key={def.id}
          definition={def}
          required={requiredDefinitionIds?.includes(def.id)}
          value={values[def.id]}
          onChange={(next) => setValue(def.id, next)}
        />
      ))}
      {mode.kind === 'editable' && (
        <div className="border-t pt-3">
          <Button type="button" variant="ghost" size="sm" onClick={onSetUp}>
            <PlusIcon className="size-4" />
            {t('admin.components.custom_fields.set_up')}
          </Button>
        </div>
      )}
    </div>
  )
}

// Read-only value grid (editable mode, not editing).
function FieldsDisplay() {
  const {
    state: { values },
    meta: { definitions },
  } = useCustomFieldsContext()
  return (
    <dl className="grid grid-cols-[minmax(140px,1fr)_2fr] gap-x-4 gap-y-2 text-sm">
      {definitions.map((def) => (
        <CustomFieldDisplayRow key={def.id} definition={def} value={values[def.id]} />
      ))}
    </dl>
  )
}

// ---------------------------------------------------------------------------
// Read-only display row (editable mode, not editing). Shows the formatted value
// or an em-dash placeholder.
// ---------------------------------------------------------------------------

function CustomFieldDisplayRow({
  definition,
  value,
}: {
  definition: CustomFieldDefinition
  value: unknown
}) {
  const { t } = useTranslation()
  const friendlyLabel = definition.label || definition.key
  const technicalKey = `${definition.namespace}.${definition.key}`

  return (
    <>
      <dt className="font-medium text-muted-foreground" title={technicalKey}>
        {friendlyLabel}
      </dt>
      <dd className="break-words text-foreground/90">
        {formatDisplayValue(value, definition.field_type, t)}
      </dd>
    </>
  )
}

// Compact, read-only rendering of a stored value for the display grid.
function formatDisplayValue(value: unknown, fieldType: string, t: (key: string) => string): string {
  const empty = t('admin.common.empty_value')
  if (value === null || value === undefined || value === '') return empty
  if (fieldType === 'boolean') return value ? t('admin.common.yes') : t('admin.common.no')
  if (fieldType === 'rich_text' && typeof value === 'string') {
    // Plain-text preview of HTML. DOMParser handles nested/malformed tags
    // correctly — a single-pass regex strip can leak tags via patterns like
    // `<scr<script>ipt>` (CodeQL js/incomplete-multi-character-sanitization).
    const text = new DOMParser().parseFromString(value, 'text/html').body.textContent ?? ''
    return text.trim() || empty
  }
  if (fieldType === 'json') return typeof value === 'string' ? value : JSON.stringify(value)
  return String(value)
}

// ---------------------------------------------------------------------------
// In-place create-definition sheet. Pre-fills (and hides) the resource type —
// the card already knows its owner. On success it closes; the create mutation
// invalidates the definitions query so the card re-renders with the new field
// ready to edit. Lives inside the card's <Card> but renders into a portal, so
// the parent product/category <form> never wraps it; the submit handler still
// stops propagation defensively (React bubbles synthetic events through the
// component tree even across the portal).
// ---------------------------------------------------------------------------

interface CreateDefinitionSheetProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  resourceType: string
  resourceLabel?: string
}

function CreateDefinitionSheet({
  open,
  onOpenChange,
  resourceType,
  resourceLabel,
}: CreateDefinitionSheetProps) {
  const { t } = useTranslation()
  const create = useCreateCustomFieldDefinition(resourceType)
  const form = useForm<CustomFieldDefinitionFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customFieldDefinitionSchema) as any,
    defaultValues: { ...CUSTOM_FIELD_DEFINITION_DEFAULTS, resource_type: resourceType },
  })

  const resetForm = useCallback(
    () => form.reset({ ...CUSTOM_FIELD_DEFINITION_DEFAULTS, resource_type: resourceType }),
    [form, resourceType],
  )

  async function onSubmit(values: CustomFieldDefinitionFormValues) {
    try {
      await create.mutateAsync(
        customFieldDefinitionValuesToCreateParams({ ...values, resource_type: resourceType }),
      )
      resetForm()
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', {
          type: 'server',
          message: err instanceof Error ? err.message : t('admin.errors.unexpected'),
        })
      }
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) resetForm()
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.components.custom_fields.new_definition_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.components.custom_fields.new_definition_description', {
              resource: resourceLabel ?? t('admin.components.custom_fields.default_resource'),
            })}
          </SheetDescription>
        </SheetHeader>
        <form
          // The sheet portals to document.body (outside the React root), but
          // React still bubbles the synthetic submit up the fiber tree, so a
          // parent product/category <form>'s onSubmit would also fire. Stop the
          // synthetic bubble — but in the BUBBLE phase, AFTER handleSubmit runs.
          // A capture-phase stopPropagation kills native propagation before it
          // reaches React's root-delegated listener, so handleSubmit (and its
          // preventDefault) never runs and the browser does a native page reload.
          onSubmit={(e) => {
            e.stopPropagation()
            form.handleSubmit(onSubmit)(e)
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <DefinitionFormFields form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              // Reset through the same path as the Sheet's onOpenChange wrapper
              // so reopening doesn't show stale input or server errors.
              onClick={() => {
                resetForm()
                onOpenChange(false)
              }}
              disabled={create.isPending}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={create.isPending}>
              {create.isPending && <Loader2Icon className="size-4 animate-spin" />}
              <span>{t('admin.custom_field_definitions.create_label')}</span>
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Per-definition input row. Picks the widget by field_type. Edits flow to the
// draft via onChange only — persistence is deferred to the page form's Save
// (form mode) or the card's Save (editable mode). No on-blur/immediate commit.
// ---------------------------------------------------------------------------

interface CustomFieldRowProps {
  definition: CustomFieldDefinition
  /**
   * The product type marks this field required. Advisory: it renders a marker,
   * and nothing rejects a blank value — see Spree::Product.
   */
  required?: boolean
  value: unknown
  onChange: (value: unknown) => void
}

// The product type's `required` flag is guidance, not a rule the API enforces
// (Shopify behaves the same way), so this marks the field without blocking any
// save.
function RequiredMarker() {
  const { t } = useTranslation()
  return (
    <span
      className="ml-0.5 text-muted-foreground"
      title={t('admin.components.custom_fields.required_hint')}
    >
      *
    </span>
  )
}

function CustomFieldRow({ definition, required, value, onChange }: CustomFieldRowProps) {
  const inputId = `custom-field-${definition.id}`
  const friendlyLabel = definition.label || definition.key
  // The `namespace.key` identifier matters to developers / API consumers but
  // is visual noise on the merchant editor surface (Saleor/Shopify both hide
  // it on the value editor). Keep it discoverable via native tooltip on the
  // label, not rendered as inline copy.
  const technicalKey = `${definition.namespace}.${definition.key}`

  // A plugin can replace the input for this specific definition
  // (customFieldComponents.register('specs.color', ColorPicker)); the default
  // field_type widget renders otherwise. Same controlled contract either way
  // — persistence stays with the card's provider.
  const CustomComponent = customFieldComponents.get(technicalKey)
  const widget = CustomComponent ? (
    <CustomComponent
      id={inputId}
      ariaLabel={friendlyLabel}
      value={value}
      onChange={onChange}
      definition={definition}
    />
  ) : (
    <CustomFieldWidget
      id={inputId}
      ariaLabel={friendlyLabel}
      fieldType={definition.field_type}
      value={value}
      onChange={onChange}
    />
  )

  // Booleans read as a horizontal label-left / switch-right row (matching the
  // definition form and Shopify/Saleor). The vertical `Field` layout forces
  // `*:w-full` on its children, which would stretch the compact switch across
  // the row — so the toggle gets its own justified wrapper instead.
  if (definition.field_type === 'boolean') {
    return (
      <Field>
        <div className="flex items-center justify-between gap-4">
          <FieldLabel htmlFor={inputId} title={technicalKey} className="cursor-pointer">
            {friendlyLabel}
            {required && <RequiredMarker />}
          </FieldLabel>
          {widget}
        </div>
      </Field>
    )
  }

  return (
    <Field>
      <FieldLabel htmlFor={inputId} title={technicalKey}>
        {friendlyLabel}
        {required && <RequiredMarker />}
      </FieldLabel>
      {widget}
    </Field>
  )
}

interface CustomFieldWidgetProps {
  id: string
  ariaLabel: string
  fieldType: string
  value: unknown
  onChange: (value: unknown) => void
}

function CustomFieldWidget({ id, ariaLabel, fieldType, value, onChange }: CustomFieldWidgetProps) {
  switch (fieldType) {
    case 'short_text':
      return (
        <Input
          id={id}
          aria-label={ariaLabel}
          value={(value as string | null | undefined) ?? ''}
          onChange={(e) => onChange(e.target.value)}
        />
      )
    case 'long_text':
      return (
        <Textarea
          id={id}
          aria-label={ariaLabel}
          rows={4}
          value={(value as string | null | undefined) ?? ''}
          onChange={(e) => onChange(e.target.value)}
        />
      )
    case 'rich_text':
      return (
        <RichTextEditor
          id={id}
          ariaLabel={ariaLabel}
          value={(value as string | null | undefined) ?? ''}
          onChange={(html: string) => onChange(html)}
        />
      )
    case 'number':
      return (
        <Input
          id={id}
          aria-label={ariaLabel}
          type="number"
          step="any"
          value={value == null ? '' : String(value)}
          onChange={(e) => {
            const v = e.target.value
            if (v === '') {
              onChange(null)
              return
            }
            // `<input type="number">` sanitizes invalid input to "" in most
            // browsers, but Safari and some locale-quirk paths can yield a
            // non-empty unparseable string ("1,5" in de-DE). Coercing with
            // Number() there produces NaN, which would flow into form state and
            // the API. Hold the previous value instead so a transient bad
            // keystroke can't corrupt state; backspacing to "" falls to null.
            const parsed = Number(v)
            if (Number.isNaN(parsed)) return
            onChange(parsed)
          }}
        />
      )
    case 'boolean':
      return (
        <Switch
          id={id}
          aria-label={ariaLabel}
          checked={Boolean(value)}
          onCheckedChange={(checked) => onChange(checked)}
        />
      )
    case 'json':
      return (
        <Textarea
          id={id}
          aria-label={ariaLabel}
          rows={6}
          className="font-mono text-xs"
          value={
            value == null ? '' : typeof value === 'string' ? value : JSON.stringify(value, null, 2)
          }
          onChange={(e) => onChange(e.target.value)}
          onBlur={(e) => {
            // Normalize on blur (no persistence): parse JSON so the draft holds
            // the canonical value the API expects. Leave an unparseable string
            // as-is — Save will surface the server's validation error.
            const raw = e.target.value.trim()
            if (!raw) {
              onChange(null)
              return
            }
            try {
              onChange(JSON.parse(raw))
            } catch {
              onChange(raw)
            }
          }}
        />
      )
    default:
      return null
  }
}
