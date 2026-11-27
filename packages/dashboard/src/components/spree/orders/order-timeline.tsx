import type { Order, OrderActivity } from '@spree/admin-sdk'
import {
  type ActivityKind,
  Can,
  Subject,
  useActivityKinds,
  useAuth,
  useMoneyLocale,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  Pagination,
  Section,
  SectionHeader,
  SectionTitle,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { CircleIcon, HistoryIcon } from '@spree/dashboard-ui/icons'
import { activeDateLocale } from '@spree/dashboard-ui/lib/date-locale'
import { format } from 'date-fns'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useDeleteOrderComment,
  useOrderActivities,
  useOrderComment,
  useRequestedOrderChange,
  useSettleOrderChange,
} from '../../../hooks/use-order'
import { describeAction } from '../../../timeline/default'
import { ActorLabel } from '../actor-label'

/**
 * Everything that happened to a placed order, newest first and grouped by day,
 * with staff comments in between (docs/plans/6.1-order-timeline.md). A change
 * still waiting to be applied sits on top, since it has not happened yet.
 */
export function OrderTimeline({ order }: { order: Order }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useOrderActivities(order.id, page)
  const activities = data?.data ?? []
  const onLastPage = !data?.meta || data.meta.page >= data.meta.pages
  // Orders placed before the timeline existed have no placement entry.
  const startRecorded = activities.some((activity) => activity.kind === 'order.placed')

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <HistoryIcon />
          {t('admin.orders.detail.timeline.title')}
        </SectionTitle>
      </SectionHeader>
      <Card>
        <CardContent className="flex flex-col gap-4 p-3">
          {/* Applying a change and commenting both write to the order. */}
          <Can I="update" a={Subject.Order}>
            <RequestedChange order={order} />
            <CommentForm orderId={order.id} />
          </Can>
          {isLoading ? (
            <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
          ) : (
            groupByDay(activities).map(([day, entries]) => (
              <div key={day} className="flex flex-col gap-2">
                <h3 className="font-medium text-muted-foreground text-sm">{day}</h3>
                <ul className="flex flex-col gap-3">
                  {entries.map((activity) => (
                    <TimelineEntry key={activity.id} activity={activity} order={order} />
                  ))}
                </ul>
              </div>
            ))
          )}
          {!isLoading && onLastPage && !startRecorded && (
            <p className="text-muted-foreground text-base">
              {t('admin.orders.detail.timeline.earlier_not_recorded')}
            </p>
          )}
          {(data?.meta?.pages ?? 1) > 1 && data?.meta && (
            <Pagination meta={data.meta} onPageChange={setPage} />
          )}
        </CardContent>
      </Card>
    </Section>
  )
}

function groupByDay(activities: OrderActivity[]): [string, OrderActivity[]][] {
  const locale = activeDateLocale()
  const days = new Map<string, OrderActivity[]>()
  for (const activity of activities) {
    const day = format(new Date(activity.created_at), 'PPP', { locale })
    days.set(day, [...(days.get(day) ?? []), activity])
  }
  return [...days]
}

const FALLBACK_KIND: ActivityKind = {
  kind: '',
  Summary: ({ activity }) => <>{activity.kind}</>,
}

function TimelineEntry({ activity, order }: { activity: OrderActivity; order: Order }) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const confirm = useConfirm()
  const deleteComment = useDeleteOrderComment(order.id)
  const kind = useActivityKinds().get(activity.kind) ?? FALLBACK_KIND
  const Icon = kind.icon ?? CircleIcon
  const { permissions } = usePermissions()
  const ownComment =
    activity.kind === 'comment' &&
    !!user &&
    activity.actor_id === user.id &&
    permissions.can('update', Subject.Order)

  async function handleDelete() {
    const confirmed = await confirm({
      message: t('admin.orders.detail.timeline.delete_comment_confirm'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (confirmed) deleteComment.mutate(activity.id)
  }

  return (
    <li className="flex gap-3 text-base" data-kind={activity.kind}>
      <span className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-muted">
        <Icon className="size-3.5 text-muted-foreground" />
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <div className="flex flex-wrap items-baseline justify-between gap-x-3">
          <span className="min-w-0">
            <kind.Summary activity={activity} order={order} />
          </span>
          <time className="shrink-0 text-muted-foreground text-sm" dateTime={activity.created_at}>
            {format(new Date(activity.created_at), 'p', { locale: activeDateLocale() })}
          </time>
        </div>
        {activity.actor && (
          <span className="text-muted-foreground text-sm">
            <ActorLabel actor={activity.actor} />
          </span>
        )}
        {kind.Details && <kind.Details activity={activity} order={order} />}
        {ownComment && (
          <Button
            variant="ghost"
            size="sm"
            className="self-start"
            disabled={deleteComment.isPending}
            onClick={handleDelete}
          >
            {t('admin.orders.detail.timeline.delete_comment')}
          </Button>
        )}
      </div>
    </li>
  )
}

function CommentForm({ orderId }: { orderId: string }) {
  const { t } = useTranslation()
  const [body, setBody] = useState('')
  const comment = useOrderComment(orderId)

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (!body.trim()) return
    comment.mutate(body, { onSuccess: () => setBody('') })
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2">
      <Textarea
        value={body}
        onChange={(event) => setBody(event.target.value)}
        placeholder={t('admin.orders.detail.timeline.comment_placeholder')}
        aria-label={t('admin.orders.detail.timeline.comment_placeholder')}
        rows={2}
      />
      <Button
        type="submit"
        size="sm"
        className="self-end"
        disabled={!body.trim() || comment.isPending}
      >
        {t('admin.orders.detail.timeline.post_comment')}
      </Button>
    </form>
  )
}

function RequestedChange({ order }: { order: Order }) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const { data: change } = useRequestedOrderChange(order.id)
  const settle = useSettleOrderChange(order.id)
  if (!change) return null

  return (
    <div
      className="flex flex-col gap-2 rounded-md border border-dashed p-3 text-base"
      data-testid="requested-order-change"
    >
      <div>
        <p className="font-medium">{t('admin.orders.detail.timeline.change_requested')}</p>
        {change.requested_by && (
          <p className="text-muted-foreground text-sm">
            <ActorLabel actor={change.requested_by} />
          </p>
        )}
      </div>
      <ul className="flex flex-col gap-0.5 text-muted-foreground">
        {change.actions.map((action) => (
          <li key={action.id}>{describeAction(action, order.currency, moneyLocale, t)}</li>
        ))}
      </ul>
      <div className="flex gap-2">
        <Button
          size="sm"
          disabled={settle.isPending}
          onClick={() => settle.mutate({ id: change.id, action: 'confirm' })}
        >
          {t('admin.orders.detail.timeline.apply_change')}
        </Button>
        <Button
          size="sm"
          variant="outline"
          disabled={settle.isPending}
          onClick={() => settle.mutate({ id: change.id, action: 'cancel' })}
        >
          {t('admin.orders.detail.timeline.discard_change')}
        </Button>
      </div>
    </div>
  )
}
