import type {
  Category,
  Country,
  Customer,
  CustomerGroup,
  PreferenceField,
  Product,
  PromotionAction,
  PromotionActionCalculatorParams,
  PromotionActionDraft,
  PromotionActionLineItemParams,
  PromotionRule,
  PromotionRuleDraft,
} from '@spree/admin-sdk'
import { defaultPreferences } from '@/components/spree/preferences-form'

/**
 * Form-state row for a promotion rule. Carries everything the editor
 * needs to render (`key`, `label`, `preference_schema`) plus the
 * payload fields the SDK ships on save (extends `PromotionRuleDraft`).
 *
 * Drafts seeded from existing rules carry the server's `id`; drafts
 * created via the picker have no id until the parent form saves.
 */
export interface PromotionRuleFormDraft extends PromotionRuleDraft {
  /** Human-readable header rendered by the edit sheet. */
  label: string
  preference_schema: PreferenceField[]
  /** Client-side row id, used for React keys when the row has no server id yet. */
  _localId: string
  /**
   * Display-only embeds carried over from the server payload so row
   * summaries can render names without a separate fetch. Stripped at
   * payload time — the API only consumes the matching `*_ids`/preference
   * arrays. Re-set by the editors after Save so the summary refreshes
   * before the parent form persists.
   */
  products?: Product[]
  categories?: Category[]
  customers?: Customer[]
  customer_groups?: CustomerGroup[]
  countries?: Country[]
}

/** Mirrors `PromotionRuleFormDraft` for actions. */
export interface PromotionActionFormDraft extends Omit<PromotionActionDraft, 'calculator'> {
  label: string
  preference_schema: PreferenceField[]
  _localId: string
  /**
   * Form-only calculator shape — extends the API's `{ type, preferences }`
   * payload with display fields (`label`, `preference_schema`) so the
   * action-row summary can render the calculator preview without
   * round-tripping. Stripped at payload time by `actionDraftToPayload`.
   */
  calculator?: PromotionActionCalculatorFormDraft
}

export interface PromotionActionCalculatorFormDraft extends PromotionActionCalculatorParams {
  label?: string
  preference_schema?: PreferenceField[]
}

/**
 * Slot context for a promotion rule editor. Editors mutate the draft
 * locally and call `onSave(next)` to write back to the parent form;
 * the parent persists everything via a single `PATCH /promotions`
 * when the user hits Save on the page header.
 *
 * Slot key: `promotion.rule_form.<draft.type>`
 */
export interface PromotionRuleEditorContext {
  draft: PromotionRuleFormDraft
  onSave: (next: PromotionRuleFormDraft) => void
  onClose: () => void
}

/** Mirrors `PromotionRuleEditorContext` for actions. */
export interface PromotionActionEditorContext {
  draft: PromotionActionFormDraft
  onSave: (next: PromotionActionFormDraft) => void
  onClose: () => void
}

/**
 * Slot context for the one-line rule summary shown in the rules list —
 * "United States, Canada" for Country, "3 products · any" for Product.
 * Falls back to a generic preferences dump when no slot is registered.
 *
 * Slot key: `promotion.rule_summary.<draft.type>`
 */
export interface PromotionRuleSummaryContext {
  draft: PromotionRuleFormDraft
}

/** Mirrors `PromotionRuleSummaryContext` for actions. */
export interface PromotionActionSummaryContext {
  draft: PromotionActionFormDraft
}

const PROMOTION_RULE_FORM_SLOT_PREFIX = 'promotion.rule_form.'
const PROMOTION_ACTION_FORM_SLOT_PREFIX = 'promotion.action_form.'
const PROMOTION_RULE_SUMMARY_SLOT_PREFIX = 'promotion.rule_summary.'
const PROMOTION_ACTION_SUMMARY_SLOT_PREFIX = 'promotion.action_summary.'

export function ruleFormSlot(key: string): string {
  return `${PROMOTION_RULE_FORM_SLOT_PREFIX}${key}`
}

export function actionFormSlot(key: string): string {
  return `${PROMOTION_ACTION_FORM_SLOT_PREFIX}${key}`
}

export function ruleSummarySlot(key: string): string {
  return `${PROMOTION_RULE_SUMMARY_SLOT_PREFIX}${key}`
}

export function actionSummarySlot(key: string): string {
  return `${PROMOTION_ACTION_SUMMARY_SLOT_PREFIX}${key}`
}

let nextLocalId = 0
/** Unique id for a freshly-picked draft, used as the React key. */
export function newLocalId(): string {
  nextLocalId += 1
  return `draft-${nextLocalId}`
}

/**
 * Builds a fresh draft from a registry type definition (e.g. an entry
 * returned by `/promotion_rules/types`). The `_localId` lets React
 * track the row before the server assigns a real `id`.
 */
export function ruleDraftFromType(type: {
  type: string
  label: string
  preference_schema: PreferenceField[]
}): PromotionRuleFormDraft {
  return {
    _localId: newLocalId(),
    type: type.type,
    label: type.label,
    preference_schema: type.preference_schema,
    preferences: defaultPreferences(type.preference_schema),
  }
}

export function actionDraftFromType(type: {
  type: string
  label: string
  preference_schema: PreferenceField[]
}): PromotionActionFormDraft {
  return {
    _localId: newLocalId(),
    type: type.type,
    label: type.label,
    preference_schema: type.preference_schema,
    preferences: defaultPreferences(type.preference_schema),
  }
}

/** Materializes a draft from an existing server-side rule. */
export function ruleDraftFromRule(rule: PromotionRule): PromotionRuleFormDraft {
  return {
    _localId: rule.id,
    id: rule.id,
    type: rule.type,
    label: rule.label,
    preference_schema: rule.preference_schema,
    preferences: rule.preferences,
    product_ids: rule.product_ids ?? undefined,
    category_ids: rule.category_ids ?? undefined,
    customer_ids: rule.customer_ids ?? undefined,
    products: rule.products,
    categories: rule.categories,
    customers: rule.customers,
    customer_groups: rule.customer_groups,
    countries: rule.countries,
  }
}

export function actionDraftFromAction(action: PromotionAction): PromotionActionFormDraft {
  return {
    _localId: action.id,
    id: action.id,
    type: action.type,
    label: action.label,
    preference_schema: action.preference_schema,
    preferences: action.preferences,
    calculator: calculatorFromAction(action.calculator),
    line_items: action.line_items ?? undefined,
  }
}

function calculatorFromAction(
  c: PromotionAction['calculator'],
): PromotionActionCalculatorFormDraft | undefined {
  if (!c) return undefined
  return {
    type: c.type,
    preferences: c.preferences,
    label: c.label,
    preference_schema: c.preference_schema,
  }
}

/** Strips display-only fields before sending to the API. */
export function ruleDraftToPayload(draft: PromotionRuleFormDraft): PromotionRuleDraft {
  const {
    _localId: _,
    label: __,
    preference_schema: ___,
    products: ____,
    categories: _____,
    customers: ______,
    customer_groups: _______,
    countries: ________,
    ...rest
  } = draft
  return rest
}

export function actionDraftToPayload(draft: PromotionActionFormDraft): PromotionActionDraft {
  const { _localId: _, label: __, preference_schema: ___, calculator, ...rest } = draft
  return {
    ...rest,
    calculator: calculator
      ? { type: calculator.type, preferences: calculator.preferences }
      : undefined,
  }
}

// Re-exports for convenience (editors only need to import from one place).
export type { PromotionActionCalculatorParams, PromotionActionLineItemParams }
