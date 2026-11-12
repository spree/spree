// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { OptionValueParams } from './OptionValueParams'

export type OptionTypeUpdateParams = {
  name?: string
  label?: string
  position?: number
  filterable?: boolean
  kind?: 'dropdown' | 'color_swatch' | 'buttons'
  /**
   * Inline option values. Values left out of the list on update are destroyed, so send the full set
   * every time.
   */
  option_values?: OptionValueParams[]
}
