// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type LoginParams = {
  /** The authentication method. Defaults to `email`. */
  provider?: 'email'
  email: string
  password: string
}
