import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/settings')({
  component: SettingsLayout,
})

/**
 * Settings content padding. The secondary sidebar lives one level up, in
 * `_authenticated/$storeId.tsx`, so it can extend full-height beside the
 * TopBar. This layout owns only the right-side content padding.
 *
 * Every settings page inherits the container from here — a page must NOT add
 * its own `p-4`/`container`/`mx-auto`, or it double-pads and drifts from the
 * rest of the area. Start a settings page at `<div className="flex flex-col
 * gap-6">`.
 */
function SettingsLayout() {
  return (
    <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
      <Outlet />
    </div>
  )
}
