// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CategoryRepositionParams = {
  /** The new parent. Omit or null to move the category to the top level. */
  new_parent_id?: string | null
  /** 0-based index among the new parent's children. */
  new_position: number
}
