import { z } from 'zod/v4'

export const FULFILLMENT_TYPES = ['shipping', 'digital', 'pickup', 'pickup_point'] as const

/**
 * One eligibility rule as held in form state. `id` is absent for rules added
 * in this editing session; `product_ids` is only used by association-backed
 * kinds and stays empty elsewhere.
 */
export const deliveryMethodRuleSchema = z.object({
  id: z.string().optional(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  product_ids: z.array(z.string()),
})

export type DeliveryMethodRuleDraft = z.infer<typeof deliveryMethodRuleSchema>

export const deliveryMethodFormSchema = z.object({
  name: z.string().min(1),
  admin_name: z.string().optional(),
  code: z.string().optional(),
  fulfillment_type: z.enum(FULFILLMENT_TYPES),
  fulfillment_provider: z.string(),
  storefront_visible: z.boolean(),
  tracking_url: z.string().optional(),
  estimated_transit_business_days_min: z.string().optional(),
  estimated_transit_business_days_max: z.string().optional(),
  tax_category_id: z.string().optional(),
  calculator_type: z.string().optional(),
  calculator_preferences: z.record(z.string(), z.unknown()).optional(),
  delivery_zone_ids: z.array(z.string()),
  stock_location_ids: z.array(z.string()),
  rules: z.array(deliveryMethodRuleSchema),
})

export type DeliveryMethodFormValues = z.infer<typeof deliveryMethodFormSchema>

export const DELIVERY_METHOD_DEFAULTS: DeliveryMethodFormValues = {
  name: '',
  admin_name: '',
  code: '',
  fulfillment_type: 'shipping',
  fulfillment_provider: 'Spree::FulfillmentProvider::Manual',
  storefront_visible: true,
  tracking_url: '',
  estimated_transit_business_days_min: '',
  estimated_transit_business_days_max: '',
  tax_category_id: '',
  calculator_type: '',
  calculator_preferences: {},
  delivery_zone_ids: [],
  stock_location_ids: [],
  rules: [],
}

export function deliveryMethodValuesToParams(values: DeliveryMethodFormValues) {
  return {
    name: values.name,
    admin_name: values.admin_name || null,
    code: values.code || null,
    fulfillment_type: values.fulfillment_type,
    fulfillment_provider: values.fulfillment_provider,
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
    delivery_zone_ids: values.delivery_zone_ids,
    stock_location_ids: values.stock_location_ids,
    // Rules ride along with the method so one request saves the whole sheet.
    // Omitting `id` marks a rule as new; dropping one from the array deletes it.
    rules: values.rules.map((rule) => ({
      ...(rule.id ? { id: rule.id } : {}),
      type: rule.type,
      preferences: rule.preferences,
      ...(rule.product_ids.length > 0 ? { product_ids: rule.product_ids } : {}),
    })),
  }
}
