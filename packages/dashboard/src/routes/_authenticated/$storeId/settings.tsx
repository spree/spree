import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/settings')({
  component: SettingsLayout,
})

/**
 * Settings content padding. The secondary sidebar lives one level up, in
 * `_authenticated/$storeId.tsx`, so it can extend full-height beside the
 * TopBar. This layout owns only the right-side content padding.
 */
function SettingsLayout() {
  return (
    <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
      <Outlet />
    </div>
  )
}
