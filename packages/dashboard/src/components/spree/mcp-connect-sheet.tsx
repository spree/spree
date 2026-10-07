import type { OauthApplication } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  CopyToClipboardButton,
  Field,
  FieldError,
  Input,
  Label,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOauthApplications } from '../../hooks/use-oauth'

type McpConnectSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * The clients whose callback we can fill in for the merchant.
 *
 * A redirect URI is where authorization codes are delivered, so a wrong one
 * sends them to whoever controls that host. For the clients we know, the
 * merchant should never have to find or type it — they pick a name. Anything
 * else is "Something else", where a developer supplies the callback from the
 * client's own documentation.
 */
const KNOWN_CLIENTS = [
  { id: 'claude', name: 'Claude', redirectUri: 'https://claude.ai/api/mcp/auth_callback' },
  {
    id: 'chatgpt',
    name: 'ChatGPT',
    redirectUri: 'https://chatgpt.com/connector_platform_oauth_redirect',
  },
] as const

/**
 * Connecting an agent, in two steps: choose which one, then take away the
 * address and the id it asks for.
 *
 * The client is registered when the merchant picks it, rather than seeded
 * into every store — a store that never connects anything carries no
 * registrations, and the sheet shows one id (the one just created) instead
 * of every id at once.
 */
export function McpConnectSheet({ open, onOpenChange }: McpConnectSheetProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
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

  const register = useMutation({
    mutationFn: (params: { name: string; redirect_uri: string }) =>
      adminClient.oauth.applications.create(params),
    onSuccess: (application) => {
      queryClient.invalidateQueries({ queryKey: ['oauth-applications'] })
      setCreated(application)
    },
  })

  async function choose(name: string, redirectUri: string) {
    setFailure(null)

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
    setCreated(null)
    setCustomName('')
    setCustomUri('')
    setFailure(null)
  }

  return (
    <Sheet open={open} onOpenChange={reset}>
      <SheetContent className="flex w-full flex-col overflow-y-auto sm:max-w-xl">
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

        <div className="flex flex-1 flex-col gap-6 px-4">
          {failure ? (
            <Alert variant="destructive">
              <AlertDescription>{failure}</AlertDescription>
            </Alert>
          ) : null}

          {created ? (
            <>
              <div className="flex flex-col gap-2">
                <p className="font-medium text-sm">{t('admin.mcp_connect.endpoint_label')}</p>
                <div className="flex items-center gap-2 rounded-md bg-muted px-3 py-2">
                  <code className="flex-1 truncate font-mono text-xs">{endpoint}</code>
                  <CopyToClipboardButton
                    value={endpoint}
                    aria-label={t('admin.mcp_connect.copy_endpoint')}
                  />
                </div>
              </div>

              <div className="flex flex-col gap-2">
                <p className="font-medium text-sm">{t('admin.mcp_connect.client_id_label')}</p>
                <p className="text-muted-foreground text-xs">
                  {t('admin.mcp_connect.client_id_help')}
                </p>
                <div className="flex items-center gap-2 rounded-md bg-muted px-3 py-2">
                  <code className="flex-1 truncate font-mono text-xs">{created.client_id}</code>
                  <CopyToClipboardButton
                    value={created.client_id}
                    aria-label={t('admin.mcp_connect.copy_client_id')}
                  />
                </div>
              </div>

              <ol className="flex list-decimal flex-col gap-2 pl-5 text-sm">
                <li>{t('admin.mcp_connect.step_paste')}</li>
                <li>{t('admin.mcp_connect.step_sign_in')}</li>
                <li>{t('admin.mcp_connect.step_approve')}</li>
              </ol>

              <Alert variant="info">
                <AlertDescription>{t('admin.mcp_connect.bounded_note')}</AlertDescription>
              </Alert>
            </>
          ) : (
            <>
              <div className="flex flex-col gap-2">
                {KNOWN_CLIENTS.map((client) => (
                  <Button
                    key={client.id}
                    variant="outline"
                    className="justify-start"
                    disabled={register.isPending}
                    onClick={() => choose(client.name, client.redirectUri)}
                  >
                    {client.name}
                  </Button>
                ))}
              </div>

              {/* Anything we do not know a callback for. A developer reads it
                  from the client's documentation; a merchant picks a name
                  above and never sees this. */}
              <div className="flex flex-col gap-3 border-t pt-4">
                <p className="font-medium text-sm">{t('admin.mcp_connect.other_title')}</p>
                <Field>
                  <Label htmlFor="mcp-other-name">
                    {t('admin.fields.oauth_application.name.label')}
                  </Label>
                  <Input
                    id="mcp-other-name"
                    value={customName}
                    onChange={(event) => setCustomName(event.target.value)}
                    placeholder={t('admin.fields.oauth_application.name.placeholder')}
                  />
                </Field>
                <Field>
                  <Label htmlFor="mcp-other-uri">
                    {t('admin.fields.oauth_application.redirect_uri.label')}
                  </Label>
                  <Input
                    id="mcp-other-uri"
                    value={customUri}
                    onChange={(event) => setCustomUri(event.target.value)}
                    placeholder="https://example.com/oauth/callback"
                  />
                  <FieldError />
                  <p className="text-muted-foreground text-xs">
                    {t('admin.fields.oauth_application.redirect_uri.help')}
                  </p>
                </Field>
                <Button
                  variant="outline"
                  className="self-start"
                  disabled={register.isPending || !customName.trim() || !customUri.trim()}
                  onClick={() => choose(customName.trim(), customUri.trim())}
                >
                  {t('admin.mcp_connect.other_cta')}
                </Button>
              </div>
            </>
          )}
        </div>

        <SheetFooter>
          <Button variant="outline" onClick={() => reset(false)}>
            {created ? t('admin.common.done') : t('admin.common.cancel')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
