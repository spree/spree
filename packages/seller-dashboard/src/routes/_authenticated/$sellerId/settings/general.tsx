import { createFileRoute } from '@tanstack/react-router'
import { GeneralSettingsPage } from '../../../../pages/general-settings'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/general')({
  component: GeneralSettingsPage,
})
