import { createFileRoute, Outlet } from '@tanstack/react-router'
import { SettingsContainer } from '../../../components/spree/settings-container'

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
