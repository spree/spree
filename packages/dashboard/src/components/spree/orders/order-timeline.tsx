import type { Order, OrderActivity } from '@spree/admin-sdk'
import {
  type ActivityKind,
  Can,
  formatStoreTime,
  getInitials,
  Subject,
  useActivityKinds,
  useAuth,
  useStore,
} from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  Card,
  cn,
  Pagination,
  Section,
  SectionHeader,
  SectionTitle,
  Textarea,
  Timeline,
  TimelineGroup,
  TimelineItem,
} from '@spree/dashboard-ui'
import { ChevronDownIcon, HistoryIcon } from '@spree/dashboard-ui/icons'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useOrderActivities,
  useOrderComment,
  useRequestedOrderChange,
  useSettleOrderChange,
} from '../../../hooks/use-order'
import { OrderChangeActions } from '../../../timeline/default'
import { ActorLabel } from '../actor-label'

/**
 * Everything that happened to a placed order, newest first and grouped by day,
 * with staff comments in between (docs/plans/6.1-order-timeline.md). A change
 * still waiting to be applied sits on top, since it has not happened yet.
 */
export function OrderTimeline({ order }: { order: Order }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { timezone } = useStore()
  const kinds = useActivityKinds()
  const { data, isLoading, isError } = useOrderActivities(order.id, page)
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
      {/* Applying a change and commenting both write to the order. */}
      <Can I="update" a={Subject.Order}>
        <RequestedChange order={order} />
        <CommentForm orderId={order.id} />
      </Can>
      {isLoading ? (
        <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
      ) : isError ? (
        <p className="text-destructive text-base">
          {t('admin.orders.detail.timeline.load_failed')}
        </p>
      ) : (
        <Timeline className="ml-4">
          {groupByDay(activities, timezone).map(([day, entries]) => (
            <TimelineGroup key={day} label={day}>
              {entries.map((activity) => (
                <TimelineEntry
                  key={activity.id}
                  activity={activity}
                  kind={kinds.get(activity.kind) ?? FALLBACK_KIND}
                  order={order}
                  timezone={timezone}
                />
              ))}
            </TimelineGroup>
          ))}
          {data && onLastPage && !startRecorded && (
            <p className="pl-10 text-muted-foreground text-sm">
              {t('admin.orders.detail.timeline.earlier_not_recorded')}
            </p>
          )}
        </Timeline>
      )}
      {(data?.meta?.pages ?? 1) > 1 && data?.meta && (
        <Pagination meta={data.meta} onPageChange={setPage} />
      )}
    </Section>
  )
}

function groupByDay(activities: OrderActivity[], timezone: string): [string, OrderActivity[]][] {
  const days = new Map<string, OrderActivity[]>()
  for (const activity of activities) {
    const day = formatStoreTime(activity.created_at, timezone, 'PPP')
    const entries = days.get(day)
    if (entries) entries.push(activity)
    else days.set(day, [activity])
  }
  return [...days]
}

const FALLBACK_KIND: ActivityKind = {
  kind: '',
  Summary: ({ activity }) => <>{activity.kind}</>,
}

function TimelineEntry({
  activity,
  kind,
  order,
  timezone,
}: {
  activity: OrderActivity
  kind: ActivityKind
  order: Order
  timezone: string
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const Icon = kind.icon
  const Details = kind.Details && (kind.hasDetails?.(activity) ?? true) ? kind.Details : undefined

  return (
    <TimelineItem
      data-kind={activity.kind}
      icon={Icon && <Icon />}
      time={
        <time dateTime={activity.created_at}>
          {formatStoreTime(activity.created_at, timezone, 'p')}
        </time>
      }
    >
      <div>
        <kind.Summary activity={activity} order={order} />
        {activity.actor && !kind.namesActor && (
          <span className="text-muted-foreground">
            {' · '}
            <ActorLabel actor={activity.actor} />
          </span>
        )}
        {Details && (
          <button
            type="button"
            className="ml-1 inline-flex size-5 translate-y-1 items-center justify-center rounded text-muted-foreground hover:bg-muted"
            aria-expanded={open}
            aria-label={t('admin.orders.detail.timeline.show_details')}
            onClick={() => setOpen(!open)}
          >
            <ChevronDownIcon className={cn('size-4 transition-transform', open && 'rotate-180')} />
          </button>
        )}
      </div>
      {open && Details && <Details activity={activity} order={order} />}
    </TimelineItem>
  )
}

function CommentForm({ orderId }: { orderId: string }) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const [body, setBody] = useState('')
  const comment = useOrderComment(orderId)

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (!body.trim()) return
    comment.mutate(body, { onSuccess: () => setBody('') })
  }

  return (
    <div className="flex flex-col gap-2">
      <Card className="gap-0 overflow-hidden p-0">
        <form onSubmit={handleSubmit}>
          <div className="flex items-start gap-3 p-3">
            <Avatar className="size-8 rounded-md">
              {user?.avatar_url && <AvatarImage src={user.avatar_url} alt="" />}
              <AvatarFallback className="rounded-md">
                {getInitials(user?.full_name ?? user?.email, '?')}
              </AvatarFallback>
            </Avatar>
            <Textarea
              value={body}
              onChange={(event) => setBody(event.target.value)}
              placeholder={t('admin.orders.detail.timeline.comment_placeholder')}
              aria-label={t('admin.orders.detail.timeline.comment_placeholder')}
              rows={1}
              className="min-h-8 resize-none border-0 p-1 shadow-none focus-visible:ring-0"
            />
          </div>
          <div className="flex justify-end border-t bg-muted/50 px-3 py-2">
            <Button type="submit" size="sm" disabled={!body.trim() || comment.isPending}>
              {t('admin.orders.detail.timeline.post_comment')}
            </Button>
          </div>
        </form>
      </Card>
      <p className="text-right text-muted-foreground text-sm">
        {t('admin.orders.detail.timeline.comments_staff_only')}
      </p>
    </div>
  )
}

function RequestedChange({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { data: change } = useRequestedOrderChange(order.id)
  const settle = useSettleOrderChange(order.id)
  if (!change) return null

  return (
    <Card
      className="flex flex-col gap-2 border-dashed p-3 text-base"
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
      <OrderChangeActions change={change} order={order} />
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
    </Card>
  )
}
