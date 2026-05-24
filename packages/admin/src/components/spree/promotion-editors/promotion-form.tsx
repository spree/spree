import { zodResolver } from '@hookform/resolvers/zod'
import type {
  Customer,
  Promotion,
  PromotionAction,
  PromotionActionDraft,
  PromotionRule,
  PromotionRuleDraft,
  ResourceTypeDefinition,
} from '@spree/admin-sdk'
import { DownloadIcon, PlusIcon, SparklesIcon, TrashIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { formatCalculatorSummary } from '@/components/spree/calculator-summary'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { PageHeader } from '@/components/spree/page-header'
import { PreferencesForm } from '@/components/spree/preferences-form'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import { StoreDatePicker } from '@/components/spree/store-date-picker'
import '@/components/spree/promotion-editors/register'
import {
  actionDraftFromAction,
  actionDraftFromType,
  actionDraftToPayload,
  actionFormSlot,
  type PromotionActionEditorContext,
  type PromotionActionFormDraft,
  type PromotionRuleEditorContext,
  type PromotionRuleFormDraft,
  ruleDraftFromRule,
  ruleDraftFromType,
  ruleDraftToPayload,
  ruleFormSlot,
} from '@/components/spree/promotion-editors/types'
import { ResourceLayout } from '@/components/spree/resource-layout'
import { Slot } from '@/components/spree/slot'
import { ActiveBadge, Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/data-table'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { useExport } from '@/hooks/use-export'
import {
  usePromotionActionTypes,
  usePromotionCouponCodes,
  usePromotionRuleTypes,
} from '@/hooks/use-promotions'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import { useStore } from '@/providers/store-provider'
import {
  MATCH_POLICIES,
  type MatchPolicy,
  PROMOTION_DEFAULTS,
  PROMOTION_KINDS,
  type PromotionFormValues,
  type PromotionKind,
  promotionFormSchema,
} from '@/schemas/promotion'

// =============================================================================
// Types
// =============================================================================

/**
 * Form values for the unified promotion form. Both create and edit use the
 * same shape; the create page sends the full set on POST, the edit page
 * sends the full set on PATCH.
 *
 * Trigger fields (kind/code/multi_codes/number_of_codes/code_prefix) are
 * editable in create mode and locked in edit mode (the server doesn't
 * accept changes to them after creation — see `permitted_params` in
 * Spree::Api::V3::Admin::PromotionsController).
 */
export type { PromotionFormValues } from '@/schemas/promotion'

export interface PromotionFormPayload {
  name: string
  description: string | null
  starts_at: string | null
  expires_at: string | null
  usage_limit: number | null
  match_policy: MatchPolicy
  rules: PromotionRuleDraft[]
  actions: PromotionActionDraft[]
  /** Only sent in create mode — server rejects these on update. */
  kind?: PromotionKind
  code?: string | null
  multi_codes?: boolean
  number_of_codes?: number | null
  code_prefix?: string | null
}

interface PromotionFormProps {
  mode: 'create' | 'edit'
  /** Existing promotion (edit mode only) — drives the trigger summary card. */
  promotion?: Promotion
  /** Existing rules (edit mode only). */
  initialRules?: PromotionRule[]
  /** Existing actions (edit mode only). */
  initialActions?: PromotionAction[]
  /** Called when the user clicks Save / Create. */
  onSubmit: (payload: PromotionFormPayload) => Promise<void>
  /** Optional — when provided in edit mode, shows a Delete button in the header. */
  onDelete?: () => void
  /** True while the delete mutation is in-flight (for button disabled state). */
  deletePending?: boolean
}

// =============================================================================
// Root component
// =============================================================================

export function PromotionForm({
  mode,
  promotion,
  initialRules,
  initialActions,
  onSubmit,
  onDelete,
  deletePending = false,
}: PromotionFormProps) {
  const { t } = useTranslation()
  const form = useForm<PromotionFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(promotionFormSchema) as any,
    defaultValues: PROMOTION_DEFAULTS,
  })

  const rulesArray = useFieldArray({ control: form.control, name: 'rules', keyName: '_key' })
  const actionsArray = useFieldArray({ control: form.control, name: 'actions', keyName: '_key' })

  // Hydrate edit mode once all three queries have settled. Re-runs after
  // a successful submit because the queries are invalidated.
  // biome-ignore lint/correctness/useExhaustiveDependencies: form is stable
  useEffect(() => {
    if (mode !== 'edit') return
    if (!promotion || !initialRules || !initialActions) return
    form.reset({
      name: promotion.name,
      description: promotion.description ?? '',
      kind: promotion.kind as PromotionKind,
      code: promotion.code ?? '',
      multi_codes: promotion.multi_codes,
      number_of_codes: promotion.number_of_codes ?? undefined,
      code_prefix: promotion.code_prefix ?? '',
      starts_at: promotion.starts_at ?? '',
      expires_at: promotion.expires_at ?? '',
      usage_limit: promotion.usage_limit ?? undefined,
      match_policy: promotion.match_policy,
      rules: initialRules.map(ruleDraftFromRule),
      actions: initialActions.map(actionDraftFromAction),
    })
  }, [mode, promotion, initialRules, initialActions])

  async function handleSubmit(values: PromotionFormValues) {
    const payload: PromotionFormPayload = {
      name: values.name,
      description: values.description?.length ? values.description : null,
      starts_at: values.starts_at || null,
      expires_at: values.expires_at || null,
      usage_limit: values.usage_limit ?? null,
      match_policy: values.match_policy,
      rules: values.rules.map(ruleDraftToPayload),
      actions: values.actions.map(actionDraftToPayload),
    }
    if (mode === 'create') {
      Object.assign(payload, couponFieldsForKind(values))
    }
    try {
      await onSubmit(payload)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const isLoading = mode === 'edit' && (!promotion || !initialRules || !initialActions)
  if (isLoading) {
    return (
      <ResourceLayout
        header={<PageHeader title={t('admin.common.loading')} backTo="promotions" />}
        main={
          <div className="text-sm text-muted-foreground">{t('admin.pages.promotions.loading')}</div>
        }
      />
    )
  }

  return (
    <form onSubmit={form.handleSubmit(handleSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={
              mode === 'create' ? t('admin.pages.promotions.new_title') : (promotion?.name ?? '')
            }
            backTo="promotions"
            actions={
              <div className="flex gap-2">
                {mode === 'edit' && onDelete && (
                  <Can I="destroy" a={Subject.Promotion}>
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
                      ? t('admin.pages.promotions.create_cta')
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
            <RulesCard
              form={form}
              rulesArray={rulesArray}
              matchPolicy={form.watch('match_policy')}
            />
            <ActionsCard form={form} actionsArray={actionsArray} />
          </>
        }
        sidebar={
          <>
            <BasicsCard form={form} />
            <TriggerCard mode={mode} form={form} promotion={promotion} />
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

function BasicsCard({ form }: { form: UseFormReturn<PromotionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <Card>
      <CardHeader>
        <CardTitle>Basics</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
            <Input
              id="name"
              placeholder={t('admin.fields.promotion.name.placeholder')}
              aria-invalid={!!errors.name || undefined}
              {...form.register('name')}
            />
            <FieldError errors={[errors.name]} />
          </Field>
          <Field>
            <FieldLabel htmlFor="description">{t('admin.fields.description.label')}</FieldLabel>
            <Textarea
              id="description"
              rows={3}
              placeholder={t('admin.fields.promotion.description.placeholder')}
              aria-invalid={!!errors.description || undefined}
              {...form.register('description')}
            />
            <FieldError errors={[errors.description]} />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

function TriggerCard({
  mode,
  form,
  promotion,
}: {
  mode: 'create' | 'edit'
  form: UseFormReturn<PromotionFormValues>
  promotion?: Promotion
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const kind = form.watch('kind')
  const multiCodes = form.watch('multi_codes')

  return (
    <Card>
      <CardHeader>
        <CardTitle>Trigger</CardTitle>
      </CardHeader>
      <CardContent>
        {mode === 'edit' && promotion ? (
          <ReadOnlyTriggerSummary promotion={promotion} />
        ) : (
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="kind">{t('admin.fields.promotion.kind.label')}</FieldLabel>
              <Controller
                name="kind"
                control={form.control}
                render={({ field }) => {
                  const items = PROMOTION_KINDS.map((value) => ({
                    value,
                    label: t(`admin.promotions.kinds.${value}`),
                  }))
                  return (
                    <Select
                      items={items as never}
                      value={field.value}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="kind">
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
            </Field>

            {kind === 'coupon_code' && (
              <>
                <Field>
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex flex-col">
                      <FieldLabel htmlFor="multi_codes" className="cursor-pointer">
                        {t('admin.fields.promotion.multi_codes.label')}
                      </FieldLabel>
                      <span className="text-xs text-muted-foreground">
                        {t('admin.fields.promotion.multi_codes.help')}
                      </span>
                    </div>
                    <Controller
                      name="multi_codes"
                      control={form.control}
                      render={({ field }) => (
                        <Switch
                          id="multi_codes"
                          checked={!!field.value}
                          onCheckedChange={field.onChange}
                        />
                      )}
                    />
                  </div>
                </Field>

                {!multiCodes ? (
                  <Field>
                    <FieldLabel htmlFor="code">{t('admin.fields.code.label')}</FieldLabel>
                    <div className="flex items-center gap-2">
                      <Input
                        id="code"
                        placeholder={t('admin.fields.promotion.code.placeholder')}
                        aria-invalid={!!errors.code || undefined}
                        {...form.register('code')}
                      />
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          // Clear any "required" error left from a prior submit so the field
                          // doesn't stay red after we fill it in.
                          form.setValue('code', randomCouponCode(), { shouldDirty: true })
                          form.clearErrors('code')
                        }}
                        title={t('admin.promotions.generate_code.title')}
                      >
                        <SparklesIcon className="size-4" />
                        {t('admin.actions.generate')}
                      </Button>
                    </div>
                    <FieldError errors={[errors.code]} />
                  </Field>
                ) : (
                  <>
                    <Field>
                      <FieldLabel htmlFor="number_of_codes">
                        {t('admin.fields.promotion.number_of_codes.label')}
                      </FieldLabel>
                      <Input
                        id="number_of_codes"
                        type="number"
                        min={1}
                        placeholder={t('admin.fields.promotion.number_of_codes.placeholder')}
                        aria-invalid={!!errors.number_of_codes || undefined}
                        {...form.register('number_of_codes')}
                      />
                      <FieldError errors={[errors.number_of_codes]} />
                    </Field>
                    <Field>
                      <FieldLabel htmlFor="code_prefix">
                        {t('admin.fields.promotion.code_prefix.label')}
                      </FieldLabel>
                      <Input
                        id="code_prefix"
                        placeholder={t('admin.fields.promotion.code_prefix.placeholder')}
                        aria-invalid={!!errors.code_prefix || undefined}
                        {...form.register('code_prefix')}
                      />
                      <p className="text-xs text-muted-foreground">
                        {t('admin.fields.promotion.code_prefix.help')}
                      </p>
                      <FieldError errors={[errors.code_prefix]} />
                    </Field>
                  </>
                )}
              </>
            )}
          </FieldGroup>
        )}
      </CardContent>
    </Card>
  )
}

function ReadOnlyTriggerSummary({ promotion }: { promotion: Promotion }) {
  const [codesOpen, setCodesOpen] = useState(false)

  return (
    <div className="space-y-2 text-sm">
      {promotion.kind === 'automatic' ? (
        <Badge variant="outline">Automatic</Badge>
      ) : promotion.multi_codes ? (
        <div className="space-y-2">
          <div>
            Multi-code coupon ({promotion.number_of_codes ?? 0} codes
            {promotion.code_prefix ? ` with prefix "${promotion.code_prefix}"` : ''})
          </div>
          <Button type="button" variant="outline" size="sm" onClick={() => setCodesOpen(true)}>
            Show codes
          </Button>
          {codesOpen && (
            <CouponCodesSheet
              promotionId={promotion.id}
              open
              onOpenChange={(o) => !o && setCodesOpen(false)}
            />
          )}
        </div>
      ) : (
        <div>
          Single coupon code:{' '}
          <code className="rounded bg-muted px-1 py-0.5 text-xs">
            {promotion.code?.toUpperCase() || '—'}
          </code>
        </div>
      )}
      <p className="text-xs text-muted-foreground">
        Trigger settings can't be changed after creation. Make a new promotion to change them.
      </p>
    </div>
  )
}

function ScheduleCard({ form }: { form: UseFormReturn<PromotionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <Card>
      <CardHeader>
        <CardTitle>Schedule & limits</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="promo-starts-at">{t('admin.fields.starts_at.label')}</FieldLabel>
            <Controller
              name="starts_at"
              control={form.control}
              render={({ field }) => (
                <StoreDatePicker
                  value={field.value || null}
                  onChange={(next) => field.onChange(next ?? '')}
                  placeholder={t('admin.fields.promotion.starts_at.placeholder')}
                  includeTime
                />
              )}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="promo-expires-at">{t('admin.fields.expires_at.label')}</FieldLabel>
            <Controller
              name="expires_at"
              control={form.control}
              render={({ field }) => (
                <StoreDatePicker
                  value={field.value || null}
                  onChange={(next) => field.onChange(next ?? '')}
                  placeholder={t('admin.fields.promotion.expires_at.placeholder')}
                  includeTime
                />
              )}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="usage_limit">
              {t('admin.fields.promotion.usage_limit.label')}
            </FieldLabel>
            <Input
              id="usage_limit"
              type="number"
              min={1}
              placeholder={t('admin.fields.promotion.usage_limit.placeholder')}
              aria-invalid={!!errors.usage_limit || undefined}
              {...form.register('usage_limit')}
            />
            <FieldError errors={[errors.usage_limit]} />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

// =============================================================================
// Main column — Rules
// =============================================================================

type RulesArray = ReturnType<typeof useFieldArray<PromotionFormValues, 'rules', '_key'>>
type ActionsArray = ReturnType<typeof useFieldArray<PromotionFormValues, 'actions', '_key'>>

function RulesCard({
  form,
  rulesArray,
  matchPolicy,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
  rulesArray: RulesArray
  matchPolicy: MatchPolicy
}) {
  const { t } = useTranslation()
  const { data: typesData } = usePromotionRuleTypes()
  const { defaultCurrency } = useStore()
  const [pickerOpen, setPickerOpen] = useState(false)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)

  const types = typesData?.data ?? []
  // Use `watch` for the row drafts — `rulesArray.fields` is RHF's
  // snapshot that only updates for registered inputs. Our drafts carry
  // unregistered nested data (preferences, embedded records, schema),
  // so reading from fields alone leaves the row summary stale after
  // editor saves. `watch('rules')` subscribes to the whole list.
  const watchedRules = (form.watch('rules') ?? []) as PromotionRuleFormDraft[]
  // Multi-rule logic is only meaningful when there are 2+ rules. For 0 or 1
  // rules, hide the picker — the description still hints at the policy so
  // the merchant knows it will matter once they add a second rule.
  const showMatchPolicy = rulesArray.fields.length >= 2

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle>{t('admin.promotions.rules_card.title')}</CardTitle>
            <p className="text-sm text-muted-foreground">
              {t('admin.promotions.rules_card.description')}{' '}
              {t(`admin.promotions.match_policies.${matchPolicy}_hint`)}
            </p>
          </div>
          {showMatchPolicy && (
            <Controller
              name="match_policy"
              control={form.control}
              render={({ field }) => {
                const items = MATCH_POLICIES.map((value) => ({
                  value,
                  label: t(`admin.promotions.match_policies.${value}`),
                }))
                return (
                  <Select items={items as never} value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger id="match_policy" data-size="sm" className="w-auto">
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
          )}
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {rulesArray.fields.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No rules. Without rules, the promotion always qualifies (subject to schedule and usage
              limit).
            </p>
          ) : (
            rulesArray.fields.map((field, index) => (
              <RuleRow
                key={field._key}
                draft={(watchedRules[index] ?? field) as unknown as PromotionRuleFormDraft}
                onEdit={() => setEditingIndex(index)}
                onRemove={() => rulesArray.remove(index)}
              />
            ))
          )}
          <Can I="create" a={Subject.PromotionRule}>
            <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
              <PlusIcon className="size-4" />
              Add rule
            </Button>
          </Can>
        </div>

        {pickerOpen && (
          <RulePickerSheet
            types={types}
            open
            onOpenChange={(o) => !o && setPickerOpen(false)}
            onPicked={(type) => {
              const draft = ruleDraftFromType(type, { currency: defaultCurrency })
              rulesArray.append(draft)
              setPickerOpen(false)
              setEditingIndex(rulesArray.fields.length)
            }}
          />
        )}

        {editingIndex !== null && rulesArray.fields[editingIndex] && (
          <RuleEditSheet
            draft={
              (watchedRules[editingIndex] ??
                rulesArray.fields[editingIndex]) as unknown as PromotionRuleFormDraft
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
  draft: PromotionRuleFormDraft
  onEdit: () => void
  onRemove: () => void
}) {
  const confirm = useConfirm()

  async function handleRemove(e: React.MouseEvent) {
    e.stopPropagation()
    const ok = await confirm({
      title: 'Remove rule?',
      message: 'Removed when you save the promotion.',
      variant: 'destructive',
      confirmLabel: 'Remove',
    })
    if (!ok) return
    onRemove()
  }

  // The row is a div, not a button, so the trash <Button> below can be a
  // valid sibling. The "edit" area is its own <button> spanning the
  // label/summary slot; trash is the second column.
  return (
    <div className="flex w-full items-stretch rounded-md border bg-card hover:bg-muted/50">
      <button
        type="button"
        onClick={onEdit}
        className="min-w-0 flex-1 px-3 py-2 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring rounded-l-md"
      >
        <div className="text-sm font-medium">{draft.label}</div>
        <RuleSummary draft={draft} />
      </button>
      <Can I="destroy" a={Subject.PromotionRule}>
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

function RuleSummary({ draft }: { draft: PromotionRuleFormDraft }) {
  const parts: string[] = []
  const products = nameList(draft.products)
  const categories = nameList(draft.categories)
  const customers = nameList(draft.customers, customerLabel)
  const groups = nameList(draft.customer_groups)
  const countries = nameList(draft.countries)

  if (products) parts.push(products)
  else if (draft.product_ids?.length) parts.push(`${draft.product_ids.length} products`)

  if (categories) parts.push(categories)
  else if (draft.category_ids?.length) parts.push(`${draft.category_ids.length} categories`)

  if (customers) parts.push(customers)
  else if (draft.customer_ids?.length) parts.push(`${draft.customer_ids.length} customers`)

  if (groups) parts.push(groups)
  if (countries) parts.push(countries)

  // Fallback for preference-only rules (Currency, ItemTotal, FirstOrder,
  // OneUsePerUser, UserLoggedIn, OptionValue, …) — these don't carry
  // embedded records, just a `preferences` hash. Walk the rule's
  // preference schema and format each value so drafts that haven't been
  // saved yet still get a useful row preview.
  const prefSummary = formatPreferencesSummary(draft)
  if (prefSummary) parts.push(prefSummary)

  if (parts.length === 0) return null
  return <div className="truncate text-xs text-muted-foreground">{parts.join(' · ')}</div>
}

const RULE_PREFS_SHOWN_ELSEWHERE = new Set([
  'match_policy', // shown in the rules card header
  'customer_group_ids', // surfaced via `customer_groups` records
  'country_isos', // surfaced via `countries` records
  'country_id',
  'country_iso',
])

function formatPreferencesSummary(draft: PromotionRuleFormDraft): string | null {
  const prefs = draft.preferences
  if (!prefs) return null
  const schema = draft.preference_schema ?? []

  const pairs: string[] = []
  for (const field of schema) {
    if (RULE_PREFS_SHOWN_ELSEWHERE.has(field.key)) continue
    const value = prefs[field.key]
    if (value === null || value === undefined || value === '') continue
    if (Array.isArray(value) && value.length === 0) continue
    pairs.push(`${humanize(field.key)}: ${formatPreferenceValue(value)}`)
  }
  return pairs.length > 0 ? pairs.join(', ') : null
}

function formatPreferenceValue(value: unknown): string {
  if (Array.isArray(value)) return value.join(', ')
  if (typeof value === 'boolean') return value ? 'yes' : 'no'
  return String(value)
}

function humanize(key: string): string {
  const spaced = key.replace(/_/g, ' ').trim()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

/**
 * Joins up to 3 names; collapses the tail into "+N more". Returns null
 * when the list is missing or empty so the caller can fall back to a
 * count-based summary built from `*_ids`.
 */
function nameList<T>(
  items: T[] | undefined,
  getLabel: (item: T) => string = defaultLabel,
): string | null {
  if (!items?.length) return null
  const labels = items.map(getLabel).filter(Boolean)
  if (labels.length === 0) return null
  if (labels.length <= 3) return labels.join(', ')
  return `${labels.slice(0, 3).join(', ')} +${labels.length - 3} more`
}

function defaultLabel(o: unknown): string {
  if (
    o &&
    typeof o === 'object' &&
    'name' in o &&
    typeof (o as { name: unknown }).name === 'string'
  ) {
    return (o as { name: string }).name
  }
  return ''
}

function customerLabel(c: Customer): string {
  return c.full_name || c.email || ''
}

function RulePickerSheet({
  types,
  open,
  onOpenChange,
  onPicked,
}: {
  types: ResourceTypeDefinition[]
  open: boolean
  onOpenChange: (open: boolean) => void
  onPicked: (type: ResourceTypeDefinition) => void
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Add rule</SheetTitle>
          <SheetDescription>Pick a rule type to configure.</SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto p-4">
          {types.map((t) => (
            <button
              key={t.type}
              type="button"
              onClick={() => onPicked(t)}
              className="flex flex-col items-start rounded-md border p-3 text-left transition-colors hover:bg-muted/50"
            >
              <span className="text-sm font-medium">{t.label}</span>
              {t.description && (
                <span className="text-xs text-muted-foreground">{t.description}</span>
              )}
            </button>
          ))}
        </div>
        <SheetFooter>
          <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
        </SheetFooter>
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
  draft: PromotionRuleFormDraft
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (next: PromotionRuleFormDraft) => void
}) {
  const onClose = () => onOpenChange(false)
  const ctx: PromotionRuleEditorContext = { draft, onSave, onClose }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{draft.label}</SheetTitle>
          <SheetDescription>Tune the rule's parameters.</SheetDescription>
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

function DefaultRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const [values, setValues] = useState<Record<string, unknown>>(draft.preferences ?? {})
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
      saveDisabled={!hasPreferences}
    >
      {hasPreferences ? (
        <PreferencesForm schema={draft.preference_schema} values={values} onChange={setValues} />
      ) : (
        <p className="text-sm text-muted-foreground">
          This rule has no configurable options — its presence alone applies the constraint.
        </p>
      )}
    </EditorShell>
  )
}

// =============================================================================
// Main column — Actions
// =============================================================================

function ActionsCard({
  form,
  actionsArray,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
  actionsArray: ActionsArray
}) {
  const { data: typesData } = usePromotionActionTypes()
  const { defaultCurrency } = useStore()
  const [pickerOpen, setPickerOpen] = useState(false)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)

  const types = typesData?.data ?? []
  // See `RulesCard` — read row drafts from `watch` so unregistered
  // nested fields (preferences, calculator, line_items) stay fresh
  // after editor saves.
  const watchedActions = (form.watch('actions') ?? []) as PromotionActionFormDraft[]

  return (
    <Card>
      <CardHeader>
        <CardTitle>Actions</CardTitle>
        <p className="text-sm text-muted-foreground">What happens when the promotion qualifies.</p>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {actionsArray.fields.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No actions yet. A promotion without actions doesn't do anything when applied.
            </p>
          ) : (
            actionsArray.fields.map((field, index) => (
              <ActionRow
                key={field._key}
                draft={(watchedActions[index] ?? field) as unknown as PromotionActionFormDraft}
                onEdit={() => setEditingIndex(index)}
                onRemove={() => actionsArray.remove(index)}
              />
            ))
          )}
          <Can I="create" a={Subject.PromotionAction}>
            <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
              <PlusIcon className="size-4" />
              Add action
            </Button>
          </Can>
        </div>

        {pickerOpen && (
          <ActionPickerSheet
            types={types}
            open
            onOpenChange={(o) => !o && setPickerOpen(false)}
            onPicked={(type) => {
              const draft = actionDraftFromType(type, { currency: defaultCurrency })
              actionsArray.append(draft)
              setPickerOpen(false)
              setEditingIndex(actionsArray.fields.length)
            }}
          />
        )}

        {editingIndex !== null && actionsArray.fields[editingIndex] && (
          <ActionEditSheet
            draft={
              (watchedActions[editingIndex] ??
                actionsArray.fields[editingIndex]) as unknown as PromotionActionFormDraft
            }
            open
            onOpenChange={(o) => !o && setEditingIndex(null)}
            onSave={(next) => actionsArray.update(editingIndex, next)}
          />
        )}
      </CardContent>
    </Card>
  )
}

function ActionRow({
  draft,
  onEdit,
  onRemove,
}: {
  draft: PromotionActionFormDraft
  onEdit: () => void
  onRemove: () => void
}) {
  const confirm = useConfirm()

  async function handleRemove(e: React.MouseEvent) {
    e.stopPropagation()
    const ok = await confirm({
      title: 'Remove action?',
      message: 'Removed when you save the promotion.',
      variant: 'destructive',
      confirmLabel: 'Remove',
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
        <div className="text-sm font-medium">{draft.label}</div>
        <ActionSummary draft={draft} />
      </button>
      <Can I="destroy" a={Subject.PromotionAction}>
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

function ActionSummary({ draft }: { draft: PromotionActionFormDraft }) {
  const parts: string[] = []
  const calc = formatCalculatorSummary(draft.calculator)
  if (calc) parts.push(calc)
  if (draft.line_items?.length) parts.push(`${draft.line_items.length} variants`)
  if (parts.length === 0) return null
  return <div className="truncate text-xs text-muted-foreground">{parts.join(' · ')}</div>
}

function ActionPickerSheet({
  types,
  open,
  onOpenChange,
  onPicked,
}: {
  types: ResourceTypeDefinition[]
  open: boolean
  onOpenChange: (open: boolean) => void
  onPicked: (type: ResourceTypeDefinition) => void
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Add action</SheetTitle>
          <SheetDescription>Pick what should happen when the promotion qualifies.</SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto p-4">
          {types.map((t) => (
            <button
              key={t.type}
              type="button"
              onClick={() => onPicked(t)}
              className="flex flex-col items-start rounded-md border p-3 text-left transition-colors hover:bg-muted/50"
            >
              <span className="text-sm font-medium">{t.label}</span>
              {t.description && (
                <span className="text-xs text-muted-foreground">{t.description}</span>
              )}
            </button>
          ))}
        </div>
        <SheetFooter>
          <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function ActionEditSheet({
  draft,
  open,
  onOpenChange,
  onSave,
}: {
  draft: PromotionActionFormDraft
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (next: PromotionActionFormDraft) => void
}) {
  const onClose = () => onOpenChange(false)
  const ctx: PromotionActionEditorContext = { draft, onSave, onClose }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{draft.label}</SheetTitle>
          <SheetDescription>Configure the action's parameters.</SheetDescription>
        </SheetHeader>
        <Slot
          name={actionFormSlot(draft.type)}
          context={ctx}
          fallback={<DefaultActionEditor {...ctx} />}
        />
      </SheetContent>
    </Sheet>
  )
}

function DefaultActionEditor({ draft, onSave, onClose }: PromotionActionEditorContext) {
  const [values, setValues] = useState<Record<string, unknown>>(draft.preferences ?? {})
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
      saveDisabled={!hasPreferences}
    >
      {hasPreferences ? (
        <PreferencesForm schema={draft.preference_schema} values={values} onChange={setValues} />
      ) : (
        <p className="text-sm text-muted-foreground">This action has no configurable options.</p>
      )}
    </EditorShell>
  )
}

// =============================================================================
// Coupon codes (multi-code promotions only) — opened from the Trigger card
// =============================================================================

function CouponCodesSheet({
  promotionId,
  open,
  onOpenChange,
}: {
  promotionId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [page, setPage] = useState(1)
  const { data: codesData, isFetching } = usePromotionCouponCodes(promotionId, {
    limit: 50,
    page,
  })
  const codes = codesData?.data ?? []
  const totalCount = codesData?.meta?.count ?? codes.length
  const totalPages = codesData?.meta?.pages ?? 1

  const exportMutation = useExport()
  function handleExport() {
    exportMutation.mutate({
      type: 'Spree::Exports::CouponCodes',
      record_selection: 'filtered',
      search_params: { promotion_id_eq: promotionId },
    })
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>Coupon codes</SheetTitle>
          <SheetDescription>
            {totalCount > 0
              ? `${totalCount} auto-generated codes. Read-only — regenerate by changing the promotion's number-of-codes setting.`
              : "Auto-generated codes for this promotion. Read-only — regenerate by changing the promotion's number-of-codes setting."}
          </SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
          {codes.length === 0 ? (
            <p className="px-4 py-6 text-sm text-muted-foreground">No codes generated yet.</p>
          ) : (
            <div className="flex-1 overflow-y-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Code</TableHead>
                    <TableHead className="w-32">Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {codes.map((c) => {
                    const used = c.state && c.state !== 'unused'
                    return (
                      <TableRow key={c.id}>
                        <TableCell>
                          <code
                            className={`font-mono text-xs ${used ? 'text-muted-foreground line-through' : ''}`}
                          >
                            {c.code}
                          </code>
                        </TableCell>
                        <TableCell>
                          <ActiveBadge
                            active={!used}
                            activeLabel="Unused"
                            inactiveLabel={c.state ?? 'Used'}
                          />
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          )}

          {totalPages > 1 && (
            <div className="flex items-center justify-between border-t px-4 py-2">
              <span className="text-xs text-muted-foreground">
                Page {page} of {totalPages}
              </span>
              <div className="flex gap-1">
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page === 1 || isFetching}
                >
                  Prev
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages || isFetching}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </div>

        <SheetFooter>
          {totalCount > 0 && (
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={handleExport}
              disabled={exportMutation.isPending}
            >
              <DownloadIcon className="size-4" />
              {exportMutation.isPending ? 'Exporting…' : 'Export CSV'}
            </Button>
          )}
          <Button type="button" size="sm" variant="outline" onClick={() => onOpenChange(false)}>
            Close
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

// =============================================================================
// Helpers
// =============================================================================

/**
 * 8-char uppercase alphanumeric (digits + A–Z, excluding ambiguous 0/O/1/I/L).
 * Mirrors `Spree::Promotion#random_code`'s rough alphabet — but generated
 * client-side so the merchant sees what they're about to save before they
 * click Create.
 */
function randomCouponCode(): string {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
  const bytes = new Uint32Array(8)
  crypto.getRandomValues(bytes)
  let out = ''
  for (const b of bytes) out += alphabet[b % alphabet.length]
  return out
}

/**
 * Server expects a coherent trigger set: automatic clears all coupon
 * fields, single-code sets `code`, multi-code sets `number_of_codes` +
 * optional prefix. Only sent on create — these fields are locked on edit.
 */
function couponFieldsForKind(values: PromotionFormValues) {
  if (values.kind !== 'coupon_code') {
    return {
      kind: 'automatic' as const,
      code: null,
      multi_codes: false,
      number_of_codes: null,
      code_prefix: null,
    }
  }
  if (values.multi_codes) {
    return {
      kind: 'coupon_code' as const,
      code: null,
      multi_codes: true,
      number_of_codes: values.number_of_codes ?? null,
      code_prefix: values.code_prefix || null,
    }
  }
  return {
    kind: 'coupon_code' as const,
    code: values.code || null,
    multi_codes: false,
    number_of_codes: null,
    code_prefix: null,
  }
}
