// Inline custom-fields editor — generic-context shape, two providers.
//
// The card is purely presentational and reads everything from context. State
// is dependency-injected by the provider above it: `FormBackedProvider` writes
// to a parent product form (works pre-save), `ApiBackedProvider` reads/writes
// the dedicated /custom_fields endpoints (commit-on-blur for existing
// products). Same UI, swappable behaviour.
//
// Composition refs:
// - state-context-interface: `{ state, actions, meta }`
// - state-decouple-implementation: card never touches the form or the SDK
// - patterns-explicit-variants: two named providers, no `mode` prop
//
// See packages/dashboard/src/components/spree/custom-fields/ for the full
// drawer that we're replacing; this lives next to it until call sites flip.

import type { CustomField, CustomFieldDefinition, CustomFieldOwnerType } from '@spree/admin-sdk'
import {
  useCreateCustomField,
  useCustomFieldDefinitions,
  useCustomFields,
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
  Skeleton,
  Switch,
  Textarea,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { TagIcon } from 'lucide-react'
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import type { CustomFieldFormValues, ProductFormValues } from '@/schemas/product'

// ---------------------------------------------------------------------------
// Generic context interface — providers implement this, the card consumes it.
// ---------------------------------------------------------------------------

interface CustomFieldsState {
  /** Draft values keyed by definition id. Always reflects what the UI shows. */
  values: Record<string, unknown>
  /** Definition ids whose commit is currently in-flight (per-field spinner). */
  pending: Set<string>
}

interface CustomFieldsActions {
  /** Update the draft value for a definition. Doesn't necessarily persist. */
  setValue: (definitionId: string, value: unknown) => void
  /**
   * Persist the value for this definition. No-op for form-backed.
   *
   * `nextValue` lets immediate-save widgets (boolean toggle, JSON blur)
   * pass the just-changed value directly — React hasn't flushed `setValue`
   * by the time `commit()` runs back-to-back with `onChange()`, so reading
   * the draft from state would persist the previous value. When omitted,
   * the current draft from state is used (commit-on-blur from text/number
   * widgets, where the blur already saw the post-render state).
   */
  commit: (definitionId: string, nextValue?: unknown) => Promise<void>
}

interface CustomFieldsMeta {
  definitions: CustomFieldDefinition[]
  isLoading: boolean
}

interface CustomFieldsContextValue {
  state: CustomFieldsState
  actions: CustomFieldsActions
  meta: CustomFieldsMeta
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
// wrong for JSON metafields because each query refetch hands back a fresh
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
// Provider A: form-backed.
// Reads from / writes to `form.values.custom_fields[]`. `commit` is a no-op —
// the parent product form save flushes everything.
// ---------------------------------------------------------------------------

interface FormBackedProviderProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  resourceType: string
  children: ReactNode
}

export function FormBackedCustomFieldsProvider({
  form,
  resourceType,
  children,
}: FormBackedProviderProps) {
  const { data: definitionsResponse, isLoading } = useCustomFieldDefinitions(resourceType)
  // Memoize against the fetched array's identity. Without this the `?? []`
  // fallback returns a fresh array on every render, which propagates into the
  // context value and triggers every consumer to re-render unnecessarily.
  const definitions = useMemo(() => definitionsResponse?.data ?? [], [definitionsResponse?.data])

  const watchedCustomFields = form.watch('custom_fields') ?? []
  const values = useMemo<Record<string, unknown>>(() => {
    const out: Record<string, unknown> = {}
    watchedCustomFields.forEach((cf) => {
      if (cf.custom_field_definition_id) out[cf.custom_field_definition_id] = cf.value
    })
    return out
  }, [watchedCustomFields])

  const setValue = useCallback(
    (definitionId: string, value: unknown) => {
      const current = form.getValues('custom_fields') ?? []
      const idx = current.findIndex((cf) => cf.custom_field_definition_id === definitionId)
      const next: CustomFieldFormValues[] = [...current]
      if (idx === -1) {
        next.push({ custom_field_definition_id: definitionId, value })
      } else {
        next[idx] = { ...next[idx], value }
      }
      form.setValue('custom_fields', next, { shouldDirty: true })
    },
    [form],
  )

  // Form-backed scope persists via the parent form save — commit is just
  // surface for the API-backed twin so the card stays implementation-agnostic.
  const commit = useCallback(async () => {}, [])

  const ctx = useMemo<CustomFieldsContextValue>(
    () => ({
      state: { values, pending: new Set() },
      actions: { setValue, commit },
      meta: { definitions, isLoading },
    }),
    [values, setValue, commit, definitions, isLoading],
  )

  return <CustomFieldsContext value={ctx}>{children}</CustomFieldsContext>
}

// ---------------------------------------------------------------------------
// Provider B: API-backed.
// Reads via `useCustomFields`, writes via per-field create/update mutations on
// commit. Local draft state lets the cell show the user's keystrokes without
// flickering on every server round-trip.
// ---------------------------------------------------------------------------

interface ApiBackedProviderProps {
  ownerType: CustomFieldOwnerType
  ownerId: string
  resourceType: string
  children: ReactNode
}

export function ApiBackedCustomFieldsProvider({
  ownerType,
  ownerId,
  resourceType,
  children,
}: ApiBackedProviderProps) {
  const { data: definitionsResponse, isLoading: defsLoading } =
    useCustomFieldDefinitions(resourceType)
  const { data: valuesResponse, isLoading: valuesLoading } = useCustomFields(ownerType, ownerId)
  const create = useCreateCustomField(ownerType, ownerId)
  const update = useUpdateCustomField(ownerType, ownerId)

  // Memoize against the fetched array's identity. Without this the `?? []`
  // fallback returns a fresh array on every render, the `useEffect` that
  // seeds `drafts` re-runs every render → setState → re-render loop →
  // "Maximum update depth exceeded".
  const definitions = useMemo(() => definitionsResponse?.data ?? [], [definitionsResponse?.data])
  const savedValues = useMemo(() => valuesResponse?.data ?? [], [valuesResponse?.data])

  // Map definition id → existing CustomField record (for update by id) and to
  // the persisted value (the baseline against which `commit` decides whether
  // to call create or update).
  const savedByDefinitionId = useMemo(() => {
    const out = new Map<string, CustomField>()
    savedValues.forEach((cf) => {
      out.set(cf.custom_field_definition_id, cf)
    })
    return out
  }, [savedValues])

  // Local drafts let the user type freely without firing a request per
  // keystroke. Initialised from the persisted values; per-field commit flushes
  // back to the server. The card calls `commit` on blur for text inputs and
  // immediately for booleans.
  const [drafts, setDrafts] = useState<Record<string, unknown>>({})
  const [pending, setPending] = useState<Set<string>>(() => new Set())

  // Seed drafts whenever the saved values change (initial load + refetch).
  // Keys the user has actively edited (i.e. already in `drafts`) stay put.
  useEffect(() => {
    setDrafts((prev) => {
      const next: Record<string, unknown> = { ...prev }
      savedValues.forEach((cf) => {
        if (!(cf.custom_field_definition_id in next)) {
          next[cf.custom_field_definition_id] = cf.value
        }
      })
      return next
    })
  }, [savedValues])

  const setValue = useCallback((definitionId: string, value: unknown) => {
    setDrafts((prev) => ({ ...prev, [definitionId]: value }))
  }, [])

  const draftsRef = useRef(drafts)
  draftsRef.current = drafts

  // Local cache of records the merchant just created in this session. The
  // `useCustomFields` query needs a refetch round-trip before
  // `savedByDefinitionId` sees them, so a second blur on the same field
  // would otherwise re-enter the create branch and produce a duplicate.
  // Refilled on every save; the auth-backed mutation handles invalidation
  // so the cache merges cleanly when the refetch lands.
  const justSavedRef = useRef<Map<string, { id: string; value: unknown }>>(new Map())

  const commit = useCallback(
    async (definitionId: string, nextValue?: unknown) => {
      // Prefer the explicit `nextValue` (immediate-save widgets pass the
      // just-changed value directly because React hasn't flushed setDrafts
      // yet). Fall back to the current draft from state for commit-on-blur.
      const draft = nextValue === undefined ? draftsRef.current[definitionId] : nextValue
      const existing =
        savedByDefinitionId.get(definitionId) ?? justSavedRef.current.get(definitionId)
      const savedValue = existing?.value
      if (valuesEqual(draft, savedValue)) return // unchanged

      setPending((prev) => new Set(prev).add(definitionId))
      try {
        if (existing) {
          const updated = await update.mutateAsync({ id: existing.id, value: draft })
          justSavedRef.current.set(definitionId, { id: existing.id, value: updated.value })
        } else {
          const created = await create.mutateAsync({
            custom_field_definition_id: definitionId,
            value: draft,
          })
          justSavedRef.current.set(definitionId, { id: created.id, value: created.value })
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to save custom field'
        toast.error(message)
        // Roll the draft back to the persisted value so the next render
        // matches the server's truth.
        setDrafts((prev) => ({ ...prev, [definitionId]: savedValue }))
      } finally {
        setPending((prev) => {
          const next = new Set(prev)
          next.delete(definitionId)
          return next
        })
      }
    },
    [create, update, savedByDefinitionId],
  )

  const ctx = useMemo<CustomFieldsContextValue>(
    () => ({
      state: { values: drafts, pending },
      actions: { setValue, commit },
      meta: { definitions, isLoading: defsLoading || valuesLoading },
    }),
    [drafts, pending, setValue, commit, definitions, defsLoading, valuesLoading],
  )

  return <CustomFieldsContext value={ctx}>{children}</CustomFieldsContext>
}

// ---------------------------------------------------------------------------
// The card — implementation-agnostic. Reads context only.
// ---------------------------------------------------------------------------

export function CustomFieldsInlineCard() {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const {
    state: { values, pending },
    actions: { setValue, commit },
    meta: { definitions, isLoading },
  } = useCustomFieldsContext()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.section_custom_fields')}</CardTitle>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="flex flex-col gap-2">
            <Skeleton className="h-4 w-3/4" />
            <Skeleton className="h-4 w-1/2" />
          </div>
        ) : definitions.length === 0 ? (
          <Empty className="border-0 p-0">
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <TagIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.products.custom_fields.empty_title')}</EmptyTitle>
              <EmptyDescription>
                {t('admin.products.custom_fields.empty_description')}
              </EmptyDescription>
            </EmptyHeader>
            <EmptyContent>
              <Button asChild type="button" variant="outline" size="sm">
                <Link to="/$storeId/settings/custom-field-definitions" params={{ storeId }}>
                  {t('admin.products.custom_fields.empty_cta')}
                </Link>
              </Button>
            </EmptyContent>
          </Empty>
        ) : (
          <div className="flex flex-col gap-4">
            {definitions.map((def) => (
              <CustomFieldRow
                key={def.id}
                definition={def}
                value={values[def.id]}
                pending={pending.has(def.id)}
                onChange={(next) => setValue(def.id, next)}
                onCommit={(nextValue) => commit(def.id, nextValue)}
              />
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Per-definition input. Picks the right widget by field_type and routes the
// commit moment appropriately (immediate for boolean, on-blur for text/number).
// ---------------------------------------------------------------------------

interface CustomFieldRowProps {
  definition: CustomFieldDefinition
  value: unknown
  pending: boolean
  onChange: (value: unknown) => void
  onCommit: (nextValue?: unknown) => void | Promise<void>
}

function CustomFieldRow({ definition, value, pending, onChange, onCommit }: CustomFieldRowProps) {
  const inputId = `custom-field-${definition.id}`
  const friendlyLabel = definition.label || definition.key
  // The `namespace.key` identifier matters to developers / API consumers but
  // is visual noise on the merchant editor surface (Saleor/Shopify both hide
  // it on the value editor). Keep it discoverable via native tooltip on the
  // label, not rendered as inline copy.
  const technicalKey = `${definition.namespace}.${definition.key}`

  return (
    <Field>
      <FieldLabel htmlFor={inputId} title={technicalKey} className="flex items-baseline gap-2">
        <span>{friendlyLabel}</span>
        {pending && <span className="text-xs text-muted-foreground">…</span>}
      </FieldLabel>
      <CustomFieldWidget
        id={inputId}
        ariaLabel={friendlyLabel}
        fieldType={definition.field_type}
        value={value}
        onChange={onChange}
        onCommit={onCommit}
      />
    </Field>
  )
}

interface CustomFieldWidgetProps {
  id: string
  ariaLabel: string
  fieldType: string
  value: unknown
  onChange: (value: unknown) => void
  /**
   * Persist the value. Accepts an optional `nextValue` for immediate-save
   * widgets (boolean, JSON-on-blur) where onChange + onCommit run back to
   * back — React hasn't flushed the draft state yet, so re-reading from
   * state would persist the previous value.
   */
  onCommit: (nextValue?: unknown) => void | Promise<void>
}

function CustomFieldWidget({
  id,
  ariaLabel,
  fieldType,
  value,
  onChange,
  onCommit,
}: CustomFieldWidgetProps) {
  switch (fieldType) {
    case 'short_text':
      return (
        <Input
          id={id}
          aria-label={ariaLabel}
          value={(value as string | null | undefined) ?? ''}
          onChange={(e) => onChange(e.target.value)}
          onBlur={() => onCommit()}
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
          onBlur={() => onCommit()}
        />
      )
    case 'rich_text':
      return (
        <RichTextEditor
          value={(value as string | null | undefined) ?? ''}
          onChange={(html) => onChange(html)}
          onBlur={() => onCommit()}
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
            // Number() in those cases produces NaN, which then flows into
            // form state and through the API. Hold the previous value
            // instead so a transient bad keystroke can't corrupt state;
            // when the user backspaces back to "" we fall through to null.
            const parsed = Number(v)
            if (Number.isNaN(parsed)) return
            onChange(parsed)
          }}
          onBlur={() => onCommit()}
        />
      )
    case 'boolean':
      return (
        <Switch
          id={id}
          aria-label={ariaLabel}
          checked={Boolean(value)}
          onCheckedChange={(checked) => {
            onChange(checked)
            // Booleans commit immediately — there's no "typing" phase.
            // Pass the next value so commit doesn't re-read stale draft state.
            void onCommit(checked)
          }}
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
            const raw = e.target.value.trim()
            // Pre-parse so we can pass the canonical value to commit(). React
            // hasn't flushed onChange's setDrafts yet, so re-reading from
            // state would persist the pre-parse string.
            let parsed: unknown
            if (!raw) {
              parsed = null
            } else {
              try {
                parsed = JSON.parse(raw)
              } catch {
                parsed = raw // leave raw string; commit will surface server error
              }
            }
            onChange(parsed)
            void onCommit(parsed)
          }}
        />
      )
    default:
      return null
  }
}
