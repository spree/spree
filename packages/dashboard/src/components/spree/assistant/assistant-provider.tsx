import { createContext, type ReactNode, useContext, useMemo, useState } from 'react'
import { useAssistantStatus } from '../../../hooks/use-assistant'

interface AssistantContextValue {
  /** Whether this store and admin can chat at all. */
  enabled: boolean
  open: boolean
  toggle: () => void
  close: () => void
}

const AssistantContext = createContext<AssistantContextValue>({
  enabled: false,
  open: false,
  toggle: () => {},
  close: () => {},
})

/**
 * Owns whether the assistant column is showing.
 *
 * Lives above the layout because the toggle (in the top bar) and the column
 * (beside the page) sit in different branches of the tree.
 */
export function AssistantProvider({ children }: { children: ReactNode }) {
  const { data: status } = useAssistantStatus()
  const [open, setOpen] = useState(false)
  const enabled = status?.available ?? false

  const value = useMemo<AssistantContextValue>(
    () => ({
      enabled,
      open: open && enabled,
      toggle: () => setOpen((current) => !current),
      close: () => setOpen(false),
    }),
    [enabled, open],
  )

  return <AssistantContext.Provider value={value}>{children}</AssistantContext.Provider>
}

export function useAssistant() {
  return useContext(AssistantContext)
}
