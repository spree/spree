import { createContext, type ReactNode, useCallback, useContext, useMemo, useState } from 'react'
import { useAssistantStatus } from '../../../hooks/use-assistant'

interface AssistantContextValue {
  /** Whether this store and admin can chat at all. */
  enabled: boolean
  open: boolean
  toggle: () => void
  close: () => void
  /** Opens the panel and asks this question. */
  ask: (question: string) => void
  /**
   * A question handed over by another surface — the command palette — waiting
   * for the panel to pick it up. The panel clears it once sent.
   */
  pendingQuestion: string | null
  clearPendingQuestion: () => void
}

const AssistantContext = createContext<AssistantContextValue>({
  enabled: false,
  open: false,
  toggle: () => {},
  close: () => {},
  ask: () => {},
  pendingQuestion: null,
  clearPendingQuestion: () => {},
})

/**
 * Owns whether the assistant column is showing, and carries a question handed
 * to it from elsewhere.
 *
 * Lives above the layout because the control that opens the assistant (a row
 * in the nav rail), the column itself (beside the page) and the command
 * palette all sit in different branches of the tree.
 *
 * The handoff is a value here rather than a call into the conversation because
 * the conversation belongs to the panel, which is not mounted until the
 * merchant first opens the assistant — so there is nothing to call into at the
 * moment the palette asks.
 */
export function AssistantProvider({ children }: { children: ReactNode }) {
  const { data: status } = useAssistantStatus()
  const [open, setOpen] = useState(false)
  const [pendingQuestion, setPendingQuestion] = useState<string | null>(null)
  const enabled = status?.available ?? false

  const ask = useCallback((question: string) => {
    const text = question.trim()
    if (!text) return
    setPendingQuestion(text)
    setOpen(true)
  }, [])

  const clearPendingQuestion = useCallback(() => setPendingQuestion(null), [])

  const value = useMemo<AssistantContextValue>(
    () => ({
      enabled,
      open: open && enabled,
      toggle: () => setOpen((current) => !current),
      close: () => setOpen(false),
      ask,
      pendingQuestion,
      clearPendingQuestion,
    }),
    [enabled, open, ask, pendingQuestion, clearPendingQuestion],
  )

  return <AssistantContext.Provider value={value}>{children}</AssistantContext.Provider>
}

export function useAssistant() {
  return useContext(AssistantContext)
}
