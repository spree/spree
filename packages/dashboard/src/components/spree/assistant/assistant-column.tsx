import { useRef, useState } from 'react'
import { AssistantPanel } from './assistant-panel'
import { useAssistant } from './assistant-provider'

/**
 * The assistant's slot in the page layout. A fixed column on wide screens; on
 * narrow ones it covers the page, because splitting a phone-width viewport in
 * two leaves neither half usable. Expanding widens it for longer answers
 * without going full-screen.
 */
export function AssistantColumn() {
  const { open, close } = useAssistant()
  const [expanded, setExpanded] = useState(false)
  // Nothing is mounted until the merchant first opens the assistant, so a
  // dashboard nobody asks pays nothing for it.
  const everOpened = useRef(false)
  if (open) everOpened.current = true

  // After that it is hidden rather than unmounted: the panel owns the live
  // conversation, and a merchant who closes it to look at a record the
  // assistant just named would otherwise come back to an empty chat.
  if (!everOpened.current) return null

  return (
    <div
      hidden={!open}
      className={
        expanded
          ? 'fixed inset-0 z-40 border-l lg:static lg:z-auto lg:w-[640px] lg:shrink-0 xl:w-[760px]'
          : 'fixed inset-0 z-40 border-l lg:static lg:z-auto lg:w-[400px] lg:shrink-0 xl:w-[460px]'
      }
    >
      <AssistantPanel
        onClose={close}
        expanded={expanded}
        onToggleExpanded={() => setExpanded((current) => !current)}
      />
    </div>
  )
}
