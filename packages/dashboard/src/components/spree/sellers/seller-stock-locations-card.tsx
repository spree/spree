import type { Seller } from '@spree/admin-sdk'
import { EditStockLocationSheet, useResourceKey } from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Pagination,
  Section,
  SectionHeader,
  SectionTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { WarehouseIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useSellerStockLocations } from '../../../hooks/use-sellers'
import { StockHistoryCard } from '../stock-history-card'
import { StockLevelsPanel } from '../stock-levels-panel'

/**
 * Where this seller ships from. Each row opens the location's editor over
 * this page, so the operator never leaves the seller.
 */
export function SellerStockLocationsCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const [editing, setEditing] = useState<string | null>(null)
  const { data, isLoading } = useSellerStockLocations(seller.id, page)
  const queryClient = useQueryClient()
  const sellerKey = useResourceKey('sellers', seller.id)

  const locations = data?.data ?? []
  const count = data?.meta.count ?? 0

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <WarehouseIcon />
          {t('admin.settings_nav.items.stock_locations')}
          {count > 0 && <Badge variant="outline">{count}</Badge>}
        </SectionTitle>
      </SectionHeader>

      <Card>
        {locations.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <WarehouseIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.stock_locations.empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <Table roundedTop>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.stock_locations.columns.location')}</TableHead>
                  <TableHead>{t('admin.stock_locations.columns.type')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {locations.map((location) => (
                  <TableRow key={location.id}>
                    <TableCell>
                      <button
                        type="button"
                        onClick={() => setEditing(location.id)}
                        className="flex flex-col text-left"
                      >
                        <span className="flex items-center gap-2 font-medium">
                          {location.name}
                          {location.default && (
                            <Badge variant="outline">
                              {t('admin.stock_locations.badges.seller_default')}
                            </Badge>
                          )}
                          {!location.active && (
                            <Badge variant="outline">
                              {t('admin.stock_locations.badges.inactive')}
                            </Badge>
                          )}
                        </span>
                        <span className="text-muted-foreground">
                          {[location.city, location.country_name].filter(Boolean).join(', ')}
                        </span>
                      </button>
                    </TableCell>
                    <TableCell>{t(`admin.stock_locations.kinds.${location.kind}`)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {data?.meta && data.meta.pages > 1 && (
              <CardContent>
                <Pagination meta={data.meta} onPageChange={setPage} />
              </CardContent>
            )}
          </>
        )}
      </Card>

      {editing && (
        <EditStockLocationSheet
          id={editing}
          open
          onOpenChange={(open) => {
            if (open) return
            setEditing(null)
            // The seller's returns address is read off its locations.
            queryClient.invalidateQueries({ queryKey: sellerKey })
          }}
          stockLevelsPanel={StockLevelsPanel}
          activityPanel={StockHistoryPanel}
        />
      )}
    </Section>
  )
}

function StockHistoryPanel({ stockLocationId }: { stockLocationId: string }) {
  return <StockHistoryCard stockLocationId={stockLocationId} />
}
