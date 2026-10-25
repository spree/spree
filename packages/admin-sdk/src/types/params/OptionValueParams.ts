// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OptionValueParams = {
  /** Present for existing values. Omit to create a new one. */
  id?: string
  name?: string
  label?: string
  position?: number
  /** Hex color. Only meaningful when the option type's `kind` is `color_swatch`. */
  color_code?: string | null
  /** A `signed_id` from `files.upload()`, or null to remove the image. */
  image_signed_id?: string | null
}
