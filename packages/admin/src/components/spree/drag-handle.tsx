import type { DraggableAttributes, DraggableSyntheticListeners } from '@dnd-kit/core'
import { GripVerticalIcon } from 'lucide-react'
import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

interface DragHandleProps extends Omit<ComponentProps<'button'>, 'type'> {
  /** `attributes` from `useSortable` / `useDraggable`. */
  attributes: DraggableAttributes
  /** `listeners` from `useSortable` / `useDraggable`. */
  listeners: DraggableSyntheticListeners
}

/**
 * Standard drag handle for `useSortable` rows. Pair with a `useSortable` row
 * by spreading its `attributes` + `listeners` onto this component:
 *
 * ```tsx
 * const { attributes, listeners, setNodeRef, ... } = useSortable({ id })
 * return (
 *   <tr ref={setNodeRef}>
 *     <td className="w-8 touch-none p-0">
 *       <DragHandle attributes={attributes} listeners={listeners} />
 *     </td>
 *     ...
 *   </tr>
 * )
 * ```
 *
 * The handle owns its own cursor styling (`cursor-grab` / `active:cursor-grabbing`),
 * hover affordance, and accessible label — the caller only needs to size the
 * surrounding cell (typically `w-8 touch-none p-0`).
 */
export function DragHandle({ attributes, listeners, className, ...props }: DragHandleProps) {
  return (
    <button
      type="button"
      aria-label="Drag to reorder"
      className={cn(
        'flex h-full w-full items-center justify-center rounded-lg p-3 text-muted-foreground cursor-grab active:cursor-grabbing hover:bg-accent',
        className,
      )}
      {...attributes}
      {...listeners}
      {...props}
    >
      <GripVerticalIcon className="size-4" />
    </button>
  )
}
