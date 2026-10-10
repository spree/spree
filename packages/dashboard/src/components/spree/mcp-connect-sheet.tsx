import type { OauthApplication } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  CopyToClipboardButton,
  Field,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOauthApplications } from '../../hooks/use-oauth'
import { ChoiceCardPicker } from './choice-card-picker'

type McpConnectSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * A client we can fill the callback in for.
 *
 * The redirect URI is where authorization codes are delivered, so a wrong
 * one sends them to whoever controls that host. For the clients we know the
 * merchant should never have to find or type it — they pick a name.
 *
 * `surfaces` are the ways that client connects. A desktop or web app takes
 * the address pasted into its settings; a terminal client takes a command.
 */
/**
 * The loopback callback a terminal client listens on.
 *
 * Registered alongside the hosted one because Claude Code and Codex redirect
 * to a local port rather than the vendor's servers, and the port is chosen
 * at run time. RFC 8252 §7.3 says to compare loopback redirects ignoring the
 * port, which Doorkeeper does — but only for an IP literal, since it decides
 * by parsing the host as an address. `localhost` is a name, so it parses as
 * nothing and every ephemeral port is refused.
 */
const LOOPBACK_CALLBACK = 'http://127.0.0.1/callback'

const KNOWN_CLIENTS = [
  {
    value: 'claude',
    name: 'Claude',
    redirectUris: ['https://claude.ai/api/mcp/auth_callback', LOOPBACK_CALLBACK],
    surfaces: [
      { id: 'app', command: null },
      { id: 'cli', command: (url: string) => `claude mcp add --transport http spree ${url}` },
    ],
  },
  {
    value: 'chatgpt',
    name: 'ChatGPT',
    redirectUris: ['https://chatgpt.com/connector_platform_oauth_redirect', LOOPBACK_CALLBACK],
    surfaces: [
      { id: 'app', command: null },
      { id: 'cli', command: (url: string) => `codex mcp add spree --url ${url}` },
    ],
  },
] as const

const OTHER = 'other'

export function McpConnectSheet({ open, onOpenChange }: McpConnectSheetProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const [choice, setChoice] = useState<string>(KNOWN_CLIENTS[0].value)
  const [created, setCreated] = useState<OauthApplication | null>(null)
  const [customName, setCustomName] = useState('')
  const [customUri, setCustomUri] = useState('')
  const [failure, setFailure] = useState<string | null>(null)
  const { data: existing } = useOauthApplications()

  // Where this dashboard's own API calls go — either a configured origin or
  // the page's own, which is what a proxied or multi-hostname deployment
  // actually answers on.
  const apiOrigin = import.meta.env.VITE_SPREE_API_URL || window.location.origin
  const endpoint = `${apiOrigin}/api/v3/admin/mcp`
  const selected = KNOWN_CLIENTS.find((client) => client.value === choice)

  const register = useMutation({
    mutationFn: (params: { name: string; redirect_uri: string }) =>
      adminClient.oauth.applications.create(params),
    onSuccess: (application) => {
      queryClient.invalidateQueries({ queryKey: ['oauth-applications'] })
      setCreated(application)
    },
  })

  async function connect() {
    setFailure(null)
    const name = selected ? selected.name : customName.trim()
    // Doorkeeper stores several callbacks newline-separated and accepts a
    // request matching any one of them.
    const redirectUri = selected ? selected.redirectUris.join('\n') : customUri.trim()

    // Picking the same client twice is reconnecting it, not registering a
    // second one — two rows with two ids would leave a merchant guessing
    // which to paste.
    const already = existing?.data?.find((candidate) => candidate.name === name)
    if (already) {
      setCreated(already)
      return
    }

    try {
      await register.mutateAsync({ name, redirect_uri: redirectUri })
    } catch (error) {
      setFailure(error instanceof Error ? error.message : t('admin.common.error'))
    }
  }

  function reset(next: boolean) {
    onOpenChange(next)
    if (next) return
    setChoice(KNOWN_CLIENTS[0].value)
    setCreated(null)
    setCustomName('')
    setCustomUri('')
    setFailure(null)
  }

  const canConnect = selected
    ? !register.isPending
    : !register.isPending && Boolean(customName.trim() && customUri.trim())

  return (
    <Sheet open={open} onOpenChange={reset}>
      <SheetContent className="w-full sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {created
              ? t('admin.mcp_connect.ready_title', { client: created.name })
              : t('admin.mcp_connect.title')}
          </SheetTitle>
          <SheetDescription>
            {created ? t('admin.mcp_connect.ready_subtitle') : t('admin.mcp_connect.subtitle')}
          </SheetDescription>
        </SheetHeader>

        <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
          {failure ? (
            <Alert variant="destructive">
              <AlertDescription>{failure}</AlertDescription>
            </Alert>
          ) : null}

          {created ? (
            <ConnectInstructions
              client={KNOWN_CLIENTS.find((candidate) => candidate.name === created.name)}
              clientId={created.client_id}
              endpoint={endpoint}
            />
          ) : (
            <>
              <ChoiceCardPicker
                options={[
                  ...KNOWN_CLIENTS.map((client) => ({
                    value: client.value as string,
                    label: client.name,
                    description: t(`admin.mcp_connect.clients.${client.value}`),
                  })),
                  {
                    value: OTHER,
                    label: t('admin.mcp_connect.other_title'),
                    description: t('admin.mcp_connect.other_help'),
                  },
                ]}
                value={choice}
                onChange={setChoice}
              />

              {/* Only once "Something else" is the choice: a merchant picking
                  a known client never sees a callback field. */}
              {selected ? null : (
                <div className="flex flex-col gap-4 rounded-lg border p-4">
                  <Field>
                    <FieldLabel htmlFor="mcp-other-name">
                      {t('admin.fields.oauth_application.name.label')}
                    </FieldLabel>
                    <Input
                      id="mcp-other-name"
                      value={customName}
                      onChange={(event) => setCustomName(event.target.value)}
                      placeholder={t('admin.fields.oauth_application.name.placeholder')}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="mcp-other-uri">
                      {t('admin.fields.oauth_application.redirect_uri.label')}
                    </FieldLabel>
                    <Input
                      id="mcp-other-uri"
                      value={customUri}
                      onChange={(event) => setCustomUri(event.target.value)}
                      placeholder="https://example.com/oauth/callback"
                    />
                    <p className="text-muted-foreground text-xs">
                      {t('admin.fields.oauth_application.redirect_uri.help')}
                    </p>
                  </Field>
                </div>
              )}
            </>
          )}
        </div>

        <SheetFooter>
          {created ? (
            <Button onClick={() => reset(false)}>{t('admin.common.done')}</Button>
          ) : (
            <>
              <Button variant="outline" onClick={() => reset(false)}>
                {t('admin.common.cancel')}
              </Button>
              <Button disabled={!canConnect} onClick={connect}>
                {t('admin.mcp_connect.continue')}
              </Button>
            </>
          )}
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

/**
 * What to do with the registration, per surface.
 *
 * A desktop or web client takes the address pasted into its settings; a
 * terminal client takes a command. Tabbed rather than listed, because a
 * merchant on claude.ai should not have to read past a shell command.
 */
function ConnectInstructions({
  client,
  clientId,
  endpoint,
}: {
  client?: (typeof KNOWN_CLIENTS)[number]
  clientId: string
  endpoint: string
}) {
  const { t } = useTranslation()
  const cli = client?.surfaces.find((surface) => surface.command)

  const address = (
    <div className="flex flex-col gap-4">
      <CopyableValue
        label={t('admin.mcp_connect.endpoint_label')}
        value={endpoint}
        copyLabel={t('admin.mcp_connect.copy_endpoint')}
      />
      <CopyableValue
        label={t('admin.mcp_connect.client_id_label')}
        help={t('admin.mcp_connect.client_id_help')}
        value={clientId}
        copyLabel={t('admin.mcp_connect.copy_client_id')}
      />
      <ol className="flex list-decimal flex-col gap-2 pl-5 text-sm">
        <li>{t('admin.mcp_connect.step_paste')}</li>
        <li>{t('admin.mcp_connect.step_sign_in')}</li>
        <li>{t('admin.mcp_connect.step_approve')}</li>
      </ol>
    </div>
  )

  return (
    <div className="flex flex-col gap-4">
      {cli?.command ? (
        <Tabs defaultValue="app">
          <TabsList>
            <TabsTrigger value="app">
              {t(`admin.mcp_connect.surfaces.${client?.value}.app`)}
            </TabsTrigger>
            <TabsTrigger value="cli">
              {t(`admin.mcp_connect.surfaces.${client?.value}.cli`)}
            </TabsTrigger>
          </TabsList>
          <TabsContent value="app" className="pt-4">
            {address}
          </TabsContent>
          <TabsContent value="cli" className="flex flex-col gap-4 pt-4">
            <CopyableValue
              label={t('admin.mcp_connect.run_label')}
              value={cli.command(endpoint)}
              copyLabel={t('admin.mcp_connect.copy_command')}
            />
            <p className="text-muted-foreground text-sm">
              {t('admin.mcp_connect.cli_then_sign_in')}
            </p>
          </TabsContent>
        </Tabs>
      ) : (
        address
      )}

      <Alert variant="info">
        <AlertDescription>{t('admin.mcp_connect.bounded_note')}</AlertDescription>
      </Alert>
    </div>
  )
}

function CopyableValue({
  label,
  help,
  value,
  copyLabel,
}: {
  label: string
  help?: string
  value: string
  copyLabel: string
}) {
  return (
    <div className="flex flex-col gap-2">
      <p className="font-medium text-sm">{label}</p>
      {help ? <p className="text-muted-foreground text-xs">{help}</p> : null}
      <div className="flex items-center gap-2 rounded-md bg-muted px-3 py-2">
        <code className="flex-1 truncate font-mono text-xs">{value}</code>
        <CopyToClipboardButton value={value} aria-label={copyLabel} />
      </div>
    </div>
  )
}
