/**
 * Shape of a Brand record as returned by the (hypothetical) Brands Admin API.
 * A real plugin would generate this from its serializer via the Typelizer
 * pipeline (see CLAUDE.md → Type Generation Pipeline); we hand-write it here
 * to keep the example self-contained.
 */
export interface Brand {
  id: string
  name: string
  slug: string
  description: string | null
  logo_url: string | null
  products_count: number
  created_at: string
  updated_at: string
}

export interface BrandCreateParams {
  name: string
  slug?: string
  description?: string | null
}

export type BrandUpdateParams = Partial<BrandCreateParams>
