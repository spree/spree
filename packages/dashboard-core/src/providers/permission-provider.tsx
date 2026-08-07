import type { PermissionRule } from '@spree/admin-sdk'
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import { adminClient } from '../client'
import { useAuth } from '../hooks/use-auth'
import type { ActionName, SubjectName } from '../lib/permissions'

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

/** Empty permissions that deny everything — used before rules are loaded. */
const EMPTY_PERMISSIONS: Permissions = {
  can: () => false,
  cannot: () => true,
  isConditional: () => false,
}

export function PermissionProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth()
  const [rules, setRules] = useState<PermissionRule[]>([])
  const [permissionKeys, setPermissionKeys] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(false)
  // Guards against out-of-order `/me` responses: a rapid store switch (or a
  // logout) bumps the generation, and any response from a superseded request
  // is dropped instead of overwriting the current store's permissions.
  const requestGeneration = useRef(0)

  const refresh = useCallback(async () => {
    const generation = ++requestGeneration.current
    setIsLoading(true)
    try {
      const res = await adminClient.me.get()
      if (generation !== requestGeneration.current) return
      setRules(res.permissions)
      setPermissionKeys(res.permission_keys ?? [])
    } catch {
      if (generation !== requestGeneration.current) return
      setRules([])
      setPermissionKeys([])
    } finally {
      if (generation === requestGeneration.current) setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!isAuthenticated) {
      requestGeneration.current += 1
      setRules([])
      setPermissionKeys([])
      setIsLoading(false)
      return
    }

    void refresh()
  }, [isAuthenticated, refresh])

  const permissions = useMemo(
    () => (rules.length > 0 ? buildPermissions(rules) : EMPTY_PERMISSIONS),
    [rules],
  )

  return (
    <PermissionContext.Provider value={{ permissions, rules, permissionKeys, isLoading, refresh }}>
      {children}
    </PermissionContext.Provider>
  )
}

export function usePermissions(): PermissionContextValue {
  const ctx = useContext(PermissionContext)
  if (!ctx) throw new Error('usePermissions must be used within a PermissionProvider')
  return ctx
}
