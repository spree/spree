import type { Customer } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete, useStore } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { PencilIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  customerGroupAutocompleteProps,
  useCustomerGroups,
} from '../../../hooks/use-customer-groups'
import { useUpdateCustomerGroups } from '../../../hooks/use-customers'

export function CustomerGroupsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [editOpen, setEditOpen] = useState(false)
  const groups = customer.customer_groups ?? []

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.customers.detail.groups.title')}
            {groups.length > 0 && <Badge variant="outline">{groups.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setEditOpen(true)}
              aria-label={t('admin.actions.edit')}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent>
          {groups.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              {t('admin.customers.detail.groups.empty')}
            </p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {groups.map((group) => (
                <Badge key={group.id} variant="secondary" className="gap-1.5">
                  <UsersIcon className="size-3 text-muted-foreground" />
                  {group.name}
                </Badge>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
      <EditGroupsSheet customer={customer} open={editOpen} onOpenChange={setEditOpen} />
    </>
  )
}

function EditGroupsSheet({
  customer,
  open,
  onOpenChange,
}: {
  customer: Customer
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const currentIds = useMemo(() => customer.customer_group_ids ?? [], [customer.customer_group_ids])
  const [groupIds, setGroupIds] = useState<string[]>(currentIds)
  const [error, setError] = useState<string | null>(null)

  // Surface the store's groups on focus (preloaded, 5-min cache) and re-seed
  // the selection whenever the sheet re-opens so a prior cancelled edit or an
  // external membership change is reflected.
  //
  // This tracks `currentIds` rather than only the open transition: the picker
  // holds a selection, not typed text, and it has to pick up the membership a
  // save just wrote before the sheet is opened again.
  const { data: groupsData } = useCustomerGroups()
  useEffect(() => {
    if (open) {
      setGroupIds(currentIds)
      setError(null)
    }
  }, [open, currentIds])

  // `customer_group_ids` is a collection setter on the customer: PATCH replaces
  // the whole membership in one request, so no add/remove diffing needed.
  const mutation = useUpdateCustomerGroups(customer.id)
  const isPending = mutation.isPending

  async function handleSave() {
    setError(null)
    try {
      await mutation.mutateAsync(groupIds)
      onOpenChange(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('admin.customers.detail.groups.save_failed'))
    }
  }

  const dirty =
    groupIds.length !== currentIds.length || groupIds.some((id) => !currentIds.includes(id))

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.customers.detail.groups.edit_title')}</SheetTitle>
          <SheetDescription>{t('admin.customers.detail.groups.edit_description')}</SheetDescription>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {error && (
            <p className="text-sm text-destructive" role="alert">
              {error}
            </p>
          )}
          <Field>
            <FieldLabel>{t('admin.fields.customer.customer_groups.label')}</FieldLabel>
            <ResourceMultiAutocomplete
              {...customerGroupAutocompleteProps(`customer-detail-groups-picker-${storeId}`)}
              initialItems={groupsData?.data}
              value={groupIds}
              onChange={setGroupIds}
            />
          </Field>
        </div>
        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleSave} disabled={isPending || !dirty}>
            {isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
