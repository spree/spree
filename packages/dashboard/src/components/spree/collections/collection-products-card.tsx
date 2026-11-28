import {
  Button,
  TableCell,
  TableHead,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { BanIcon } from '@spree/dashboard-ui/icons'
import { useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  listCollectionProductsPage,
  useCollectionProducts,
  useExcludeCollectionProduct,
  useRepositionCollectionProduct,
} from '../../../hooks/use-collections'
import { DeferredProductMembershipCard } from '../deferred-product-membership-card'

/**
 * Product membership for a collection: the products its rules matched and
 * the ones picked by hand. Adds and removes stage into the collection form
 * and persist on its Save, while reordering writes through on drop, since a
 * collection's position drives storefront display order.
 *
 * Removing a product the rules still match brings it back on the next
 * regeneration, so a rule-matched row can also exclude its product, which
 * takes it out at once and keeps it out. A hand-picked product never comes
 * back on its own, so removing it is enough.
 */
export function CollectionProductsCard({
  collectionId,
  hasRules,
}: {
  collectionId: string
  /** Whether the collection has rules, which is when a removed product can come back. */
  hasRules: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/collections/$collectionId',
  })
  const reposition = useRepositionCollectionProduct(collectionId)
  const exclude = useExcludeCollectionProduct(collectionId)
  const confirm = useConfirm()

  async function handleExclude(productId: string, name: string) {
    const confirmed = await confirm({
      title: t('admin.collections.exclusions.confirm_title'),
      message: t('admin.collections.exclusions.confirm_message', { name }),
      confirmLabel: t('admin.collections.exclusions.exclude'),
      variant: 'destructive',
    })
    if (confirmed) await exclude.mutateAsync(productId)
  }

  return (
    <DeferredProductMembershipCard
      parentId={collectionId}
      storeId={storeId}
      useProducts={useCollectionProducts}
      listMembersPage={listCollectionProductsPage}
      onReorder={(productId, new_position) => reposition.mutateAsync({ productId, new_position })}
      translationNamespace="admin.collections"
      description={hasRules ? t('admin.collections.products.rules_hint') : undefined}
      extraColumns={(products) => {
        const ruleMatched = new Set(
          products
            .filter((product) => product.membership_source === 'rule')
            .map((product) => product.id),
        )

        return {
          columnCount: 1,
          headers: (
            <TableHead>
              <span className="sr-only">{t('admin.collections.exclusions.exclude')}</span>
            </TableHead>
          ),
          // Only a rule-matched member comes back after a remove. A staged
          // addition is never in the set: it isn't a member yet.
          renderCells: (row) => (
            <TableCell>
              {ruleMatched.has(row.id) && (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button
                      type="button"
                      variant="destructive-ghost"
                      size="sm"
                      aria-label={t('admin.collections.exclusions.exclude_row', {
                        name: row.name ?? '',
                      })}
                      onClick={() => handleExclude(row.id, row.name ?? '')}
                    >
                      <BanIcon className="size-4" />
                      {t('admin.collections.exclusions.exclude')}
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    {t('admin.collections.exclusions.exclude_tooltip')}
                  </TooltipContent>
                </Tooltip>
              )}
            </TableCell>
          ),
        }
      }}
    />
  )
}
