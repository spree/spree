import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$sellerId/settings')({
  component: SettingsLayout,
})

/** Content padding for the settings area; the sidebar lives in the chrome. */
function SettingsLayout() {
  return <Outlet />
}
