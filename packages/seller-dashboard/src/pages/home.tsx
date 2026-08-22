import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Progress,
  StatusBadge,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { Link, useParams } from '@tanstack/react-router'
import { ChevronRightIcon, PackageIcon, UsersIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

/**
 * Where a seller lands: how they stand with the marketplace, what is left to
 * do, and the counts they would otherwise open a page to see.
 *
 * The operator's home is an analytics dashboard — a sales chart and top
 * products. A seller has no analytics endpoint yet (orders are a later
 * phase), and inventing widgets over data that does not exist would be worse
 * than a smaller page that is true. This shows what the panel can actually
 * answer today; the sales card lands with the orders surface.
 */
export function HomePage() {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  const { data: profile, isLoading } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })

  const { data: onboarding } = useQuery({
    queryKey: ['seller', sellerId, 'onboarding'],
    queryFn: () => sellerClient().onboarding.get(),
  })

  const { data: team } = useQuery({
    queryKey: ['seller', sellerId, 'team'],
    queryFn: () => sellerClient().team.list(),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (!profile) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  const progress = onboarding?.progress
  const setupDone = !progress || progress.total === 0 || progress.done === progress.total

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-medium text-2xl">{t('home.title', { name: profile.name })}</h1>
        <p className="text-muted-foreground text-sm">{t('home.subtitle')}</p>
      </div>

      {/* Setup leads while it is unfinished — until a seller is approved it is
          the only thing on this page that matters. It drops away once done
          rather than sitting at 100% forever. */}
      {!setupDone && progress && (
        <Card>
          <CardHeader>
            <CardTitle>{t('home.setup_title')}</CardTitle>
            <CardDescription>
              {t('home.setup_description', { done: progress.done, total: progress.total })}
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <Progress value={progress.percentage} />
            <div>
              <Button size="sm" asChild>
                <Link to="/$sellerId/onboarding" params={{ sellerId }}>
                  {t('home.setup_cta')}
                  <ChevronRightIcon className="size-4" />
                </Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label={t('home.status')}>
          <StatusBadge status={profile.status} />
        </StatCard>
        <StatCard label={t('home.products')} icon={<PackageIcon className="size-4" />}>
          {profile.products_count}
        </StatCard>
        <StatCard label={t('home.team')} icon={<UsersIcon className="size-4" />}>
          {team?.data?.length ?? '—'}
        </StatCard>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('home.selling_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            {profile.sellable ? t('home.selling_yes') : t('home.selling_no')}
          </p>
        </CardContent>
      </Card>
    </div>
  )
}

function StatCard({
  label,
  icon,
  children,
}: {
  label: string
  icon?: ReactNode
  children: ReactNode
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardDescription className="flex items-center gap-2">
          {icon}
          {label}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="font-medium text-2xl">{children}</div>
      </CardContent>
    </Card>
  )
}
