import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Pagination,
  Table,
  TableBody,
  TableCell,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCollectionExclusions,
  useRemoveCollectionExclusion,
} from '../../../hooks/use-collections'

/**
 * Products kept out of the collection whatever its rules match or a merchant
 * picked. Lifting an exclusion writes at once and brings the product back if
 * the rules match it; the card stays hidden while there is nothing excluded.
 */
export function CollectionExclusionsCard({ collectionId }: { collectionId: string }) {
  const { t } = useTranslation()
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/collections/$collectionId',
  })
  const [page, setPage] = useState(1)
  const { data } = useCollectionExclusions(collectionId, page)
  const removeExclusion = useRemoveCollectionExclusion(collectionId)
  const confirm = useConfirm()
  const exclusions = data?.data ?? []

  if (!data || data.meta.count === 0) return null

  async function handleRemove(exclusionId: string, name: string) {
    const confirmed = await confirm({
      title: t('admin.collections.exclusions.remove_confirm_title'),
      message: t('admin.collections.exclusions.remove_confirm_message', { name }),
      confirmLabel: t('admin.collections.exclusions.remove'),
    })
    if (confirmed) await removeExclusion.mutateAsync(exclusionId)
  }

  return (
    <Card className="overflow-hidden">
      <CardHeader>
        <CardTitle>
          {t('admin.collections.exclusions.title')}
          <span className="ml-2 font-normal text-muted-foreground text-sm">{data.meta.count}</span>
        </CardTitle>
        <CardDescription>{t('admin.collections.exclusions.description')}</CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <Table>
          <TableBody>
            {exclusions.map((exclusion) => {
              const name = exclusion.product?.name ?? exclusion.product_id
              return (
                <TableRow key={exclusion.id}>
                  <TableCell className="w-full max-w-0">
                    <Link
                      to="/$storeId/products/$productId"
                      params={{ storeId, productId: exclusion.product_id }}
                      className="truncate text-sm hover:underline"
                    >
                      {name}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      aria-label={t('admin.collections.exclusions.remove_row', { name })}
                      onClick={() => handleRemove(exclusion.id, name)}
                    >
                      {t('admin.collections.exclusions.remove')}
                    </Button>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
        <Pagination meta={data.meta} onPageChange={setPage} />
      </CardContent>
    </Card>
  )
}
