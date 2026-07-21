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
import type { OrderRoutingRule, PaginatedResponse, ResourceTypeDefinition } from '@spree/admin-sdk'
import {
  Can,
  PreferencesForm,
  Subject,
  usePermissions,
  useResourceKeyBuilder,
} from '@spree/dashboard-core'
import { Button, DragHandle, Switch, useConfirm } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { PlusIcon, SlidersHorizontalIcon, Trash2Icon } from 'lucide-react'
import { type CSSProperties, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateOrderRoutingRule,
  useDeleteOrderRoutingRule,
  useOrderRoutingRules,
  useOrderRoutingRuleTypes,
  useUpdateOrderRoutingRule,
} from '../../hooks/use-order-routing-rules'
import { typeDescription, typeLabel } from '../../lib/type-labels'

/**
 * Per-channel routing-rules editor rendered inside the channel edit sheet.
 * Rules persist through direct per-rule mutations (not the surrounding
 * channel form), so every button here must stay `type="button"` — the
 * section lives inside the channel form element.
 */
export function OrderRoutingRulesSection({ channelId }: { channelId: string }) {
  const { t } = useTranslation()
  const { data, isLoading } = useOrderRoutingRules(channelId)
  const { data: typesData } = useOrderRoutingRuleTypes()
  const createMutation = useCreateOrderRoutingRule(channelId)
  const updateMutation = useUpdateOrderRoutingRule(channelId)
  const deleteMutation = useDeleteOrderRoutingRule(channelId)
  const confirm = useConfirm()
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  const { permissions } = usePermissions()

  const rules = data?.data ?? []
  // Rule kinds are unique per channel (DB-enforced) — only offer what's left.
  const availableTypes = useMemo(() => {
    const usedTypes = new Set(rules.map((r) => r.type))
    return (typesData?.data ?? []).filter((t) => !usedTypes.has(t.type))
  }, [rules, typesData])
  const canUpdate = permissions.can('update', Subject.OrderRoutingRule)

  const [showPicker, setShowPicker] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const fromIndex = rules.findIndex((r) => r.id === active.id)
    const toIndex = rules.findIndex((r) => r.id === over.id)
    if (fromIndex === -1 || toIndex === -1) return

    // Reorder the cache first so the row doesn't snap back while the PATCH
    // runs; the mutation's invalidation then restores canonical positions.
    const next = arrayMove(rules, fromIndex, toIndex).map((r, i) => ({ ...r, position: i + 1 }))
    queryClient.setQueryData(
      buildKey('channels', channelId, 'order-routing-rules'),
      (prev: PaginatedResponse<OrderRoutingRule> | undefined) =>
        prev ? { ...prev, data: next } : prev,
    )
    updateMutation.mutate({ id: String(active.id), params: { position: toIndex + 1 } })
  }

  async function handleDelete(rule: OrderRoutingRule) {
    const ok = await confirm({
      title: t('admin.pages.channels.order_routing_rules.delete_confirm.title'),
      message: t('admin.pages.channels.order_routing_rules.delete_confirm.message', {
        name: typeLabel('order_routing_rule_types', rule.type, rule.label),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    if (editingId === rule.id) setEditingId(null)
    await deleteMutation.mutateAsync(rule.id).catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-2 border-t pt-4">
      <div>
        <span className="text-sm font-medium">
          {t('admin.pages.channels.order_routing_rules.title')}
        </span>
        <p className="text-xs text-muted-foreground">
          {t('admin.pages.channels.order_routing_rules.help')}
        </p>
      </div>

      {isLoading ? (
        <p className="text-sm text-muted-foreground">{t('admin.common.loading')}</p>
      ) : rules.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {t('admin.pages.channels.order_routing_rules.empty')}
        </p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={rules.map((r) => r.id)} strategy={verticalListSortingStrategy}>
            <ul className="flex flex-col gap-1">
              {rules.map((rule) => (
                <SortableRuleRow
                  key={rule.id}
                  rule={rule}
                  canUpdate={canUpdate}
                  canDestroy={permissions.can('destroy', Subject.OrderRoutingRule)}
                  editing={editingId === rule.id}
                  onToggleActive={(active) =>
                    updateMutation.mutate({ id: rule.id, params: { active } })
                  }
                  onToggleEdit={() => setEditingId(editingId === rule.id ? null : rule.id)}
                  onSavePreferences={(preferences) => {
                    updateMutation.mutate({ id: rule.id, params: { preferences } })
                    setEditingId(null)
                  }}
                  onDelete={() => handleDelete(rule)}
                />
              ))}
            </ul>
          </SortableContext>
        </DndContext>
      )}

      {!isLoading && availableTypes.length > 0 && (
        <Can I="create" a={Subject.OrderRoutingRule}>
          {showPicker ? (
            <RuleTypePicker
              types={availableTypes}
              disabled={createMutation.isPending}
              onPick={(type) => {
                createMutation.mutate({ type: type.type })
                setShowPicker(false)
              }}
              onCancel={() => setShowPicker(false)}
            />
          ) : (
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="self-start"
              onClick={() => setShowPicker(true)}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.channels.order_routing_rules.add_cta')}
            </Button>
          )}
        </Can>
      )}
    </div>
  )
}

function SortableRuleRow({
  rule,
  canUpdate,
  canDestroy,
  editing,
  onToggleActive,
  onToggleEdit,
  onSavePreferences,
  onDelete,
}: {
  rule: OrderRoutingRule
  canUpdate: boolean
  canDestroy: boolean
  editing: boolean
  onToggleActive: (active: boolean) => void
  onToggleEdit: () => void
  onSavePreferences: (preferences: Record<string, unknown>) => void
  onDelete: () => void
}) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: rule.id,
    disabled: !canUpdate,
  })
  const style: CSSProperties = { transform: CSS.Transform.toString(transform), transition }
  const hasPreferences = rule.preference_schema.length > 0
  const label = typeLabel('order_routing_rule_types', rule.type, rule.label)
  const description = typeDescription('order_routing_rule_types', rule.type, rule.description)

  return (
    <li
      ref={setNodeRef}
      style={style}
      className={`rounded-md border bg-card ${isDragging ? 'relative z-10 opacity-80 shadow-lg' : ''}`}
    >
      <div className="flex items-center gap-2 p-2">
        {canUpdate && (
          <span className="w-6 touch-none">
            <DragHandle attributes={attributes} listeners={listeners} />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <span className="block truncate text-sm" title={description || undefined}>
            {label}
          </span>
        </div>
        {hasPreferences && canUpdate && (
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            aria-label={t('admin.pages.channels.order_routing_rules.edit_preferences')}
            onClick={onToggleEdit}
          >
            <SlidersHorizontalIcon className="size-4" />
          </Button>
        )}
        <Switch
          checked={rule.active}
          onCheckedChange={onToggleActive}
          disabled={!canUpdate}
          aria-label={t('admin.pages.channels.order_routing_rules.active_toggle')}
        />
        {canDestroy && (
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            aria-label={t('admin.actions.delete')}
            onClick={onDelete}
          >
            <Trash2Icon className="size-4 text-destructive" />
          </Button>
        )}
      </div>
      {editing && hasPreferences && (
        <RulePreferencesEditor rule={rule} onSave={onSavePreferences} onCancel={onToggleEdit} />
      )}
    </li>
  )
}

function RulePreferencesEditor({
  rule,
  onSave,
  onCancel,
}: {
  rule: OrderRoutingRule
  onSave: (preferences: Record<string, unknown>) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const [values, setValues] = useState<Record<string, unknown>>(rule.preferences ?? {})

  return (
    <div className="flex flex-col gap-3 border-t p-3">
      <PreferencesForm schema={rule.preference_schema} values={values} onChange={setValues} />
      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" size="sm" onClick={onCancel}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" onClick={() => onSave(values)}>
          {t('admin.actions.save')}
        </Button>
      </div>
    </div>
  )
}

function RuleTypePicker({
  types,
  disabled,
  onPick,
  onCancel,
}: {
  types: ResourceTypeDefinition[]
  disabled: boolean
  onPick: (type: ResourceTypeDefinition) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-1 rounded-md border p-2">
      <span className="px-1 text-xs font-medium text-muted-foreground">
        {t('admin.pages.channels.order_routing_rules.picker_title')}
      </span>
      {types.map((type) => {
        const description = typeDescription(
          'order_routing_rule_types',
          type.type,
          type.description ?? '',
        )
        return (
          <button
            key={type.type}
            type="button"
            disabled={disabled}
            className="rounded-md px-2 py-1.5 text-left hover:bg-accent disabled:opacity-50"
            onClick={() => onPick(type)}
          >
            <span className="block text-sm">
              {typeLabel('order_routing_rule_types', type.type, type.label)}
            </span>
            {description && (
              <span className="block text-xs text-muted-foreground">{description}</span>
            )}
          </button>
        )
      })}
      <Button type="button" variant="ghost" size="sm" className="self-start" onClick={onCancel}>
        {t('admin.actions.cancel')}
      </Button>
    </div>
  )
}
