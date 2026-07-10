import { Button } from '@spree/dashboard-ui'
import { useSearch } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  normalizeOrigin,
  StorefrontConnectSheet,
} from '@/components/spree/storefront-connect-sheet'
import type { SetupTaskSlotContext } from './types'

// Card body for the setup_storefront task: opens the storefront-connect
// sheet. Vercel's deploy button redirects back with a deployment-url param —
// when present, the sheet auto-opens with the deployed URL prefilled.
export function StorefrontConnectTask({ task, store }: SetupTaskSlotContext) {
  const { t } = useTranslation()
  const search = useSearch({ strict: false }) as Record<string, unknown>
  const deploymentUrl = search['deployment-url']
  const deployedOrigin = typeof deploymentUrl === 'string' ? normalizeOrigin(deploymentUrl) : null
  const [sheetOpen, setSheetOpen] = useState(deployedOrigin != null)

  return (
    <>
      <p className="text-muted-foreground text-sm">
        {t('admin.getting_started.tasks.setup_storefront.description')}
      </p>
      <Button variant={task.done ? 'outline' : 'default'} onClick={() => setSheetOpen(true)}>
        {t('admin.getting_started.tasks.setup_storefront.cta')}
      </Button>
      <StorefrontConnectSheet
        store={store}
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        initialUrl={deployedOrigin ?? undefined}
      />
    </>
  )
}
