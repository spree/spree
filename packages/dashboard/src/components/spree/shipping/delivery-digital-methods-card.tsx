import type { DeliveryMethod } from '@spree/admin-sdk'
import { Can, Subject } from '@spree/dashboard-core'
import { Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { PlusIcon, ZapIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { DeliveryMethodList } from './delivery-method-list'
import { useMethodSheetNavigation } from './use-method-sheet-navigation'

/** Methods delivered without a destination of any kind. */
export function DeliveryDigitalMethodsCard({ methods }: { methods: DeliveryMethod[] }) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ZapIcon className="size-4 text-muted-foreground" />
          {t('admin.delivery_profiles.detail.digital_title')}
        </CardTitle>
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_profiles.detail.digital_hint')}
        </span>
      </CardHeader>
      <CardContent>
        {methods.length > 0 ? (
          <DeliveryMethodList methods={methods} icon={ZapIcon} />
        ) : (
          <div className="flex flex-col items-start gap-2">
            <p className="text-muted-foreground text-sm">
              {t('admin.delivery_profiles.detail.digital_empty')}
            </p>
            <Can I="create" a={Subject.DeliveryMethod}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => openNewMethod({ provider: 'digital' })}
              >
                <PlusIcon className="size-4" />
                {t('admin.delivery_profiles.detail.add_digital_method')}
              </Button>
            </Can>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
