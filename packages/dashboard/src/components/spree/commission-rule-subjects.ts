import type { ResourceFilterConfig } from '@spree/dashboard-core'
import { categoryAutocompleteProps } from '../../hooks/use-categories'
import { productAutocompleteProps } from '../../hooks/use-products'
import { vendorAutocompleteProps } from '../../hooks/use-vendors'

/**
 * How to pick a record for each kind of commission-rule target.
 *
 * A registry rather than a branch in the form, because the server owns the
 * list of targetable types (`commissionRates.ruleSubjectTypes()`) and may grow
 * it — a channel, a market. Adding one here is then the whole client-side
 * change, and a type nobody has registered yet still renders as itself rather
 * than silently disappearing.
 *
 * Each entry is the shared autocomplete config the rest of the dashboard
 * already uses for that resource, so a category picked here shows its full
 * path exactly as it does on a product.
 */
/**
 * Everything a `<ResourceMultiAutocomplete>` needs to search one resource,
 * minus the value/onChange the form supplies — the shape the shared
 * `*AutocompleteProps` helpers already return.
 *
 * The record type is `any` for the same reason the table registry's
 * `filterResource` is: pickers for different resources cannot be stored under
 * one key otherwise, since each one's `getOptionLabel` accepts only its own
 * record.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommissionRuleSubjectPicker = (queryKey: string) => ResourceFilterConfig<any>

const PICKERS: Record<string, CommissionRuleSubjectPicker> = {
  'Spree::Vendor': vendorAutocompleteProps,
  'Spree::Product': productAutocompleteProps,
  'Spree::Category': categoryAutocompleteProps,
}

/**
 * The picker for a subject type, or undefined when nothing has registered one.
 *
 * @param subjectType e.g. `Spree::Vendor`
 */
export function commissionRuleSubjectPicker(
  subjectType: string,
): CommissionRuleSubjectPicker | undefined {
  return PICKERS[subjectType]
}

/**
 * Registers a picker for a subject type an extension has added to the catalog.
 */
export function registerCommissionRuleSubjectPicker(
  subjectType: string,
  picker: CommissionRuleSubjectPicker,
): void {
  PICKERS[subjectType] = picker
}
