// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateDataRequestParams = {
  /** Defaults to `access`. */
  kind?: 'access' | 'erasure'
  /** Required for `erasure`. */
  current_password?: string
}
