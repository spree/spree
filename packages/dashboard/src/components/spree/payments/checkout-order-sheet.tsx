import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { PaymentMethod } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  cn,
  DragHandle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Item,
  ItemContent,
  ItemMedia,
  ItemTitle,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
} from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { type CSSProperties, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * The order checkout lists its payment methods in. Methods hold one shared
 * position whichever section of the Payments page shows them, so they are
 * ordered here in a single list of what checkout actually offers: active
 * methods shown on the storefront.
 */
export function CheckoutOrderSheet({
  methods,
  open,
  onOpenChange,
}: {
  /** Every payment method, in position order. */
  methods: PaymentMethod[]
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const offered = methods.filter((method) => method.active && method.storefront_visible)
  // Held locally so a dropped row stays put while its save runs.
  const [rows, setRows] = useState(offered)
  const offeredKey = offered.map((method) => `${method.id}:${method.position}`).join(',')
  // biome-ignore lint/correctness/useExhaustiveDependencies: re-syncs only when the saved order changes
  useEffect(() => setRows(offered), [offeredKey])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  async function handleDragEnd({ active, over }: DragEndEvent) {
    if (!over || active.id === over.id) return
    const fromIndex = rows.findIndex((row) => row.id === active.id)
    const toIndex = rows.findIndex((row) => row.id === over.id)
    if (fromIndex === -1 || toIndex === -1) return

    const snapshot = rows
    setRows(arrayMove(rows, fromIndex, toIndex))
    // Methods checkout leaves out keep their positions too, so the moved
    // method takes the position of the one it landed on rather than its index
    // in this list.
    try {
      await adminClient.paymentMethods.update(String(active.id), {
        position: rows[toIndex].position,
      })
    } catch {
      setRows(snapshot)
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_update') })
    }
    queryClient.invalidateQueries({ queryKey: ['payment-methods'] })
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.payments.checkout_order.title')}</SheetTitle>
          <SheetDescription>
            {t('admin.pages.settings.payments.checkout_order.description')}
          </SheetDescription>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto p-4">
          {rows.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>
                  {t('admin.pages.settings.payments.checkout_order.empty.title')}
                </EmptyTitle>
                <EmptyDescription>
                  {t('admin.pages.settings.payments.checkout_order.empty.description')}
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              onDragEnd={handleDragEnd}
            >
              <SortableContext
                items={rows.map((row) => row.id)}
                strategy={verticalListSortingStrategy}
              >
                <ol className="flex flex-col gap-2">
                  {rows.map((method) => (
                    <CheckoutOrderRow key={method.id} method={method} />
                  ))}
                </ol>
              </SortableContext>
            </DndContext>
          )}
        </div>
        <SheetFooter>
          <Button type="button" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function CheckoutOrderRow({ method }: { method: PaymentMethod }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: method.id,
  })
  const style: CSSProperties = { transform: CSS.Transform.toString(transform), transition }

  return (
    <Item
      variant="outline"
      size="sm"
      ref={setNodeRef}
      style={style}
      render={<li />}
      className={cn(isDragging && 'relative z-10 opacity-80 shadow-lg')}
    >
      <span className="w-8 shrink-0 touch-none">
        <DragHandle attributes={attributes} listeners={listeners} />
      </span>
      <ItemMedia>
        <Avatar
          className={cn(
            'size-8 rounded-md p-1 after:rounded-md after:border-border-subtle',
            method.logo_url ? 'bg-white' : 'bg-background',
          )}
        >
          {method.logo_url && (
            <AvatarImage src={method.logo_url} className="rounded-none object-contain" />
          )}
          <AvatarFallback className="rounded-md bg-transparent font-semibold text-xs">
            {method.name.charAt(0).toUpperCase()}
          </AvatarFallback>
        </Avatar>
      </ItemMedia>
      <ItemContent className="min-w-0">
        <ItemTitle className="w-full truncate">{method.name}</ItemTitle>
      </ItemContent>
    </Item>
  )
}
