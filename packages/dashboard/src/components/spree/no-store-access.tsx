import { NO_STORE_ACCESS_SLOT, type NoStoreAccessSlotContext, Slot } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * Shown to a signed-in admin who holds a role on no store. Plugins replace the
 * built-in message by registering on the `no_store_access` slot.
 */
export function NoStoreAccess(context: NoStoreAccessSlotContext) {
  return (
    <Slot<NoStoreAccessSlotContext>
      name={NO_STORE_ACCESS_SLOT}
      context={context}
      fallback={<NoStoreAccessMessage {...context} />}
    />
  )
}

function NoStoreAccessMessage({ user, signOut }: NoStoreAccessSlotContext) {
  const { t } = useTranslation()

  return (
    <>
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-bold">{t('admin.auth.no_store_access.title')}</h1>
        <p className="text-sm text-muted-foreground">
          {t('admin.auth.no_store_access.description')}
        </p>
        <p className="text-sm text-muted-foreground">
          {t('admin.auth.no_store_access.signed_in_as', { email: user.email })}
        </p>
      </div>
      <Button variant="outline" className="w-full" onClick={() => signOut()}>
        {t('admin.auth.logout')}
      </Button>
    </>
  )
}
