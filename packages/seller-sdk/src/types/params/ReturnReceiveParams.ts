// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnReceiveParams = {
  /** What actually arrived. Omit to receive everything as requested and resellable. */
  items?: {
    return_line_item_id: string
    quantity: number
    /** Defaults to true. */
    resellable?: boolean
  }[]
}
