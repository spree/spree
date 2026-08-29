import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import { TaxIdentifiersCard } from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { sellerClient } from '../api-client'

/**
 * The seller's own tax registrations, rendered by the same panel a company's
 * are managed from: a seller is a business like any other, and two surfaces
 * for one job is how they come to behave differently.
 */
export function SellerTaxIdentifiersCard() {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const queryKey = ['seller', sellerId, 'tax_identifiers']

  const { data, isLoading } = useQuery({
    queryKey,
    queryFn: () => sellerClient().taxIdentifiers.list(),
  })

  // A registration can satisfy an onboarding requirement, so the checklist has
  // to re-evaluate whenever one changes.
  function refresh() {
    void queryClient.invalidateQueries({ queryKey })
    void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
  }

  const create = useMutation({
    mutationFn: (params: { kind: string; value: string }) =>
      sellerClient().taxIdentifiers.create(params),
    onSuccess: refresh,
  })
  const update = useMutation({
    mutationFn: ({ id, params }: { id: string; params: { kind: string; value: string } }) =>
      sellerClient().taxIdentifiers.update(id, params),
    onSuccess: refresh,
  })
  const remove = useMutation({
    mutationFn: (id: string) => sellerClient().taxIdentifiers.remove(id),
    onSuccess: refresh,
  })
  const validate = useMutation({
    mutationFn: (id: string) => sellerClient().taxIdentifiers.validate(id),
    onSuccess: refresh,
  })

  return (
    <TaxIdentifiersCard
      identifiers={data?.data ?? []}
      isLoading={isLoading}
      canEdit
      mutations={{
        create: (params) => create.mutateAsync(params),
        update: (id, params) => update.mutateAsync({ id, params }),
        remove: (id) => remove.mutateAsync(id),
        validate: (id) => validate.mutateAsync(id),
        isValidating: validate.isPending,
        mapErrors: mapSpreeErrorsToForm,
      }}
    />
  )
}
