/**
 * Per-file setup — reads credentials written by global-setup.ts.
 */
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

export interface TestCredentials {
  base_url: string
  publishable_key: string
  jwt_token: string
  user_email: string
  user_password: string
  product_slug: string
  product_id: string
  variant_id: string
  category_id: string
  category_permalink: string
  country_iso: string
  store_name: string
  bogus_payment_method_id: string
  check_payment_method_id: string
}

const CREDENTIALS_FILE = resolve(__dirname, '.credentials.json')

let credentials: TestCredentials | null = null

export function getCredentials(): TestCredentials {
  if (!credentials) {
    credentials = JSON.parse(readFileSync(CREDENTIALS_FILE, 'utf-8'))
  }
  return credentials!
}
