import { createAdminClient } from '@spree/admin-sdk'

const baseUrl = import.meta.env.VITE_SPREE_API_URL || 'http://localhost:3000'

const TOKEN_KEY = 'spree_admin_token'

export const adminClient = createAdminClient({
  baseUrl,
  jwtToken: localStorage.getItem(TOKEN_KEY) ?? '',
})
