// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SupplierCreateParams = {
  name: string
  contact_name?: string | null
  email?: string | null
  phone?: string | null
  notes?: string | null
  address1?: string | null
  address2?: string | null
  city?: string | null
  state_name?: string | null
  state_code?: string | null
  country_code?: string | null
  postal_code?: string | null
  metadata?: Record<string, unknown> | null
}
