// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnReceiveParams = {
  /**
   * What arrived. Omit to receive all units still due, resellable. Name a line twice to split it.
   */
  items?: {
    return_line_item_id: string
    quantity: number
    /** Goods that cannot be resold are received but never restocked. Defaults to true. */
    resellable?: boolean
  }[]
}
