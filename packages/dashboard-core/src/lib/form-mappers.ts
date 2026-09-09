/**
 * Treat a blank or whitespace-only string as "not set" — common when mapping
 * form values to API params, where a blank `<input>` should become `undefined`
 * (omit the field) or `null` (clear the server value) rather than passing the
 * empty string through. Returns the trimmed value when present.
 */
export function blankToUndefined(s: string | null | undefined): string | undefined {
  const trimmed = s?.trim()
  return trimmed ? trimmed : undefined
}

export function blankToNull(s: string | null | undefined): string | null {
  const trimmed = s?.trim()
  return trimmed ? trimmed : null
}

/**
 * Preprocessor for Zod optional-number fields backed by `<input type="number">`.
 * Empty inputs return `''`, which `z.coerce.number()` would coerce to `0` —
 * tripping `.positive()` / `.min()` on otherwise-optional fields. Map empty
 * to `undefined` so the optional branch wins.
 *
 * ```ts
 * usage_limit: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional())
 * ```
 */
export function emptyToUndefined(value: unknown): unknown {
  if (value === '' || value === null) return undefined
  return value
}

/**
 * The address columns a stock location carries, in either panel's SDK shape.
 * Structural rather than either `StockLocation` type so both the admin and
 * seller panels can map their own rows through the helpers below.
 */
export interface StockLocationAddressFields {
  company?: string | null
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  state_code?: string | null
  state_text?: string | null
  country_code?: string | null
  country_name?: string | null
  phone?: string | null
}

/**
 * The three shapes a stock location's address sits between. A location stores
 * `zipcode` where an address says `postal_code`, and carries no personal name
 * — mapping the fields explicitly keeps that difference in one place instead
 * of leaking a cast into every call.
 */
export function stockLocationToAddressBlock(location: StockLocationAddressFields) {
  return {
    company: location.company,
    address1: location.address1,
    address2: location.address2,
    city: location.city,
    state_text: location.state_text,
    postal_code: location.zipcode,
    country_code: location.country_code,
    country_name: location.country_name,
    phone: location.phone,
  }
}

export function stockLocationToEditableAddress(
  location: StockLocationAddressFields & { id: string },
) {
  return {
    id: location.id,
    company: location.company,
    address1: location.address1,
    address2: location.address2,
    city: location.city,
    postal_code: location.zipcode,
    country_code: location.country_code,
    state_code: location.state_code,
    phone: location.phone,
  }
}

export function editableAddressToStockLocationParams(values: {
  company?: string | null
  address1?: string | null
  address2?: string | null
  city?: string | null
  postal_code?: string | null
  country_code?: string | null
  state_code?: string | null
  phone?: string | null
}) {
  return {
    company: values.company,
    address1: values.address1,
    address2: values.address2,
    city: values.city,
    zipcode: values.postal_code,
    country_code: values.country_code,
    state_code: values.state_code,
    phone: values.phone,
  }
}
