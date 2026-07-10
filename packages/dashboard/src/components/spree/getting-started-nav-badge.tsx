import { useStore } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'

// Progress counter next to the Getting Started nav entry, mirroring the
// legacy admin's "n/m" badge. Hidden once every task is done.
export function GettingStartedNavBadge() {
  const { store } = useStore()
  const tasks = store?.setup_tasks ?? []
  const done = tasks.filter((task) => task.done).length

  if (tasks.length === 0 || done === tasks.length) return null

  return (
    <Badge variant="info" className="rounded-lg">
      {done} <span className="opacity-50">/{tasks.length}</span>
    </Badge>
  )
}
