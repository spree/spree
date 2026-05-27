import type { PriceRuleFormDraft } from '@/schemas/price-list'

/**
 * Slot context for a price rule editor. Editors mutate the draft
 * locally and call `onSave(next)` to write back to the parent form;
 * the parent persists everything via a single `PATCH /price_lists`
 * when the user hits Save on the page header.
 *
 * Slot key: `price_list.rule_form.<draft.type>` (where `draft.type`
 * is the wire shorthand — e.g. `user_rule`, `customer_group_rule`,
 * `volume_rule`).
 */
export interface PriceRuleEditorContext {
  draft: PriceRuleFormDraft
  onSave: (next: PriceRuleFormDraft) => void
  onClose: () => void
}

const PRICE_RULE_FORM_SLOT_PREFIX = 'price_list.rule_form.'

export function ruleFormSlot(key: string): string {
  return `${PRICE_RULE_FORM_SLOT_PREFIX}${key}`
}
