/**
 * The client registry.
 *
 * `@spree/dashboard-core` is the framework behind more than one panel: the
 * marketplace operator's dashboard talks to the Admin API, a seller's panel
 * talks to the Seller API. Those are different surfaces with different
 * credentials — a seller JWT and `X-Spree-Seller-Id` rather than a secret key
 * and a store header — so the framework cannot own either client. Each host
 * builds its own and registers it here at boot.
 *
 * Only the surface both panels share is typed. Anything admin-only
 * (`customFieldDefinitions`, `exports`, `imports`, store switching) stays on
 * the admin client, imported directly by the code that needs it — typing it
 * here would promise the seller panel methods its API does not have.
 */

import type { PermissionRule } from '@spree/admin-sdk'

/** What the permission provider needs, whichever panel asked. */
export interface PanelPermissions {
  /**
   * CanCanCan rules. The seller panel returns none — its capability is the
   * key list alone — so an empty array is a valid answer, not a failure.
   */
  rules: PermissionRule[]
  keys: string[]
}

/** What every panel's client can do, whichever API it talks to. */
export interface PanelApiClient {
  auth: {
    login(params: { email: string; password: string }): Promise<PanelSession>
    refresh(): Promise<PanelSession>
    logout(): Promise<void>
    /**
     * Optional sign-in flows, because not every panel offers all of them.
     * Both panels accept invitations — each against its own API, so the
     * session that comes back carries the right audience. Password reset and
     * first-run setup remain the marketplace's own, so a seller's client
     * leaves them undefined.
     */
    acceptInvitation?(id: string, token: string, params: unknown): Promise<PanelSession>
    resetPassword?(token: string, params: unknown): Promise<PanelSession>
    completeSetup?(params: unknown): Promise<PanelSession>
  }
  setToken(token: string): void
  onUnauthorized(handler: () => Promise<boolean>): void
  /**
   * Forgets which tenant the session was acting as — the store on the admin
   * panel, the seller on a seller's. Left set, it rides into the next
   * principal's first requests and 403s them against a tenant they may hold
   * no role on.
   */
  clearTenant?(): void
  /**
   * Reads the signed-in principal's capability. Panel-specific because the
   * two APIs answer different shapes: the admin `/me` returns CanCanCan rules
   * and keys, the seller `/me` returns keys scoped to the selected seller.
   */
  fetchPermissions(): Promise<PanelPermissions>
  /**
   * Countries (with their states) for the shared address form.
   *
   * Registered rather than imported, for the same reason as everything else
   * here: reaching for `adminClient` would make the one address form work
   * only in the operator's panel, and a seller filling in a billing address
   * would get an empty country list.
   */
  listCountries?(): Promise<{ data: PanelCountry[] }>
}

/**
 * A country as the address form needs it. Structural, not the Admin SDK's
 * `Country`: both panels' country endpoints answer this shape, and typing
 * the wider one here would bind core to a package a seller's panel does not
 * install.
 */
export interface PanelCountry {
  iso: string
  iso3: string
  name: string
  states_required?: boolean
  zipcode_required?: boolean
  states?: Array<{ abbr: string; name: string }>
}

/** What a sign-in returns, whichever panel asked. */
export interface PanelSession {
  token: string
  // Panel-specific: an AdminUser here, the same class through the seller API.
  // Typed loosely so core does not depend on either package's user type.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  user: any
}

let registered: PanelApiClient | null = null

/**
 * Registers the client for this panel. Call once at boot, before rendering —
 * providers read it on mount.
 */
export function setApiClient(client: PanelApiClient): void {
  registered = client
}

/**
 * The registered client.
 *
 * Throws rather than returning null: a panel that renders without registering
 * one is misconfigured, and every call would otherwise fail somewhere further
 * away with a less useful message.
 */
export function getApiClient(): PanelApiClient {
  if (!registered) {
    throw new Error(
      '@spree/dashboard-core: no API client registered. Call setApiClient(client) at boot, ' +
        'before rendering the app.',
    )
  }

  return registered
}

/** Whether a client has been registered. For tests and conditional boot paths. */
export function hasApiClient(): boolean {
  return registered !== null
}
