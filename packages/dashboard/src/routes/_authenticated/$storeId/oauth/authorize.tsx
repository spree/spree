import { PageHeader } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  CardContent,
  Checkbox,
  Skeleton,
} from '@spree/dashboard-ui'
import { ShieldIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { permissionKeyLabel } from '../../../../components/spree/permission-picker'
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
  const scopeFieldId = useId()

  const grantable = data?.grantable_scopes ?? []
  const withheld = (data?.scopes ?? []).filter((key) => !grantable.includes(key))
  const selected = granted ?? grantable

  const toggle = (key: string) =>
    setSelected(selected.includes(key) ? selected.filter((k) => k !== key) : [...selected, key])

  function setSelected(next: string[]) {
    setGranted(next)
  }
  const { data: catalog } = usePermissionCatalog()
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
          <CardContent className="flex flex-col gap-6 pt-6">
            {isLoading || !data ? (
              <div className="flex flex-col gap-3">
                <Skeleton className="h-5 w-48" />
                <Skeleton className="h-4 w-full" />
                <Skeleton className="h-4 w-2/3" />
              </div>
            ) : (
              <>
                <div className="flex items-start gap-3">
                  <ShieldIcon className="mt-0.5 size-5 shrink-0 text-muted-foreground" />
                  <p className="text-sm">
                    {t('admin.pages.oauth.authorize.intro', { client: data.client_name })}
                  </p>
                </div>

                <div className="flex flex-col gap-3">
                  <h2 className="font-medium text-sm">
                    {t('admin.pages.oauth.authorize.permissions_heading')}
                  </h2>
                  {/* Each one is a choice, not a notice: a merchant can hand
                      over less than the client asked for, and the grant is
                      whatever they leave ticked. Labelled client-side so the
                      one screen that says what is being granted follows the
                      merchant's own language, not the server's. */}
                  <ul className="flex flex-col gap-2">
                    {grantable.map((key) => (
                      <li key={key}>
                        <label
                          htmlFor={`${scopeFieldId}-${key}`}
                          className="flex cursor-pointer items-start gap-2 text-sm"
                        >
                          <Checkbox
                            id={`${scopeFieldId}-${key}`}
                            checked={selected.includes(key)}
                            onCheckedChange={() => toggle(key)}
                          />
                          <span>{permissionKeyLabel(t, catalog?.data, key)}</span>
                        </label>
                      </li>
                    ))}
                  </ul>
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

                <Alert>
                  <AlertDescription>
                    {t('admin.pages.oauth.authorize.revoke_hint')}
                  </AlertDescription>
                </Alert>

                {decisionError ? (
                  <Alert variant="destructive">
                    <AlertDescription>{decisionError}</AlertDescription>
                  </Alert>
                ) : null}

                <div className="flex gap-3">
                  <Button
                    disabled={pending || selected.length === 0}
                    onClick={() => decide(approve)}
                  >
                    {t('admin.pages.oauth.authorize.approve')}
                  </Button>
                  <Button variant="outline" disabled={pending} onClick={() => decide(deny)}>
                    {t('admin.pages.oauth.authorize.deny')}
                  </Button>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  )
}
