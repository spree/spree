import { SidebarTrigger, useSidebar } from '@spree/dashboard-ui'
import { TopBarBreadcrumbs } from './top-bar-breadcrumbs'

/**
 * The thin row at the top of the content sheet, shown only while the nav rail
 * is collapsed: the trigger that brings the rail back, and the location trail.
 *
 * Both belong to the same moment. The trigger is here rather than in the rail
 * because a collapsed rail has no room for it, and the control that restores
 * the nav should not live inside the thing that is hidden. The trail answers
 * the question the collapsed rail stops answering — where in the nav am I —
 * so with the rail open, where the active item is already lit, it would only
 * restate what is on screen and cost a row of chrome to do it.
 *
 * One condition for both, so the band appears and disappears as a unit rather
 * than leaving a stray trail floating above the page.
 */
export function SheetTopBar({
  tenantId,
  inSettings = false,
}: {
  tenantId?: string
  /**
   * Hides the bar. Inside settings the settings nav marks where you are and
   * every record page carries its own back button, so a trail would only
   * repeat them. The rail trigger goes too: the rail is collapsed by the app
   * there, and a control offering to re-expand a rail the area will just
   * re-collapse would not do what it says.
   */
  inSettings?: boolean
}) {
  const { isMobile, state } = useSidebar()
  const collapsed = state === 'collapsed' && !isMobile

  if (!collapsed || inSettings) return null

  return (
    <div className="hidden min-h-8 items-center gap-2 px-4 pt-3 md:flex">
      <SidebarTrigger className="-ms-1 shrink-0 text-muted-foreground hover:bg-accent hover:text-foreground" />
      <TopBarBreadcrumbs tenantId={tenantId} />
    </div>
  )
}
