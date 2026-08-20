import { useState } from 'react'
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

  if (!open) return null

  return (
    <div
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
