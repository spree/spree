import type { PermissionRule } from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, type ReactNode, useCallback, useContext, useMemo } from 'react'
import { getApiClient } from '../api-client'
import { useAuth } from '../hooks/use-auth'
import type { ActionName, SubjectName } from '../lib/permissions'
import { useTenantId } from './tenant-provider'

/**
 * Matcher that mirrors CanCanCan semantics:
 *   - `manage` action matches any action
 *   - `all` subject matches any subject
 *   - Later rules override earlier rules (last-matching-wins)
 *
 * Per-record conditions are NOT evaluated — they stay on the server. The
 * `isConditional` flag indicates that a rule may still be rejected at the
 * per-record level, so the UI should expect possible 403 from the API.
 */
export interface Permissions {
  can: (action: ActionName, subject: SubjectName) => boolean
  cannot: (action: ActionName, subject: SubjectName) => boolean
  /** True if the matching rule has per-record conditions. Caller should expect possible 403. */
  isConditional: (action: ActionName, subject: SubjectName) => boolean
}

interface PermissionContextValue {
  permissions: Permissions
  rules: PermissionRule[]
  /**
   * The flat expanded catalog permission keys the user holds on the current
   * store (`read_orders`, `write_products`, …) — the same vocabulary as API
   * key scopes and the role editor.
   */
  permissionKeys: string[]
  isLoading: boolean
  /**
   * Reloads `/me`. The seller panel calls this when the seller changes, since
   * its provider is not told which seller is open.
   */
  refresh: () => Promise<void>
}

const PermissionContext = createContext<PermissionContextValue | null>(null)

function ruleMatches(rule: PermissionRule, action: string, subject: string): boolean {
  const actionMatch = rule.actions.includes(action) || rule.actions.includes('manage')
  const subjectMatch = rule.subjects.includes(subject) || rule.subjects.includes('all')
  return actionMatch && subjectMatch
}

export function buildPermissions(rules: PermissionRule[]): Permissions {
  const can = (action: ActionName, subject: SubjectName): boolean => {
    // Walk rules in order — later matching rules override earlier ones
    let allowed = false
    for (const rule of rules) {
      if (ruleMatches(rule, action, subject)) {
        allowed = rule.allow
      }
    }
    return allowed
  }

  return {
    can,
    cannot: (action, subject) => !can(action, subject),
    isConditional: (action, subject) => {
      let conditional = false
      for (const rule of rules) {
        if (ruleMatches(rule, action, subject) && rule.allow && rule.has_conditions) {
          conditional = true
        }
      }
      return conditional
    },
  }
}

/**
 * Query resource name for the permission fetch. Exported so anything else
 * reading the same `/me` response can share this cache entry rather than
 * issuing a second identical request.
 */
export const PERMISSIONS_RESOURCE = 'permissions'

/** Stable identities, so `data ?? []` doesn't produce a new array each render. */
const EMPTY_RULES: PermissionRule[] = []
const EMPTY_KEYS: string[] = []

/** Empty permissions that deny everything — used before rules are loaded. */
const EMPTY_PERMISSIONS: Permissions = {
  can: () => false,
  cannot: () => true,
  isConditional: () => false,
}

export function PermissionProvider({
  tenantId,
  children,
}: {
  /**
   * The store (or seller) the panel is acting as. Roles are held per store,
   * so this is part of the query key: opening another store loads its
   * permissions instead of reusing the last one's. Pass it when the provider
   * sits above the router, where the store route's `StoreProvider` is out of
   * reach; without it the key falls back to `useTenantId()`.
   */
  tenantId?: string
  children: ReactNode
}) {
  const { isAuthenticated } = useAuth()
  const queryClient = useQueryClient()
  const contextTenantId = useTenantId()
  const activeTenantId = tenantId ?? contextTenantId

  const query = useQuery({
    queryKey: [PERMISSIONS_RESOURCE, activeTenantId],
    queryFn: () => getApiClient().fetchPermissions(),
    enabled: isAuthenticated,
    // Permissions change when an admin's role does, which is rare and happens
    // elsewhere. Refetching them on every window focus costs a request on the
    // shell's critical path and almost never returns anything new.
    staleTime: 5 * 60 * 1000,
  })

  const rules = query.data?.rules ?? EMPTY_RULES
  const permissionKeys = query.data?.keys ?? EMPTY_KEYS

  const refresh = useCallback(async () => {
    const permissionsKey = [PERMISSIONS_RESOURCE, activeTenantId]
    // A refresh asks for the rules as they stand now. A first fetch still in
    // flight was sent before — in the seller panel, before any seller was
    // chosen — and with nothing cached TanStack hands that same fetch back
    // rather than starting another, so it is cancelled first.
    await queryClient.cancelQueries({ queryKey: permissionsKey })
    await queryClient.invalidateQueries({ queryKey: permissionsKey })
  }, [queryClient, activeTenantId])

  const permissions = useMemo(
    () => (rules.length > 0 ? buildPermissions(rules) : EMPTY_PERMISSIONS),
    [rules],
  )

  return (
    <PermissionContext.Provider
      value={{
        permissions,
        rules,
        permissionKeys,
        // The first load only, which is what the nav's skeleton is for. Not
        // `isFetching` alone: that is also true while a stale query refetches
        // in the background, so an already-rendered nav would drop back to
        // placeholders on every refresh — the flicker the skeleton exists to
        // remove. Not `isPending` alone either: it stays true for a disabled
        // query, leaving the sign-in screen loading forever. Both together
        // mean "signed in, nothing cached yet, a request in flight".
        isLoading: isAuthenticated && query.isPending && query.isFetching,
        refresh,
      }}
    >
      {children}
    </PermissionContext.Provider>
  )
}

export function usePermissions(): PermissionContextValue {
  const ctx = useContext(PermissionContext)
  if (!ctx) throw new Error('usePermissions must be used within a PermissionProvider')
  return ctx
}
