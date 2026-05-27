import type {
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import { z } from 'zod/v4'
import { blankToUndefined, emptyToUndefined } from '@/lib/form-mappers'
import { requiredMessage } from '@/lib/validation-messages'

// Labels live in `en.json` under `admin.stock_locations.kinds.*` and
// `admin.stock_locations.pickup_stock_policies.*`. Consumers map these
// values to translated labels at render time.
export const STOCK_LOCATION_KINDS = ['warehouse', 'store', 'fulfillment_center'] as const
export const PICKUP_STOCK_POLICIES = ['local', 'any'] as const
export type PickupStockPolicy = (typeof PICKUP_STOCK_POLICIES)[number]

export const stockLocationFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('name') }),
  admin_name: z.string().optional(),
  kind: z.enum(STOCK_LOCATION_KINDS),
  active: z.boolean(),
  default: z.boolean(),
  propagate_all_variants: z.boolean(),
  backorderable_default: z.boolean(),
  address1: z.string().optional(),
  address2: z.string().optional(),
  city: z.string().optional(),
  zipcode: z.string().optional(),
  phone: z.string().optional(),
  company: z.string().optional(),
  country_iso: z.string().optional(),
  state_abbr: z.string().optional(),
  state_name: z.string().optional(),
  pickup_enabled: z.boolean(),
  pickup_stock_policy: z.enum(PICKUP_STOCK_POLICIES),
  pickup_ready_in_minutes: z.preprocess(
    emptyToUndefined,
    z.coerce.number().int().min(0).optional().nullable(),
  ),
  pickup_instructions: z.string().optional(),
})

export type StockLocationFormValues = z.infer<typeof stockLocationFormSchema>

export const STOCK_LOCATION_DEFAULTS: StockLocationFormValues = {
  name: '',
  admin_name: '',
  kind: 'warehouse',
  active: true,
  default: false,
  propagate_all_variants: false,
  backorderable_default: false,
  address1: '',
  address2: '',
  city: '',
  zipcode: '',
  phone: '',
  company: '',
  country_iso: '',
  state_abbr: '',
  state_name: '',
  pickup_enabled: false,
  pickup_stock_policy: 'local',
  pickup_ready_in_minutes: null,
  pickup_instructions: '',
}

export function stockLocationToFormValues(sl: StockLocation): StockLocationFormValues {
  return {
    name: sl.name,
    admin_name: sl.admin_name ?? '',
    kind: STOCK_LOCATION_KINDS.includes(sl.kind as (typeof STOCK_LOCATION_KINDS)[number])
      ? (sl.kind as (typeof STOCK_LOCATION_KINDS)[number])
      : 'warehouse',
    active: sl.active,
    default: sl.default,
    propagate_all_variants: sl.propagate_all_variants,
    backorderable_default: sl.backorderable_default,
    address1: sl.address1 ?? '',
    address2: sl.address2 ?? '',
    city: sl.city ?? '',
    zipcode: sl.zipcode ?? '',
    phone: sl.phone ?? '',
    company: sl.company ?? '',
    country_iso: sl.country_iso ?? '',
    state_abbr: sl.state_abbr ?? '',
    state_name: sl.state_name ?? '',
    pickup_enabled: sl.pickup_enabled,
    pickup_stock_policy: PICKUP_STOCK_POLICIES.includes(sl.pickup_stock_policy as PickupStockPolicy)
      ? (sl.pickup_stock_policy as PickupStockPolicy)
      : 'local',
    pickup_ready_in_minutes: sl.pickup_ready_in_minutes ?? null,
    pickup_instructions: sl.pickup_instructions ?? '',
  }
}

// Drops blank strings → undefined so we don't overwrite null fields with "".
export function formValuesToParams(
  v: StockLocationFormValues,
): StockLocationCreateParams & StockLocationUpdateParams {
  return {
    name: v.name,
    admin_name: blankToUndefined(v.admin_name),
    kind: v.kind,
    active: v.active,
    default: v.default,
    propagate_all_variants: v.propagate_all_variants,
    backorderable_default: v.backorderable_default,
    address1: blankToUndefined(v.address1),
    address2: blankToUndefined(v.address2),
    city: blankToUndefined(v.city),
    zipcode: blankToUndefined(v.zipcode),
    phone: blankToUndefined(v.phone),
    company: blankToUndefined(v.company),
    country_iso: blankToUndefined(v.country_iso),
    state_abbr: blankToUndefined(v.state_abbr),
    state_name: blankToUndefined(v.state_name),
    pickup_enabled: v.pickup_enabled,
    pickup_stock_policy: v.pickup_stock_policy,
    pickup_ready_in_minutes: v.pickup_ready_in_minutes ?? null,
    pickup_instructions: blankToUndefined(v.pickup_instructions),
  }
}
