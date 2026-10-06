import { PageHeader } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  ScrollArea,
  Skeleton,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { PermissionGrid, permissionKeyLabel } from '../../../../components/spree/permission-picker'
import {
  useApproveOauthAuthorization,
  useDenyOauthAuthorization,
  useOauthAuthorization,
} from '../../../../hooks/use-oauth'
import { usePermissionCatalog } from '../../../../hooks/use-roles'

// Passed through to the authorization server untouched. Validated only for
// shape — whether the request is authorizable is the server's call, and
// re-deriving PKCE or the audience here would be a way to get it wrong.
const authorizeSearchSchema = z.object({
  client_id: z.string(),
  redirect_uri: z.string(),
  response_type: z.string().default('code'),
  scope: z.string().optional(),
  state: z.string().optional(),
  code_challenge: z.string().optional(),
  code_challenge_method: z.string().optional(),
  resource: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/oauth/authorize')({
  validateSearch: authorizeSearchSchema,
  component: OauthAuthorizePage,
})

function OauthAuthorizePage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const { data, isLoading, error } = useOauthAuthorization(search)
  const errorDetail = error instanceof Error ? error.message : undefined
  const [decisionError, setDecisionError] = useState<string | null>(null)
  // Null until the request loads, then every permission this person could
  // hand over — pre-ticked, because the client asked for them and declining
  // one should be a deliberate act rather than the default.
  const [granted, setGranted] = useState<string[] | null>(null)

  const grantable = data?.grantable_scopes ?? []
  const withheld = (data?.scopes ?? []).filter((key) => !grantable.includes(key))
  const selected = granted ?? grantable

  function setSelected(next: string[]) {
    setGranted(next)
  }
  const { data: catalog } = usePermissionCatalog()

  // Only the resources this request touches. The grid builds its rows from
  // whatever catalog entries it is handed, so narrowing the entries narrows
  // the screen — the merchant sees what was asked for, not the whole catalog.
  const requestedEntries = useMemo(() => {
    const requested = new Set(data?.scopes ?? [])
    return (catalog?.data ?? []).filter((entry) => requested.has(entry.key))
  }, [catalog?.data, data?.scopes])

  // Asked for but not this person's to give. Rendered disabled rather than
  // hidden, so the merchant can see the client wanted it and that they could
  // not hand it over.
  const withheldKeys = useMemo(() => new Set(withheld), [withheld])
  const approve = useApproveOauthAuthorization()
  const deny = useDenyOauthAuthorization()

  // The decision ends the flow by handing the browser back to the client, so
  // a full navigation rather than a router push.
  //
  // A rejected decision leaves the merchant here, and without the catch they
  // would sit on an unchanged screen with no sign the click did anything.
  async function decide(mutation: typeof approve | typeof deny) {
    setDecisionError(null)

    try {
      // The scope the merchant settled on, not the one the client asked
      // for — Doorkeeper records whatever reaches it, so a trimmed list
      // becomes the token's authority.
      const result = await mutation.mutateAsync({ ...search, scope: selected.join(' ') })
      window.location.href = result.redirect_uri
    } catch (failure) {
      setDecisionError(
        failure instanceof Error
          ? failure.message
          : t('admin.pages.oauth.authorize.decision_failed'),
      )
    }
  }

  const pending = approve.isPending || deny.isPending

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-6">
      <PageHeader
        title={t('admin.pages.oauth.authorize.title')}
        description={t('admin.pages.oauth.authorize.subtitle')}
      />

      {/* The server says what is actually wrong — a missing code challenge,
          an unknown client, a redirect that does not match. Showing only
          "not valid" leaves a merchant with nothing to act on, and the card
          below would skeleton forever behind it. */}
      {error ? (
        <Alert variant="destructive">
          <AlertDescription>
            {t('admin.pages.oauth.authorize.invalid_request')}
            {errorDetail ? (
              <span className="mt-1 block text-xs opacity-80">{errorDetail}</span>
            ) : null}
          </AlertDescription>
        </Alert>
      ) : null}

      {error ? null : (
        <Card>
          {isLoading || !data ? null : (
            <CardHeader>
              <CardTitle>{t('admin.pages.oauth.authorize.permissions_heading')}</CardTitle>
              <CardDescription>
                {t('admin.pages.oauth.authorize.intro', { client: data.client_name })}
              </CardDescription>
            </CardHeader>
          )}
          <CardContent className="flex flex-col gap-4">
            {isLoading || !data ? (
              <div className="flex flex-col gap-3">
                <Skeleton className="h-5 w-48" />
                <Skeleton className="h-4 w-full" />
                <Skeleton className="h-4 w-2/3" />
              </div>
            ) : (
              <>
                <div className="flex flex-col gap-3">
                  {/* The same grid the role editor and API-key picker use, so
                      a merchant reads one layout everywhere permissions are
                      granted. Narrowed to what the client asked for: showing
                      the whole catalog would invite ticking a permission the
                      client never requested, which the server would then cut
                      from the grant anyway.

                      Capped in height so the decision buttons stay in view
                      however much was asked for. */}
                  <ScrollArea className="-mx-6 max-h-96 border-border border-y px-6 [&_[data-slot=scroll-area-scrollbar]]:opacity-100">
                    <PermissionGrid
                      entries={requestedEntries}
                      value={selected}
                      onChange={setSelected}
                      disabledKeys={withheldKeys}
                      bare
                    />
                  </ScrollArea>
                  {/* Asked for but not this person's to give — saying so is
                      better than silently dropping it, because the agent will
                      behave as though it has them. */}
                  {withheld.length > 0 ? (
                    <p className="text-muted-foreground text-xs">
                      {t('admin.pages.oauth.authorize.withheld', {
                        permissions: withheld
                          .map((key) => permissionKeyLabel(t, catalog?.data, key))
                          .join(', '),
                      })}
                    </p>
                  ) : null}
                </div>

                <Alert variant="info">
                  <AlertDescription>
                    {t('admin.pages.oauth.authorize.revoke_hint')}
                  </AlertDescription>
                </Alert>

                {decisionError ? (
                  <Alert variant="destructive">
                    <AlertDescription>{decisionError}</AlertDescription>
                  </Alert>
                ) : null}
              </>
            )}
          </CardContent>
          {isLoading || !data ? null : (
            <CardFooter className="gap-3">
              <Button disabled={pending || selected.length === 0} onClick={() => decide(approve)}>
                {t('admin.pages.oauth.authorize.approve')}
              </Button>
              <Button variant="outline" disabled={pending} onClick={() => decide(deny)}>
                {t('admin.pages.oauth.authorize.deny')}
              </Button>
            </CardFooter>
          )}
        </Card>
      )}
    </div>
  )
}
