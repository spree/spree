import type { ActionName, SubjectName } from '@spree/dashboard-core'
import { usePermissions } from '@spree/dashboard-core'
import type { ReactNode } from 'react'

interface CanProps {
  /** Action name (e.g. "update", "destroy", "manage") */
  I: ActionName
  /** Subject class name (e.g. "Spree::Product") */
  a: SubjectName
  children: ReactNode
  fallback?: ReactNode
}

/**
 * Declarative permission check. Renders `children` if the current user
 * can perform `I` on `a`, otherwise renders `fallback` (or nothing).
 *
 * Example:
 *   <Can I="destroy" a="Spree::Product">
 *     <Button onClick={handleDelete}>Delete</Button>
 *   </Can>
 *
 * Note: This is purely for UX. The backend still enforces CanCanCan
 * `authorize!` on every request — never rely on the frontend check
 * for security.
 */
export function Can({ I, a, children, fallback = null }: CanProps) {
  const { permissions } = usePermissions()
  return <>{permissions.can(I, a) ? children : fallback}</>
}
