import { createSpreeClient } from '@spree/sdk'

export const spreeClient = createSpreeClient({
  baseUrl: import.meta.env.VITE_SPREE_API_URL || 'http://localhost:3000',
  secretKey: import.meta.env.VITE_SPREE_SECRET_KEY,
})
