// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnReceiveParams = {
  /**
   * What actually arrived. Omit to receive everything as requested and resellable; send rows for a
   * partial or damaged receipt.
   */
  items?: {
    return_line_item_id: string
    quantity: number
    /** Goods that cannot be resold are received but never restocked. Defaults to true. */
    resellable?: boolean
  }[]
}
