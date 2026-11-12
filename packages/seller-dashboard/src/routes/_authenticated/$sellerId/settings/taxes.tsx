import { createFileRoute } from '@tanstack/react-router'
import { TaxesPage } from '../../../../pages/taxes'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/taxes')({
  component: TaxesPage,
})
