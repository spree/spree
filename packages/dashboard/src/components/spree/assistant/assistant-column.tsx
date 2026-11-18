import { cn } from '@spree/dashboard-ui'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { AssistantPanel } from './assistant-panel'
import { useAssistant } from './assistant-provider'

/**
 * The assistant's column in the shell: `[rail] [page] [assistant]`.
 *
 * It mirrors the content sheet deliberately — same card fill, radius, border
 * and margin — so the two read as a pair of panels on one ground rather than
 * as a page with something bolted to its edge. The shell renders it as a
 * sibling of the sheet, so it is exactly the viewport's height and scrolls
 * its own transcript; it never rides down a long page.
 *
 * Below `md` it covers the page instead, because splitting a phone-width
 * viewport in two leaves neither half usable.
 */
export function AssistantColumn() {
  const { t } = useTranslation()
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
    <aside
      aria-label={t('admin.assistant.title')}
      hidden={!open}
      className={cn(
        // Phone: over the page.
        'fixed inset-0 z-40 flex flex-col bg-card',
        // From `md`: a card beside the page. The same treatment
        // `SidebarInset` gives the content sheet, minus the left margin it
        // drops to sit flush against the rail — here the margin on both sides
        // is what separates the two cards.
        'md:static md:z-auto md:my-2 md:me-2 md:h-auto md:rounded-xl md:border md:border-sidebar-border md:shadow-sm',
        // `min-w-0` so the column can shrink; a fixed basis so it does not
        // grow with the conversation.
        'md:min-w-0 md:shrink-0',
        expanded ? 'md:w-[560px] xl:w-[680px]' : 'md:w-[380px] xl:w-[440px]',
      )}
    >
      <AssistantPanel
        onClose={close}
        expanded={expanded}
        onToggleExpanded={() => setExpanded((current) => !current)}
      />
    </aside>
  )
}
