import { PageHeader } from '@spree/dashboard-core'
import { Alert, AlertDescription, Button, Card, CardContent, Skeleton } from '@spree/dashboard-ui'
import { CheckIcon, ShieldIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
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
  const { data: catalog } = usePermissionCatalog()
  const approve = useApproveOauthAuthorization()
  const deny = useDenyOauthAuthorization()

  // The decision ends the flow by handing the browser back to the client, so
  // a full navigation rather than a router push.
  const leaveTo = (redirectUri: string) => {
    window.location.href = redirectUri
  }

  const describe = (key: string) => catalog?.data.find((permission) => permission.key === key)
  const pending = approve.isPending || deny.isPending

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-6">
      <PageHeader
        title={t('admin.pages.oauth.authorize.title')}
        description={t('admin.pages.oauth.authorize.subtitle')}
      />

      {error ? (
        <Alert variant="destructive">
          <AlertDescription>{t('admin.pages.oauth.authorize.invalid_request')}</AlertDescription>
        </Alert>
      ) : null}

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
                <ul className="flex flex-col gap-2">
                  {data.scopes.map((key) => {
                    const permission = describe(key)

                    return (
                      <li key={key} className="flex items-start gap-2 text-sm">
                        <CheckIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
                        <span>
                          {permission?.label ?? key}
                          {permission?.description ? (
                            <span className="block text-muted-foreground text-xs">
                              {permission.description}
                            </span>
                          ) : null}
                        </span>
                      </li>
                    )
                  })}
                </ul>
              </div>

              <Alert>
                <AlertDescription>{t('admin.pages.oauth.authorize.revoke_hint')}</AlertDescription>
              </Alert>

              <div className="flex gap-3">
                <Button
                  disabled={pending}
                  onClick={async () => {
                    const result = await approve.mutateAsync(search)
                    leaveTo(result.redirect_uri)
                  }}
                >
                  {t('admin.pages.oauth.authorize.approve')}
                </Button>
                <Button
                  variant="outline"
                  disabled={pending}
                  onClick={async () => {
                    const result = await deny.mutateAsync(search)
                    leaveTo(result.redirect_uri)
                  }}
                >
                  {t('admin.pages.oauth.authorize.deny')}
                </Button>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
