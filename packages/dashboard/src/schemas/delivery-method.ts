import { z } from 'zod/v4'

/**
 * One eligibility rule as held in form state. `id` is absent for rules added
 * in this editing session. `takes_products` comes from the rule-type discovery
 * endpoint and decides whether `product_ids` is part of this rule's payload —
 * it is display-only state, stripped before send.
 */
export const deliveryMethodRuleSchema = z.object({
  id: z.string().optional(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  product_ids: z.array(z.string()),
  takes_products: z.boolean(),
})

export type DeliveryMethodRuleDraft = z.infer<typeof deliveryMethodRuleSchema>

/**
 * One carrier service row: a service the method offers, with an optional
 * customer-facing label and markup override. No rows on a provider-priced
 * method means "offer everything the carrier returns".
 */
export const deliveryMethodServiceSchema = z.object({
  id: z.string().optional(),
  carrier: z.string().min(1),
  service: z.string().min(1),
  label: z.string().optional(),
  markup_flat: z.string().optional(),
  markup_percent: z.string().optional(),
})

export type DeliveryMethodServiceDraft = z.infer<typeof deliveryMethodServiceSchema>

export const deliveryMethodFormSchema = z.object({
  name: z.string().min(1),
  admin_name: z.string().optional(),
  code: z.string().optional(),
  fulfillment_provider: z.string(),
  // Empty string means the built-in Internal provider (calculator-priced).
  rate_provider: z.string(),
  storefront_visible: z.boolean(),
  tracking_url: z.string().optional(),
  estimated_transit_business_days_min: z.string().optional(),
  estimated_transit_business_days_max: z.string().optional(),
  tax_category_id: z.string().optional(),
  calculator_type: z.string().optional(),
  calculator_preferences: z.record(z.string(), z.unknown()).optional(),
  // Empty string means no destination restriction — the method serves
  // everywhere its profile reaches.
  delivery_zone_id: z.string(),
  stock_location_ids: z.array(z.string()),
  rules: z.array(deliveryMethodRuleSchema),
  markup_flat: z.string().optional(),
  markup_percent: z.string().optional(),
  services: z.array(deliveryMethodServiceSchema),
})

export type DeliveryMethodFormValues = z.infer<typeof deliveryMethodFormSchema>

export const DELIVERY_METHOD_DEFAULTS: DeliveryMethodFormValues = {
  name: '',
  admin_name: '',
  code: '',
  fulfillment_provider: 'Spree::FulfillmentProvider::Manual',
  rate_provider: '',
  storefront_visible: true,
  tracking_url: '',
  estimated_transit_business_days_min: '',
  estimated_transit_business_days_max: '',
  tax_category_id: '',
  calculator_type: '',
  calculator_preferences: {},
  delivery_zone_id: '',
  stock_location_ids: [],
  rules: [],
  markup_flat: '',
  markup_percent: '',
  services: [],
}

export function deliveryMethodValuesToParams(values: DeliveryMethodFormValues) {
  return {
    name: values.name,
    admin_name: values.admin_name || null,
    code: values.code || null,
    fulfillment_provider: values.fulfillment_provider,
    rate_provider: values.rate_provider || null,
    storefront_visible: values.storefront_visible,
    tracking_url: values.tracking_url || null,
    estimated_transit_business_days_min: values.estimated_transit_business_days_min
      ? Number(values.estimated_transit_business_days_min)
      : null,
    estimated_transit_business_days_max: values.estimated_transit_business_days_max
      ? Number(values.estimated_transit_business_days_max)
      : null,
    tax_category_id: values.tax_category_id || null,
    ...(values.calculator_type ? { calculator_type: values.calculator_type } : {}),
    ...(values.calculator_preferences && Object.keys(values.calculator_preferences).length > 0
      ? { calculator_preferences: values.calculator_preferences }
      : {}),
    delivery_zone_id: values.delivery_zone_id || null,
    stock_location_ids: values.stock_location_ids,
    // Rules ride along with the method so one request saves the whole page.
    // Omitting `id` marks a rule as new; dropping one from the array deletes
    // it. `product_ids` is always sent for association-backed rules — omitting
    // an emptied array would read as "leave unchanged" and silently keep the
    // exclusions the merchant just removed.
    rules: values.rules.map((rule) => ({
      ...(rule.id ? { id: rule.id } : {}),
      type: rule.type,
      preferences: rule.preferences,
      ...(rule.takes_products ? { product_ids: rule.product_ids } : {}),
    })),
    markup_flat: values.markup_flat || null,
    markup_percent: values.markup_percent || null,
    // Service rows follow the rules convention: the array replaces the full
    // set, omitted rows are removed, and an empty array clears them (back to
    // "offer every service").
    services: values.services.map((row) => ({
      ...(row.id ? { id: row.id } : {}),
      carrier: row.carrier,
      service: row.service,
      label: row.label || null,
      markup_flat: row.markup_flat || null,
      markup_percent: row.markup_percent || null,
    })),
  }
}
