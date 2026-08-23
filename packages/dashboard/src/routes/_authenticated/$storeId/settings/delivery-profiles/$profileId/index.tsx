import type { DeliveryProfile } from '@spree/admin-sdk'
import { adminClient, PageHeader } from '@spree/dashboard-core'
import { ErrorState, ResourceLayout, useConfirm } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { DeliveryProfileGeneralCard } from '../../../../../../components/spree/shipping/delivery-profile-general-card'
import { DeliveryProfileOriginsCard } from '../../../../../../components/spree/shipping/delivery-profile-origins-card'
import { DeliveryZonesAndMethodsSection } from '../../../../../../components/spree/shipping/delivery-zones-and-methods-section'
import {
  useDeleteDeliveryProfile,
  useDeliveryProfile,
} from '../../../../../../hooks/use-delivery-profiles'
import { spreeJsonLinkResolver } from '../../../../../../lib/json-link-resolver'

/**
 * The method sheet is driven from the URL so a deep link opens it over a live
 * profile page: `method` is either a method's ID or `new`, and `zone`, `group`
 * and `provider` preselect what a new method is being created for.
 */
const profileDetailSearchSchema = z.object({
  method: z.string().optional(),
  zone: z.string().optional(),
  group: z.string().optional(),
  provider: z.enum(['pickup', 'digital']).optional(),
})

type ProfileDetailSearch = z.infer<typeof profileDetailSearchSchema>

export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/delivery-profiles/$profileId/',
)({
  validateSearch: profileDetailSearchSchema,
  component: DeliveryProfileDetailPage,
})

function DeliveryProfileDetailPage() {
  const { t } = useTranslation()
  const { profileId } = Route.useParams()
  const { data: profile, isLoading, error, refetch } = useDeliveryProfile(profileId)

  if (isLoading) {
    return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  }
  if (error || !profile) {
    return (
      <ErrorState
        title={t('admin.delivery_profiles.detail.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }
  return <DeliveryProfileDetailBody profile={profile} />
}

function DeliveryProfileDetailBody({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as ProfileDetailSearch
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryProfile()

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.delivery_profiles.delete_confirm.title'),
      message: t('admin.delivery_profiles.delete_confirm.message', { name: profile.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(profile.id)
    navigate({ to: '/$storeId/settings/delivery-profiles', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={profile.name}
          backTo="settings/delivery-profiles"
          resource={{ id: profile.id }}
          jsonPreview={{
            title: `Delivery profile ${profile.name}`,
            fetch: () => adminClient.deliveryProfiles.get(profile.id),
            endpoint: `/api/v3/admin/delivery_profiles/${profile.id}`,
            resolveLink: spreeJsonLinkResolver(storeId),
          }}
          onDelete={profile.default ? undefined : handleDelete}
          deleteLabel={t('admin.delivery_profiles.detail.delete_label')}
        />
      }
      main={<DeliveryZonesAndMethodsSection profile={profile} search={search} />}
      sidebar={
        <>
          <DeliveryProfileGeneralCard profile={profile} />
          <DeliveryProfileOriginsCard profile={profile} />
        </>
      }
    />
  )
}
