import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$sellerId/settings')({
  component: SettingsLayout,
})

/**
 * Content padding for the settings area. The rail itself lives in the chrome,
 * one level up, so it can span full height beside the top bar — this layout
 * owns only the right-hand column, matching the dashboard's settings layout.
 */
function SettingsLayout() {
  return (
    <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
      <Outlet />
    </div>
  )
}
