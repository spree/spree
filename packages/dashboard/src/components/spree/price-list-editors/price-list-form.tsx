import { zodResolver } from '@hookform/resolvers/zod'
import type { PriceList, PriceRule, ResourceTypeDefinition } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  formatStoreDateTime,
  PageHeader,
  PreferencesForm,
  ResourceMultiAutocomplete,
  useStore,
} from '@spree/dashboard-core'
import { useConfirm } from '@spree/dashboard-ui'
import {
  CalendarOffIcon,
  PauseIcon,
  PencilIcon,
  PlayIcon,
  PlusIcon,
  TableIcon,
  TrashIcon,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { BulkPriceEditorDialog } from '@/components/spree/bulk-price-editor/bulk-price-editor-dialog'
import { PriceListStatusBadge } from '@/components/spree/price-list-editors/status-badge'
// Side-effect import — registers per-rule editors (customer, customer
// group, …) into the slot registry. Must run before any RuleEditSheet
// mounts.
import '@/components/spree/price-list-editors/register'
import { mapSpreeErrorsToForm, Slot, StoreDatePicker, Subject } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Textarea,
} from '@spree/dashboard-ui'
import {
  type PriceRuleEditorContext,
  ruleFormSlot,
} from '@/components/spree/price-list-editors/types'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import {
  useActivatePriceList,
  useDeactivatePriceList,
  usePriceRuleTypes,
} from '@/hooks/use-price-lists'
import {
  MATCH_POLICIES,
  PRICE_LIST_DEFAULTS,
  type PriceListFormValues,
  type PriceRuleFormDraft,
  priceListFormSchema,
  priceListValuesToParams,
  ruleDraftFromRule,
  ruleDraftFromType,
} from '@/schemas/price-list'

// =============================================================================
// Public API
// =============================================================================

interface PriceListFormProps {
  mode: 'create' | 'edit'
  /** Existing record (edit mode only). */
  priceList?: PriceList
  /** Existing rules (edit mode only) — fetched separately, the price list serializer doesn't embed them by default. */
  initialRules?: PriceRule[]
  /** Called on Save. Receives the full payload — rules included. */
  onSubmit: (payload: ReturnType<typeof priceListValuesToParams>) => Promise<void>
  /** Edit-mode only: when supplied, the header gains a Delete button. */
  onDelete?: () => void
  deletePending?: boolean
}

// =============================================================================
// Component
// =============================================================================

export function PriceListForm({
  mode,
  priceList,
  initialRules,
  onSubmit,
  onDelete,
  deletePending = false,
}: PriceListFormProps) {
  const { t } = useTranslation()

  const form = useForm<PriceListFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(priceListFormSchema) as any,
    defaultValues: PRICE_LIST_DEFAULTS,
  })

  const rulesArray = useFieldArray<PriceListFormValues, 'rules', '_key'>({
    control: form.control,
    name: 'rules',
    keyName: '_key',
  })

  // biome-ignore lint/correctness/useExhaustiveDependencies: form is stable
  useEffect(() => {
    if (mode !== 'edit') return
    if (!priceList || !initialRules) return
    form.reset({
      name: priceList.name,
      description: priceList.description ?? '',
      starts_at: priceList.starts_at,
      ends_at: priceList.ends_at,
      match_policy: (priceList.match_policy as 'all' | 'any') ?? 'all',
      rules: initialRules.map(ruleDraftFromRule),
      product_ids: priceList.product_ids ?? [],
    })
  }, [mode, priceList, initialRules])

  async function handleSubmit(values: PriceListFormValues) {
    try {
      await onSubmit(priceListValuesToParams(values))
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const isLoading = mode === 'edit' && (!priceList || !initialRules)
  if (isLoading) {
    return (
      <ResourceLayout
        header={<PageHeader title={t('admin.common.loading')} backTo="products/price-lists" />}
        main={<div className="text-sm text-muted-foreground">{t('admin.common.loading')}</div>}
      />
    )
  }

  return (
    <form onSubmit={form.handleSubmit(handleSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={
              mode === 'create'
                ? t('admin.pages.products.price_lists.sheet_title_create')
                : (priceList?.name ?? '')
            }
            backTo="products/price-lists"
            badges={priceList && <PriceListStatusBadge priceList={priceList} />}
            actions={
              <div className="flex gap-2">
                {mode === 'edit' && priceList && <ActivationButtons priceList={priceList} />}
                {mode === 'edit' && onDelete && (
                  <Can I="destroy" a={Subject.PriceList}>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      onClick={onDelete}
                      disabled={deletePending}
                      className="text-destructive hover:bg-destructive/10 hover:text-destructive"
                    >
                      {t('admin.actions.delete')}
                    </Button>
                  </Can>
                )}
                <Button
                  type="submit"
                  size="sm"
                  disabled={
                    form.formState.isSubmitting || (mode === 'edit' && !form.formState.isDirty)
                  }
                >
                  {form.formState.isSubmitting
                    ? mode === 'create'
                      ? t('admin.actions.creating')
                      : t('admin.actions.saving')
                    : mode === 'create'
                      ? t('admin.actions.create')
                      : t('admin.actions.save')}
                </Button>
              </div>
            }
          />
        }
        main={
          <>
            {form.formState.errors.root?.message && (
              <p
                className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
                role="alert"
              >
                {form.formState.errors.root.message}
              </p>
            )}
            <RulesCard form={form} rulesArray={rulesArray} />
            <ProductsCard form={form} />
            {mode === 'edit' && priceList && <PricesCard priceList={priceList} />}
          </>
        }
        sidebar={
          <>
            <BasicsCard form={form} />
            <ScheduleCard form={form} />
          </>
        }
      />
    </form>
  )
}

// =============================================================================
// Sidebar cards
// =============================================================================

function BasicsCard({ form }: { form: UseFormReturn<PriceListFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.price_lists.basics_section')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="name">{t('admin.fields.price_list.name.label')}</FieldLabel>
            <Input
              id="name"
              autoFocus
              placeholder={t('admin.fields.price_list.name.placeholder')}
              aria-invalid={!!errors.name || undefined}
              {...form.register('name')}
            />
            <p className="text-xs text-muted-foreground">
              {t('admin.fields.price_list.name.help')}
            </p>
            <FieldError errors={[errors.name]} />
          </Field>
          <Field>
            <FieldLabel htmlFor="description">
              {t('admin.fields.price_list.description.label')}
            </FieldLabel>
            <Textarea
              id="description"
              rows={3}
              placeholder={t('admin.fields.price_list.description.placeholder')}
              {...form.register('description')}
            />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

function ScheduleCard({ form }: { form: UseFormReturn<PriceListFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.price_lists.schedule_section')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="pl-starts-at">
              {t('admin.fields.price_list.starts_at.label')}
            </FieldLabel>
            <Controller
              name="starts_at"
              control={form.control}
              render={({ field }) => (
                <StoreDatePicker
                  value={field.value ?? null}
                  onChange={(v) => field.onChange(v ?? null)}
                  includeTime
                  placeholder={t('admin.fields.price_list.starts_at.placeholder')}
                />
              )}
            />
            <p className="text-xs text-muted-foreground">
              {t('admin.fields.price_list.starts_at.help')}
            </p>
          </Field>
          <Field>
            <FieldLabel htmlFor="pl-ends-at">
              {t('admin.fields.price_list.ends_at.label')}
            </FieldLabel>
            <Controller
              name="ends_at"
              control={form.control}
              render={({ field }) => (
                <StoreDatePicker
                  value={field.value ?? null}
                  onChange={(v) => field.onChange(v ?? null)}
                  includeTime
                  placeholder={t('admin.fields.price_list.ends_at.placeholder')}
                />
              )}
            />
            <p className="text-xs text-muted-foreground">
              {t('admin.fields.price_list.ends_at.help')}
            </p>
            <FieldError errors={[errors.ends_at]} />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

// =============================================================================
// Activation header buttons
// =============================================================================

function ActivationButtons({ priceList }: { priceList: PriceList }) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const confirm = useConfirm()
  const activate = useActivatePriceList(priceList.id)
  const deactivate = useDeactivatePriceList(priceList.id)
  const isActive = priceList.status === 'active' || priceList.status === 'scheduled'

  async function handleDeactivate() {
    const isScheduled = priceList.status === 'scheduled'
    const namespace = isScheduled
      ? 'admin.pages.products.price_lists.unschedule_confirm'
      : 'admin.pages.products.price_lists.deactivate_confirm'
    const ok = await confirm({
      title: t(`${namespace}.title`),
      message: t(`${namespace}.message`, { name: priceList.name }),
      // Not destructive — flips status; primary confirm button keeps default styling.
      confirmLabel: t(
        isScheduled
          ? 'admin.pages.products.price_lists.unschedule'
          : 'admin.pages.products.price_lists.deactivate',
      ),
    })
    if (!ok) return
    deactivate.mutate()
  }

  async function handleActivate(willSchedule: boolean) {
    const startsAt = priceList.starts_at ? formatStoreDateTime(priceList.starts_at, timezone) : ''
    const endsAt = priceList.ends_at ? formatStoreDateTime(priceList.ends_at, timezone) : ''
    const ok = await confirm({
      title: t(
        willSchedule
          ? 'admin.pages.products.price_lists.schedule_confirm.title'
          : 'admin.pages.products.price_lists.activate_confirm.title',
      ),
      message: willSchedule
        ? t('admin.pages.products.price_lists.schedule_confirm.message', {
            name: priceList.name,
            starts_at: startsAt,
          })
        : t(
            endsAt
              ? 'admin.pages.products.price_lists.activate_confirm.message_with_end'
              : 'admin.pages.products.price_lists.activate_confirm.message',
            { name: priceList.name, ends_at: endsAt },
          ),
      confirmLabel: t(
        willSchedule
          ? 'admin.pages.products.price_lists.schedule'
          : 'admin.pages.products.price_lists.activate',
      ),
    })
    if (!ok) return
    activate.mutate()
  }

  if (isActive) {
    return (
      <Can I="update" a={Subject.PriceList}>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={handleDeactivate}
          disabled={deactivate.isPending}
        >
          {priceList.status === 'scheduled' ? (
            <CalendarOffIcon className="size-4" />
          ) : (
            <PauseIcon className="size-4" />
          )}
          {t(
            priceList.status === 'scheduled'
              ? 'admin.pages.products.price_lists.unschedule'
              : 'admin.pages.products.price_lists.deactivate',
          )}
        </Button>
      </Can>
    )
  }

  const willSchedule = !!priceList.starts_at && new Date(priceList.starts_at) > new Date()
  return (
    <Can I="update" a={Subject.PriceList}>
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={() => handleActivate(willSchedule)}
        disabled={activate.isPending}
      >
        <PlayIcon className="size-4" />
        {willSchedule
          ? t('admin.pages.products.price_lists.schedule')
          : t('admin.pages.products.price_lists.activate')}
      </Button>
    </Can>
  )
}

// =============================================================================
// Main column — Rules
// =============================================================================

type RulesArray = ReturnType<typeof useFieldArray<PriceListFormValues, 'rules', '_key'>>

function RulesCard({
  form,
  rulesArray,
}: {
  form: UseFormReturn<PriceListFormValues>
  rulesArray: RulesArray
}) {
  const { t } = useTranslation()
  // Rule types come from the live price list (preferred — that's the
  // authoritative scope for "what's available here"). When that's missing
  // (create mode), we'll still get the same registry list because the
  // backend uses a single global `Spree.pricing.rules`.
  const { data: typesData } = usePriceRuleTypes()
  const [pickerOpen, setPickerOpen] = useState(false)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)

  const types = typesData?.data ?? []
  const watchedRules = (form.watch('rules') ?? []) as PriceRuleFormDraft[]

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle>{t('admin.pages.products.price_lists.rules_section')}</CardTitle>
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.products.price_lists.rules_help')}
            </p>
          </div>
          <Controller
            name="match_policy"
            control={form.control}
            render={({ field }) => {
              const items = MATCH_POLICIES.map((value) => ({
                value,
                label: t(`admin.fields.price_list.match_policy.${value}`),
              }))
              return (
                <Select items={items as never} value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger data-size="sm" className="w-auto">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {items.map((o) => (
                      <SelectItem key={o.value} value={o.value}>
                        {o.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )
            }}
          />
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {rulesArray.fields.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.products.price_lists.rules_empty')}
            </p>
          ) : (
            rulesArray.fields.map((field, index) => (
              <RuleRow
                key={field._key}
                draft={(watchedRules[index] ?? field) as unknown as PriceRuleFormDraft}
                onEdit={() => setEditingIndex(index)}
                onRemove={() => rulesArray.remove(index)}
              />
            ))
          )}
          <Can I="create" a={Subject.PriceRule}>
            <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.products.price_lists.add_rule')}
            </Button>
          </Can>
        </div>

        {pickerOpen && (
          <RulePickerSheet
            // One rule type per list (backend uniqueness on `type`).
            types={types.filter((tt) => !watchedRules.some((r) => r.type === tt.type))}
            registeredCount={types.length}
            open
            onOpenChange={(o) => !o && setPickerOpen(false)}
            onPicked={(type) => {
              const draft = ruleDraftFromType(type)
              rulesArray.append(draft)
              setPickerOpen(false)
              // Newly-appended index is the OLD length (append happens after
              // we read .fields), which is exactly the right index for the
              // edit sheet to point at.
              setEditingIndex(rulesArray.fields.length)
            }}
          />
        )}

        {editingIndex !== null && rulesArray.fields[editingIndex] && (
          <RuleEditSheet
            draft={
              (watchedRules[editingIndex] ??
                rulesArray.fields[editingIndex]) as unknown as PriceRuleFormDraft
            }
            open
            onOpenChange={(o) => !o && setEditingIndex(null)}
            onSave={(next) => rulesArray.update(editingIndex, next)}
          />
        )}
      </CardContent>
    </Card>
  )
}

function RuleRow({
  draft,
  onEdit,
  onRemove,
}: {
  draft: PriceRuleFormDraft
  onEdit: () => void
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  async function handleRemove(e: React.MouseEvent) {
    e.stopPropagation()
    const ok = await confirm({
      title: t('admin.pages.products.price_lists.remove_rule_confirm.title'),
      message: t('admin.pages.products.price_lists.remove_rule_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.remove'),
    })
    if (!ok) return
    onRemove()
  }

  return (
    <div className="flex w-full items-stretch rounded-md border bg-card hover:bg-muted/50">
      <button
        type="button"
        onClick={onEdit}
        className="min-w-0 flex-1 px-3 py-2 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring rounded-l-md"
      >
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{draft.label}</span>
          <PencilIcon className="size-3 text-muted-foreground" />
        </div>
        <RuleSummary draft={draft} />
      </button>
      <Can I="destroy" a={Subject.PriceRule}>
        <div className="flex items-center pr-1.5">
          <Button
            type="button"
            size="icon-xs"
            variant="ghost"
            onClick={handleRemove}
            className="text-destructive hover:bg-destructive/10 hover:text-destructive"
          >
            <TrashIcon className="size-4" />
          </Button>
        </div>
      </Can>
    </div>
  )
}

// Display embeds the API ships alongside each rule. The preference key
// is skipped in the generic prefs dump below so the row preview reads
// "VIPs, Wholesale" instead of "Customer group ids: cg_…".
const RULE_EMBEDS = [
  {
    prefKey: 'customer_group_ids',
    pick: (d: PriceRuleFormDraft) => d.customer_groups,
    label: (g: { name?: string | null; id: string }) => g.name ?? g.id,
  },
  {
    prefKey: 'user_ids',
    pick: (d: PriceRuleFormDraft) => d.customers,
    label: (c: { email?: string | null; id: string }) => c.email ?? c.id,
  },
  {
    prefKey: 'market_ids',
    pick: (d: PriceRuleFormDraft) => d.markets,
    label: (m: { name?: string | null; id: string }) => m.name ?? m.id,
  },
  {
    prefKey: 'channel_ids',
    pick: (d: PriceRuleFormDraft) => d.channels,
    label: (c: { name?: string | null; code?: string | null; id: string }) =>
      c.name ?? c.code ?? c.id,
  },
] as const

const PREFS_SHOWN_VIA_EMBED: ReadonlySet<string> = new Set(RULE_EMBEDS.map((e) => e.prefKey))

function RuleSummary({ draft }: { draft: PriceRuleFormDraft }) {
  const { t } = useTranslation()
  const parts: string[] = []

  for (const embed of RULE_EMBEDS) {
    const items = embed.pick(draft) as Array<{ id: string }> | undefined
    const rendered = nameList(items, embed.label as (item: { id: string }) => string, t)
    if (rendered) parts.push(rendered)
  }

  // Fall back to the generic preferences dump for everything else
  // (Volume Rule's min_quantity, etc.). Skip keys already covered above.
  for (const field of draft.preference_schema ?? []) {
    if (PREFS_SHOWN_VIA_EMBED.has(field.key)) continue
    const value = draft.preferences?.[field.key]
    if (value === null || value === undefined || value === '') continue
    if (Array.isArray(value) && value.length === 0) continue
    parts.push(`${humanize(field.key)}: ${formatPreferenceValue(value, t)}`)
  }

  if (parts.length === 0) {
    return (
      <div className="truncate text-xs text-muted-foreground">
        {draft.description || t('admin.pages.products.price_lists.rule_click_to_configure')}
      </div>
    )
  }
  return <div className="truncate text-xs text-muted-foreground">{parts.join(' · ')}</div>
}

/**
 * Joins up to 3 names; collapses the tail into "+N more". Returns null
 * when the embed is missing/empty — caller falls back to the preferences
 * dump.
 */
type Translator = (key: string, options?: Record<string, unknown>) => string

function nameList<T>(
  items: T[] | undefined,
  getLabel: (item: T) => string,
  t: Translator,
): string | null {
  if (!items?.length) return null
  const labels = items.map(getLabel).filter(Boolean)
  if (labels.length === 0) return null
  if (labels.length <= 3) return labels.join(', ')
  return t('admin.pages.products.price_lists.rule_name_overflow', {
    names: labels.slice(0, 3).join(', '),
    count: labels.length - 3,
  })
}

function formatPreferenceValue(value: unknown, t: Translator): string {
  if (Array.isArray(value)) return value.join(', ')
  if (typeof value === 'boolean') return t(value ? 'admin.common.yes' : 'admin.common.no')
  return String(value)
}

function humanize(key: string): string {
  const spaced = key.replace(/_/g, ' ').trim()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

function RulePickerSheet({
  types,
  registeredCount,
  open,
  onOpenChange,
  onPicked,
}: {
  /** Types still selectable — already-added types are filtered out upstream. */
  types: ResourceTypeDefinition[]
  /** Total registered types regardless of selection — lets the empty state
   *  distinguish "nothing registered" from "all already used". */
  registeredCount: number
  open: boolean
  onOpenChange: (open: boolean) => void
  onPicked: (type: ResourceTypeDefinition) => void
}) {
  const { t } = useTranslation()
  const emptyKey =
    registeredCount === 0
      ? 'admin.pages.products.price_lists.rule_types_empty'
      : 'admin.pages.products.price_lists.rule_types_all_used'
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.products.price_lists.add_rule')}</SheetTitle>
          <SheetDescription>{t('admin.pages.products.price_lists.add_rule_help')}</SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto p-4">
          {types.length === 0 ? (
            <p className="text-sm text-muted-foreground">{t(emptyKey)}</p>
          ) : (
            types.map((tt) => (
              <button
                key={tt.type}
                type="button"
                onClick={() => onPicked(tt)}
                className="flex flex-col items-start rounded-md border p-3 text-left transition-colors hover:bg-muted/50"
              >
                <span className="text-sm font-medium">{tt.label}</span>
                {tt.description && (
                  <span className="text-xs text-muted-foreground">{tt.description}</span>
                )}
              </button>
            ))
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}

function RuleEditSheet({
  draft,
  open,
  onOpenChange,
  onSave,
}: {
  draft: PriceRuleFormDraft
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (next: PriceRuleFormDraft) => void
}) {
  const { t } = useTranslation()
  const onClose = () => onOpenChange(false)
  const ctx: PriceRuleEditorContext = { draft, onSave, onClose }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{draft.label}</SheetTitle>
          <SheetDescription>
            {draft.description || t('admin.pages.products.price_lists.rule_default_description')}
          </SheetDescription>
        </SheetHeader>
        <Slot
          name={ruleFormSlot(draft.type)}
          context={ctx}
          fallback={<DefaultRuleEditor {...ctx} />}
        />
      </SheetContent>
    </Sheet>
  )
}

/**
 * Generic preferences editor used when a rule type doesn't ship its own
 * editor. Works for VolumeRule (integer min/max inputs) and any future
 * rule whose configuration fits the `<PreferencesForm>` shape.
 */
function DefaultRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  const [values, setValues] = useState<Record<string, unknown>>(draft.preferences ?? {})
  // Re-seed when the user switches between rules without closing.
  useEffect(() => {
    setValues(draft.preferences ?? {})
  }, [draft])

  const hasPreferences = !!draft.preference_schema?.length

  function handleSave() {
    onSave({ ...draft, preferences: values })
    onClose()
  }

  return (
    <EditorShell
      onSave={handleSave}
      onCancel={onClose}
      pending={false}
      saveDisabled={!hasPreferences && draft.preferences == null}
    >
      {hasPreferences ? (
        <PreferencesForm schema={draft.preference_schema} values={values} onChange={setValues} />
      ) : (
        <p className="text-sm text-muted-foreground">
          {t('admin.pages.products.price_lists.rule_no_options')}
        </p>
      )}
    </EditorShell>
  )
}

// =============================================================================
// Products card — inline multi-autocomplete + link to spreadsheet
// =============================================================================

/**
 * Products that belong to the price list. The picker writes directly to
 * the form's `product_ids` field — on Save the whole list ships in the
 * same PATCH that handles name, schedule, and rules. No separate
 * add/remove endpoints, no sheet.
 *
 * The spreadsheet for filling in the actual amounts is rendered as a
 * sibling card below, so adding a product here causes its variant rows
 * to appear (after Save) in the Prices card without any navigation.
 */
function ProductsCard({ form }: { form: UseFormReturn<PriceListFormValues> }) {
  const { t } = useTranslation()
  const productIds = form.watch('product_ids')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.products.price_lists.products_section')}</CardTitle>
        <p className="mt-1 text-xs text-muted-foreground">
          {t('admin.pages.products.price_lists.products_help')}
        </p>
      </CardHeader>
      <CardContent>
        <Controller
          name="product_ids"
          control={form.control}
          render={({ field }) => (
            <ResourceMultiAutocomplete
              queryKey="price-list-products"
              value={field.value}
              onChange={field.onChange}
              search={(q) => adminClient.products.list({ name_cont: q, limit: 10, sort: 'name' })}
              hydrate={(ids) => adminClient.products.list({ id_in: ids, limit: ids.length })}
              getOptionLabel={(p) => p.name ?? p.id}
              placeholder={t('admin.pages.products.price_lists.products_search_placeholder')}
              emptyText={t('admin.pages.products.price_lists.products_empty_search')}
            />
          )}
        />
        {productIds.length > 0 && (
          <p className="mt-2 text-xs text-muted-foreground">
            {t('admin.pages.products.price_lists.products_selected', {
              count: productIds.length,
            })}
          </p>
        )}
      </CardContent>
    </Card>
  )
}

function PricesCard({ priceList }: { priceList: PriceList }) {
  const { t } = useTranslation()
  const [editorOpen, setEditorOpen] = useState(false)
  const count = priceList.prices_count ?? 0

  return (
    <>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0">
          <div>
            <CardTitle>{t('admin.common.prices')}</CardTitle>
            <p className="mt-1 text-xs text-muted-foreground">
              {t('admin.pages.products.price_lists.prices_help', { count })}
            </p>
          </div>
          <Button type="button" size="sm" variant="outline" onClick={() => setEditorOpen(true)}>
            <TableIcon className="mr-1 size-4" />
            {t('admin.pages.products.price_lists.edit_prices_cta')}
          </Button>
        </CardHeader>
      </Card>
      <BulkPriceEditorDialog open={editorOpen} onOpenChange={setEditorOpen} priceList={priceList} />
    </>
  )
}
