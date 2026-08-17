import type { ResourceFilterConfig } from '@spree/dashboard-core'
import { categoryAutocompleteProps } from '../../hooks/use-categories'
import { productAutocompleteProps } from '../../hooks/use-products'
import { vendorAutocompleteProps } from '../../hooks/use-vendors'

/**
 * How to pick records for a commission rule that names them.
 *
 * A registry rather than a branch in the form, because the server owns the
 * list of rule kinds (`commissionRates.ruleTypes()`) and may grow it. A kind
 * with no picker here still works — it renders its own preference schema —
 * so an extension's rule is usable before anyone teaches the dashboard about
 * it, and better once they do.
 *
 * Each entry is the shared autocomplete config the rest of the dashboard
 * already uses for that resource, so a category picked here shows its full
 * path exactly as it does on a product — everything a
 * `<ResourceMultiAutocomplete>` needs bar the value/onChange the form supplies.
 *
 * The record type is `any` for the same reason the table registry's
 * `filterResource` is: pickers for different resources cannot be stored under
 * one key otherwise, since each one's `getOptionLabel` accepts only its own
 * record.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommissionRuleSubjectPicker = (queryKey: string) => ResourceFilterConfig<any>

// Keyed by rule kind, matching the `type` the discovery endpoint reports.
const PICKERS: Record<string, CommissionRuleSubjectPicker> = {
  vendor_rule: vendorAutocompleteProps,
  product_rule: productAutocompleteProps,
  category_rule: categoryAutocompleteProps,
}

/**
 * The picker for a rule kind, or undefined when the kind names no records —
 * a value band configures itself through its preference schema instead.
 *
 * @param ruleType e.g. `vendor_rule`
 */
export function commissionRuleSubjectPicker(
  ruleType: string,
): CommissionRuleSubjectPicker | undefined {
  return PICKERS[ruleType]
}

/**
 * Registers a picker for a rule kind an extension has added, so its condition
 * gets a proper resource picker rather than a raw id field.
 */
export function registerCommissionRuleSubjectPicker(
  ruleType: string,
  picker: CommissionRuleSubjectPicker,
): void {
  PICKERS[ruleType] = picker
}
