import { ImportButton, Subject } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { Link, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import type { SetupTaskSlotContext } from './types'

// Card body for the add_products task: the manual path (products page) plus
// the bulk path — the CSV import sheet opens right here, and the created
// import lands on the products page with the wizard dialog open (its
// `?import=` search param).
export function AddProductsTask({ task, storeId }: SetupTaskSlotContext) {
  const { t } = useTranslation()
  const navigate = useNavigate()

  return (
    <>
      <p className="text-muted-foreground text-sm">
        {t('admin.pages.getting_started.tasks.add_products.description')}
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <Button asChild variant={task.done ? 'outline' : 'default'}>
          <Link to="/$storeId/products" params={{ storeId }}>
            {t('admin.pages.getting_started.tasks.add_products.cta')}
          </Link>
        </Button>
        <ImportButton
          type="Spree::Imports::Products"
          subject={Subject.Product}
          label={t('admin.pages.getting_started.tasks.add_products.import_cta')}
          onCreated={(imp) =>
            navigate({
              to: '/$storeId/products',
              params: { storeId },
              search: { import: imp.id } as never,
            })
          }
        />
      </div>
    </>
  )
}
