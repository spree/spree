import { AddressFormDialog, type EditableAddress } from '@spree/dashboard-core'
import {
  AddressBlock,
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
} from '@spree/dashboard-ui'
import type { StockLocation, StockLocationParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PencilIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'

/**
 * Where customers send returns — the address on the seller's default stock
 * location.
 *
 * A location rather than a loose address because returned goods have to be
 * restocked somewhere the catalog can see: stock movements anchor to a
 * location, so an address on its own would leave the parcel arriving nowhere.
 * The seller sees an address form all the same — the location is the record
 * behind it, not a concept they have to learn to fill this in.
 */
export function SellerReturnsLocationCard({ headless = false }: { headless?: boolean }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  const { data: locations } = useQuery({
    queryKey: ['seller', sellerId, 'stock-locations'],
    queryFn: () => sellerClient().stockLocations.list({ per_page: 100 }),
  })

  // The default one is where returns go, matching `Seller#returns_location`.
  const location = locations?.data.find((candidate) => candidate.default) ?? locations?.data[0]
  const hasAddress = Boolean(location?.address1)
  const title = t('profile.returns_address')

  const save = useMutation({
    mutationFn: (params: StockLocationParams) => {
      if (!location) throw new Error(t('common.error'))
      return sellerClient().stockLocations.update(location.id, params)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'stock-locations'] })
      // The checklist asks whether this address is filled in, so it has to
      // re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toast.success(t('profile.saved'))
    },
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  const body =
    hasAddress && location ? (
      <AddressBlock address={toAddressBlock(location)} />
    ) : (
      <p className="text-muted-foreground text-sm">{t('profile.address_not_provided')}</p>
    )

  const editButton = (
    <Button
      variant={hasAddress ? 'outline' : 'default'}
      size="sm"
      disabled={!location}
      onClick={() => setEditing(true)}
    >
      {hasAddress ? <PencilIcon className="size-4" /> : <PlusIcon className="size-4" />}
      {hasAddress ? t('profile.edit') : t('profile.add_address')}
    </Button>
  )

  const dialog = editing && location && (
    <AddressFormDialog
      title={title}
      address={toEditableAddress(location)}
      open
      business
      onOpenChange={setEditing}
      onSave={(values) => save.mutate(toStockLocationParams(values))}
      isPending={save.isPending}
    />
  )

  if (headless) {
    return (
      <div className="flex flex-col items-start gap-3">
        {body}
        {editButton}
        {dialog}
      </div>
    )
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {title}
            {hasAddress ? (
              <Badge variant="success">{t('profile.address_filled')}</Badge>
            ) : (
              <Badge variant="outline">{t('profile.address_missing')}</Badge>
            )}
          </CardTitle>
          <CardAction>{editButton}</CardAction>
        </CardHeader>
        <CardContent>{body}</CardContent>
      </Card>
      {dialog}
    </>
  )
}

/**
 * The three shapes this card sits between. A stock location stores `zipcode`
 * where an address says `postal_code`, and carries no personal name — mapping
 * the fields explicitly is what keeps that difference in one place instead of
 * leaking a cast into every call.
 */
function toAddressBlock(location: StockLocation) {
  return {
    company: location.company,
    address1: location.address1,
    address2: location.address2,
    city: location.city,
    state_text: location.state_text,
    postal_code: location.zipcode,
    country_code: location.country_code,
    country_name: location.country_name,
    phone: location.phone,
  }
}

function toEditableAddress(location: StockLocation) {
  return {
    id: location.id,
    company: location.company,
    address1: location.address1,
    address2: location.address2,
    city: location.city,
    postal_code: location.zipcode,
    country_code: location.country_code,
    state_code: location.state_code,
    phone: location.phone,
  }
}

function toStockLocationParams(values: EditableAddress): StockLocationParams {
  return {
    company: values.company,
    address1: values.address1,
    address2: values.address2,
    city: values.city,
    zipcode: values.postal_code,
    country_code: values.country_code,
    state_code: values.state_code,
    phone: values.phone,
  }
}
