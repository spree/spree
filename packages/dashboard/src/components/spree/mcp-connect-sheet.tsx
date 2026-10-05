import type { ApiKey } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Checkbox,
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
import { useId, useState } from 'react'
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
  const [writable, setWritable] = useState(false)
  const [mintError, setMintError] = useState<string | null>(null)
  const writableId = useId()

  const endpoint = store ? `${store.api_url}/v3/admin/mcp` : ''
  const token = minted?.plaintext_token ?? 'YOUR_SECRET_KEY'
  const canMint = permissions.can('create', Subject.ApiKey)

  async function mint() {
    setMintError(null)

    try {
      // Named with a timestamp because a key's name is unique within the
      // store while it is live — a second agent connected on the same day
      // would otherwise collide with the first.
      const key = await createKey.mutateAsync({
        name: `MCP agent ${new Date().toISOString().slice(0, 16).replace('T', ' ')}`,
        key_type: 'secret',
        scopes: writable ? ['write_all'] : ['read_all'],
      })
      setMinted(key)
    } catch (error) {
      setMintError(error instanceof Error ? error.message : t('admin.mcp_connect.mint_failed'))
    }
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
                <>
                  <label
                    htmlFor={writableId}
                    className="flex cursor-pointer items-start gap-2 text-sm"
                  >
                    <Checkbox
                      id={writableId}
                      checked={writable}
                      onCheckedChange={(checked) => setWritable(checked === true)}
                    />
                    <span>
                      {t('admin.mcp_connect.allow_writes')}
                      <span className="block text-muted-foreground text-xs">
                        {t('admin.mcp_connect.allow_writes_help')}
                      </span>
                    </span>
                  </label>
                  {mintError ? (
                    <Alert variant="destructive">
                      <AlertDescription>{mintError}</AlertDescription>
                    </Alert>
                  ) : null}
                  <Button className="self-start" disabled={createKey.isPending} onClick={mint}>
                    {t('admin.mcp_connect.mint_cta')}
                  </Button>
                </>
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

          {/* A consumer connector takes a URL, not a key — it signs in. There
              is no deep link that would open one of these apps on a given
              server, so the useful thing is the URL itself, ready to paste
              into the connector dialog. */}
          <div className="flex flex-col gap-2 border-t pt-4">
            <p className="font-medium text-sm">{t('admin.mcp_connect.consumer_title')}</p>
            <p className="text-muted-foreground text-xs">{t('admin.mcp_connect.consumer_note')}</p>
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
        </div>
      </SheetContent>
    </Sheet>
  )
}
