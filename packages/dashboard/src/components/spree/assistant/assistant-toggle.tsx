import { SidebarMenu, SidebarMenuButton, SidebarMenuItem } from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useAssistant } from './assistant-provider'

/**
 * Opens and closes the assistant column, as a row in the nav rail.
 *
 * The rail is where the app's global affordances live now that there is no top
 * bar — the switcher, search and the account menu — and the assistant is one
 * of those rather than something belonging to the page on screen.
 *
 * Renders nothing unless this store has a connected AI provider and this admin
 * may use it: a button that only ever explains why it cannot help is worse
 * than no button.
 */
export function AssistantToggle() {
  const { t } = useTranslation()
  const { enabled, open, toggle } = useAssistant()

  if (!enabled) return null

  const label = t('admin.assistant.title')

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        {/* `isActive` rather than a pressed variant: to the rail this reads as
            the current surface, which is what the nav items use, so an open
            assistant is lit the same way an open section is. `tooltip` is what
            names it once the rail collapses to icons. */}
        <SidebarMenuButton isActive={open} tooltip={label} aria-pressed={open} onClick={toggle}>
          <SparklesIcon />
          <span>{label}</span>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
