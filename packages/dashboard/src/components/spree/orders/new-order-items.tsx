import type { Variant } from '@spree/admin-sdk'
import { isDecimalString, multiplyMoney } from '@spree/core'
import { Money } from '@spree/dashboard-core'
import {
  Button,
  Card,
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Input,
  ProductIdentity,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { PackageIcon, PlusIcon, XIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

export interface NewOrderItem {
  variant: Variant
  quantity: number
}

/**
 * The items of an order being created, laid out like the edit screen's: the
 * same columns, product rows and "Add product" sheet, so building an order and
 * changing one look alike. Held in page state until the order is created.
 */
export function NewOrderItems({
  items,
  currency,
  canAdd,
  onAdd,
  onQuantityChange,
  onRemove,
}: {
  items: NewOrderItem[]
  currency: string
  /** Off until the market and channel are known, which the search depends on. */
  canAdd: boolean
  onAdd: () => void
  onQuantityChange: (variantId: string, quantity: number) => void
  onRemove: (variantId: string) => void
}) {
  const { t } = useTranslation()

  const addButton = (
    <Button type="button" variant="outline" size="sm" disabled={!canAdd} onClick={onAdd}>
      <PlusIcon className="size-4" />
      {t('admin.orders.edit.actions.add_product')}
    </Button>
  )

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <PackageIcon />
          {t('admin.pages.orders.new.section_items')}
        </SectionTitle>
        {items.length > 0 && <SectionActions>{addButton}</SectionActions>}
      </SectionHeader>
      <Card>
        {items.length === 0 ? (
          <Empty className="p-6">
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <PackageIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.pages.orders.new.items_empty.title')}</EmptyTitle>
              <EmptyDescription>
                {t('admin.pages.orders.new.items_empty.description')}
              </EmptyDescription>
            </EmptyHeader>
            <EmptyContent>{addButton}</EmptyContent>
          </Empty>
        ) : (
          <Table roundedTop>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.orders.edit.columns.product')}</TableHead>
                <TableHead className="text-right">
                  {t('admin.orders.edit.columns.unit_price')}
                </TableHead>
                <TableHead className="w-32 text-right">
                  {t('admin.fields.quantity.label')}
                </TableHead>
                <TableHead className="text-right">
                  {t('admin.orders.edit.columns.line_total')}
                </TableHead>
                <TableHead className="w-16" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {items.map(({ variant, quantity }) => {
                const name = variant.product_name ?? variant.sku ?? variant.id
                const amount = variant.price?.amount
                return (
                  <TableRow key={variant.id}>
                    <TableCell>
                      <ProductIdentity
                        name={name}
                        subtitle={variant.options_text}
                        thumbnailUrl={variant.thumbnail_url}
                        size="lg"
                      />
                    </TableCell>
                    <TableCell className="text-right whitespace-nowrap">
                      {isDecimalString(amount) ? (
                        <Money amount={amount} currency={currency} />
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Input
                        type="number"
                        min={1}
                        inputMode="numeric"
                        className="ml-auto w-24 text-right"
                        aria-label={t('admin.orders.edit.actions.quantity_for', { name })}
                        value={quantity}
                        onChange={(event) =>
                          onQuantityChange(variant.id, Number(event.target.value))
                        }
                      />
                    </TableCell>
                    <TableCell className="text-right whitespace-nowrap">
                      {isDecimalString(amount) ? (
                        <Money amount={multiplyMoney(amount, quantity)} currency={currency} />
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant="destructive-ghost"
                        size="icon"
                        onClick={() => onRemove(variant.id)}
                        aria-label={t('admin.orders.edit.actions.remove_item', { name })}
                      >
                        <XIcon className="size-4 text-destructive" />
                      </Button>
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        )}
      </Card>
    </Section>
  )
}
