import { adminClient, setApiClient } from '@spree/dashboard-core'

/**
 * Registers the Admin API client as this panel's client.
 *
 * `@spree/dashboard-core` is shared with the seller panel, which talks to a
 * different API with different credentials, so the framework holds no client
 * of its own — each host installs one. Side-effect import, run before any
 * provider mounts.
 */
setApiClient({
  auth: adminClient.auth,
  setToken: (token: string) => adminClient.setToken(token),
  onUnauthorized: (handler) => adminClient.onUnauthorized(handler),
  clearTenant: () => adminClient.setStore(''),
  fetchPermissions: async () => {
    const response = await adminClient.me.get()

    return { rules: response.permissions, keys: response.permission_keys ?? [] }
  },
})
