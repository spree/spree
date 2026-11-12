// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type IntegrationCreateParams = {
  /** Wire shorthand from the integration types endpoint. */
  type: string
  /** Activating runs the connection check, and a failed check is a 422. */
  active?: boolean
  /**
   * Credential values. Secret preferences come back masked, and sending a masked value back keeps
   * the stored secret.
   */
  preferences?: Record<string, unknown>
}
