import type { ApiKey } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  CopyToClipboardButton,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCreateApiKey } from '../../hooks/use-api-keys'
import { useStoreSettings } from '../../hooks/use-store-settings'

type McpConnectSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Connects an agent to this store without anyone hand-building a config
 * file. A key is minted on demand with read-only scopes, and each client's
 * snippet is rendered ready to paste — the token appears here once, because
 * that is the only moment the API returns it.
 */
export function McpConnectSheet({ open, onOpenChange }: McpConnectSheetProps) {
  const { t } = useTranslation()
  const { data: store } = useStoreSettings()
  const createKey = useCreateApiKey()
  const { permissions } = usePermissions()
  const [minted, setMinted] = useState<ApiKey | null>(null)

  const endpoint = store ? `${store.api_url}/v3/admin/mcp` : ''
  const token = minted?.plaintext_token ?? 'YOUR_SECRET_KEY'
  const canMint = permissions.can('create', Subject.ApiKey)

  async function mint() {
    const key = await createKey
      .mutateAsync({
        name: `MCP agent (${new Date().toISOString().slice(0, 10)})`,
        key_type: 'secret',
        // Read-only by default: an agent that should cancel or refund is a
        // deliberate choice, made on the API keys page.
        scopes: ['read_all'],
      })
      .catch(() => null)

    if (key) setMinted(key)
  }

  const snippets = {
    claude: `claude mcp add --transport http spree ${endpoint} \\
  --header "X-Spree-API-Key: ${token}"`,
    cursor: JSON.stringify(
      { mcpServers: { spree: { url: endpoint, headers: { 'X-Spree-API-Key': token } } } },
      null,
      2,
    ),
    vscode: JSON.stringify(
      {
        servers: {
          spree: { type: 'http', url: endpoint, headers: { 'X-Spree-API-Key': token } },
        },
      },
      null,
      2,
    ),
    curl: `curl ${endpoint} \\
  -H "Content-Type: application/json" \\
  -H "X-Spree-API-Key: ${token}" \\
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'`,
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>{t('admin.mcp_connect.title')}</SheetTitle>
          <SheetDescription>{t('admin.mcp_connect.subtitle')}</SheetDescription>
        </SheetHeader>

        <div className="flex flex-col gap-6 px-4 pb-8">
          {minted ? (
            <Alert>
              <AlertDescription>{t('admin.mcp_connect.token_shown_once')}</AlertDescription>
            </Alert>
          ) : (
            <div className="flex flex-col gap-3">
              <p className="text-muted-foreground text-sm">{t('admin.mcp_connect.mint_help')}</p>
              {canMint ? (
                <Button className="self-start" disabled={createKey.isPending} onClick={mint}>
                  {t('admin.mcp_connect.mint_cta')}
                </Button>
              ) : (
                <Alert variant="destructive">
                  <AlertDescription>{t('admin.mcp_connect.mint_denied')}</AlertDescription>
                </Alert>
              )}
            </div>
          )}

          <Tabs defaultValue="claude">
            <TabsList>
              <TabsTrigger value="claude">Claude Code</TabsTrigger>
              <TabsTrigger value="cursor">Cursor</TabsTrigger>
              <TabsTrigger value="vscode">VS Code</TabsTrigger>
              <TabsTrigger value="curl">{t('admin.mcp_connect.tab_other')}</TabsTrigger>
            </TabsList>

            {(['claude', 'cursor', 'vscode', 'curl'] as const).map((client) => (
              <TabsContent key={client} value={client}>
                <div className="relative">
                  <pre className="overflow-x-auto rounded-md bg-muted p-4 pr-12 text-xs leading-relaxed">
                    <code>{snippets[client]}</code>
                  </pre>
                  <CopyToClipboardButton
                    aria-label={t('admin.actions.copy')}
                    className="absolute top-2 right-2"
                    value={snippets[client]}
                  />
                </div>
                {client === 'cursor' ? (
                  <p className="mt-2 text-muted-foreground text-xs">
                    {t('admin.mcp_connect.cursor_path')}
                  </p>
                ) : null}
                {client === 'vscode' ? (
                  <p className="mt-2 text-muted-foreground text-xs">
                    {t('admin.mcp_connect.vscode_path')}
                  </p>
                ) : null}
              </TabsContent>
            ))}
          </Tabs>

          <p className="text-muted-foreground text-xs">{t('admin.mcp_connect.consumer_note')}</p>
        </div>
      </SheetContent>
    </Sheet>
  )
}
