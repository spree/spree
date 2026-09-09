import type { PermissionRule } from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, type ReactNode, useCallback, useContext, useMemo } from 'react'
import { getApiClient } from '../api-client'
import { useAuth } from '../hooks/use-auth'
import type { ActionName, SubjectName } from '../lib/permissions'
import { useResourceKey } from '../lib/query-keys'
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
   * Reloads `/me`. Permissions are store-scoped (roles are held per store),
   * so the store route calls this whenever the active store changes.
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

export function PermissionProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth()
  const queryClient = useQueryClient()
  // Store-scoped by construction: `useResourceKey` folds the tenant id in, so
  // switching store changes the key and TanStack refetches on its own — no
  // manual reload, and no chance of one store's rules being shown for another.
  const queryKey = useResourceKey(PERMISSIONS_RESOURCE)

  const query = useQuery({
    queryKey,
    queryFn: () => getApiClient().fetchPermissions(),
    enabled: isAuthenticated,
    // Permissions change when an admin's role does, which is rare and happens
    // elsewhere. Refetching them on every window focus costs a request on the
    // shell's critical path and almost never returns anything new.
    staleTime: 5 * 60 * 1000,
  })

  const rules = query.data?.rules ?? EMPTY_RULES
  const permissionKeys = query.data?.keys ?? EMPTY_KEYS

  // `useResourceKey` returns a fresh array each render, so depending on it
  // directly would give `refresh` a new identity every render — and a consumer
  // holding it in an effect's dependencies would then re-run that effect
  // forever. Depend on the tenant id (a string) and rebuild the key inside.
  const tenantId = useTenantId()
  const refresh = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: [PERMISSIONS_RESOURCE, tenantId] })
  }, [queryClient, tenantId])

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
        // `isPending` stays true for a disabled query, which would leave the
        // shell in a loading state forever on the sign-in screen. This is
        // "a request is genuinely in flight".
        isLoading: query.isFetching,
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
