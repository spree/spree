import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  type DragMoveEvent,
  type DragOverEvent,
  type DragStartEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import { SortableContext, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Category } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  cn,
  DragHandle,
  RowActions,
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { ChevronDownIcon, ChevronRightIcon, LanguagesIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  buildForest,
  collapsibleIds,
  type FlatNode,
  flatten,
  getProjection,
  INDENTATION_WIDTH,
  removeChildrenOf,
} from './category-tree-utils'

interface CategoryTreeProps {
  categories: Category[]
  onEdit: (category: Category) => void
  onTranslate: (category: Category) => void
  onDelete: (category: Category) => void
  /** Move `id` under `parentId` (null = top level) at the given sibling index. */
  onReorder: (id: string, parentId: string | null, position: number) => void
  deleting?: boolean
}

/**
 * Category tree — a faithful port of the dnd-kit "Tree" example (the same
 * pattern Medusa's category tree uses). The tree flattens into one ordered
 * SortableContext; dragging vertically reorders, dragging horizontally
 * re-parents (depth projected from the pointer's horizontal offset). Collapsed
 * by default, one level at a time.
 */
export function CategoryTree({
  categories,
  onEdit,
  onTranslate,
  onDelete,
  onReorder,
  deleting,
}: CategoryTreeProps) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const forest = useMemo(() => buildForest(categories), [categories])
  const categoriesById = useMemo(() => new Map(categories.map((c) => [c.id, c])), [categories])

  const [collapsed, setCollapsed] = useState<Set<string>>(() => collapsibleIds(forest))
  const [activeId, setActiveId] = useState<string | null>(null)
  const [overId, setOverId] = useState<string | null>(null)
  const [offsetLeft, setOffsetLeft] = useState(0)

  const flattened = useMemo(() => {
    const all = flatten(forest, collapsed)
    return activeId ? removeChildrenOf(all, [activeId]) : all
  }, [forest, collapsed, activeId])

  const projection =
    activeId && overId ? getProjection(flattened, activeId, overId, offsetLeft) : null

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor),
  )

  function toggle(id: string) {
    setCollapsed((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function handleDragStart({ active }: DragStartEvent) {
    setActiveId(active.id as string)
    setOverId(active.id as string)
  }

  function handleDragMove({ delta }: DragMoveEvent) {
    setOffsetLeft(delta.x)
  }

  function handleDragOver({ over }: DragOverEvent) {
    setOverId((over?.id as string) ?? null)
  }

  function handleDragEnd({ active }: DragEndEvent) {
    const id = active.id as string
    const result = projection
    reset()
    if (result) onReorder(id, result.parentId, result.position)
  }

  function reset() {
    setActiveId(null)
    setOverId(null)
    setOffsetLeft(0)
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragStart={handleDragStart}
      onDragMove={handleDragMove}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
      onDragCancel={reset}
    >
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-8" />
            <TableHead>{t('admin.categories.columns.name')}</TableHead>
            <TableHead className="w-28 text-right">
              {t('admin.categories.columns.products')}
            </TableHead>
            <TableHead className="w-12" />
          </TableRow>
        </TableHeader>
        <TableBody className="border-t border-border">
          {flattened.length === 0 ? (
            <TableEmpty colSpan={4}>{t('admin.categories.empty')}</TableEmpty>
          ) : (
            <SortableContext
              items={flattened.map((n) => n.id)}
              strategy={verticalListSortingStrategy}
            >
              {flattened.map((node) => (
                <Row
                  key={node.id}
                  node={node}
                  depth={node.id === activeId && projection ? projection.depth : node.depth}
                  collapsed={collapsed.has(node.id)}
                  onToggle={() => toggle(node.id)}
                  canDestroy={permissions.can('destroy', Subject.Taxon)}
                  deleting={deleting}
                  onEdit={() => onEdit(categoriesById.get(node.id) as Category)}
                  onTranslate={() => onTranslate(categoriesById.get(node.id) as Category)}
                  onDelete={() => onDelete(categoriesById.get(node.id) as Category)}
                />
              ))}
            </SortableContext>
          )}
        </TableBody>
      </Table>
    </DndContext>
  )
}

interface RowProps {
  node: FlatNode
  depth: number
  collapsed: boolean
  onToggle: () => void
  canDestroy: boolean
  deleting?: boolean
  onEdit: () => void
  onTranslate: () => void
  onDelete: () => void
}

function Row({
  node,
  depth,
  collapsed,
  onToggle,
  canDestroy,
  deleting,
  onEdit,
  onTranslate,
  onDelete,
}: RowProps) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: node.id,
  })
  const hasChildren = node.childCount > 0

  return (
    <TableRow
      ref={setNodeRef}
      style={{ transform: CSS.Translate.toString(transform), transition }}
      className={cn(isDragging && 'opacity-40')}
    >
      <TableCell className="w-10 pr-0">
        <DragHandle attributes={attributes} listeners={listeners} className="size-7" />
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-2" style={{ paddingLeft: depth * INDENTATION_WIDTH }}>
          {hasChildren ? (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="size-5 shrink-0"
              aria-label={t(collapsed ? 'admin.categories.expand' : 'admin.categories.collapse')}
              onClick={onToggle}
            >
              {collapsed ? (
                <ChevronRightIcon className="size-4" />
              ) : (
                <ChevronDownIcon className="size-4" />
              )}
            </Button>
          ) : (
            <span className="inline-block size-5 shrink-0" />
          )}

          <button type="button" className="truncate text-left hover:underline" onClick={onEdit}>
            {node.name}
          </button>
        </div>
      </TableCell>
      <TableCell className="w-28 text-right text-muted-foreground tabular-nums">
        {t('admin.categories.products_count', { count: node.productsCount })}
      </TableCell>
      <TableCell className="w-12 text-right">
        <RowActions
          actions={[
            { key: 'edit', onSelect: onEdit },
            {
              key: 'translate',
              label: t('admin.translations.manage'),
              icon: <LanguagesIcon />,
              onSelect: onTranslate,
            },
            {
              key: 'delete',
              destructive: true,
              visible: canDestroy,
              disabled: deleting,
              onSelect: onDelete,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}
