import { SettingsContainer } from '@spree/dashboard-core'
import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/settings')({
  component: SettingsLayout,
})

function SettingsLayout() {
  return (
    <SettingsContainer>
      <Outlet />
    </SettingsContainer>
  )
}
