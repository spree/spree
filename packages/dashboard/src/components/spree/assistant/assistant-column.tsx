import { cn } from '@spree/dashboard-ui'
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
      // `sticky` + viewport height rather than `static`: as a plain flex child
      // the column stretches to the height of the page, so on a long dashboard
      // the composer ends up below the fold and the transcript scrolls the
      // whole window instead of itself. Pinned to the viewport, the panel is
      // always exactly one screen tall and scrolls internally.
      className={cn(
        'fixed inset-0 z-40 border-l',
        'lg:sticky lg:top-0 lg:z-auto lg:h-svh lg:shrink-0',
        expanded ? 'lg:w-[640px] xl:w-[760px]' : 'lg:w-[400px] xl:w-[460px]',
      )}
    >
      <AssistantPanel
        onClose={close}
        expanded={expanded}
        onToggleExpanded={() => setExpanded((current) => !current)}
      />
    </div>
  )
}
