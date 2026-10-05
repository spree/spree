import {
  Alert,
  AlertDescription,
  CopyToClipboardButton,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

type McpConnectSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * How a merchant points an agent at this store.
 *
 * There is nothing to mint: the client sends the person here to sign in and
 * approve what the agent may do, so the only thing to hand over is the URL.
 * An API key is not accepted by the MCP endpoint — that credential belongs
 * to the CLI, where there is no person to approve anything.
 */
export function McpConnectSheet({ open, onOpenChange }: McpConnectSheetProps) {
  const { t } = useTranslation()

  // Where this dashboard's own API calls go — either a configured origin or
  // the page's own, which is what a proxied or multi-hostname deployment
  // actually answers on.
  const apiOrigin = import.meta.env.VITE_SPREE_API_URL || window.location.origin
  const endpoint = `${apiOrigin}/api/v3/admin/mcp`

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>{t('admin.mcp_connect.title')}</SheetTitle>
          <SheetDescription>{t('admin.mcp_connect.subtitle')}</SheetDescription>
        </SheetHeader>

        <div className="flex flex-col gap-6 px-4 pb-8">
          <div className="flex flex-col gap-2">
            <p className="font-medium text-sm">{t('admin.mcp_connect.url_label')}</p>
            <div className="relative">
              <pre className="overflow-x-auto rounded-md bg-muted p-3 pr-12 text-xs">
                <code>{endpoint}</code>
              </pre>
              <CopyToClipboardButton
                aria-label={t('admin.actions.copy')}
                className="absolute top-1.5 right-2"
                value={endpoint}
              />
            </div>
          </div>

          <ol className="flex list-decimal flex-col gap-2 pl-5 text-sm">
            <li>{t('admin.mcp_connect.step_paste')}</li>
            <li>{t('admin.mcp_connect.step_sign_in')}</li>
            <li>{t('admin.mcp_connect.step_approve')}</li>
          </ol>

          <Alert>
            <AlertDescription>{t('admin.mcp_connect.scope_note')}</AlertDescription>
          </Alert>

          <p className="text-muted-foreground text-xs">{t('admin.mcp_connect.cli_note')}</p>
        </div>
      </SheetContent>
    </Sheet>
  )
}
