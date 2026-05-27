import { CopyIcon, EllipsisVerticalIcon, PencilIcon, Trash2Icon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export interface RowAction {
  /** Stable key for React reconciliation. Doubles as the i18n action slug
   *  (`'edit' | 'clone' | 'delete' | …`) when `label` is omitted: the helper
   *  looks up `admin.row_actions.<key>` for built-ins, so callers don't have
   *  to repeat the translation key. */
  key: string
  /** Override the auto-resolved label for custom (non-built-in) actions. */
  label?: string
  /** Override the default icon — required for actions other than the
   *  three built-ins (edit/clone/delete). */
  icon?: ReactNode
  /** Skips rendering when false. Use for CanCanCan gates. */
  visible?: boolean
  /** Greys out the item without removing it (in-flight mutations). */
  disabled?: boolean
  /** Styles the item red — use for destructive actions. */
  destructive?: boolean
  onSelect: () => void
}

interface RowActionsProps {
  /** Items in render order. Items with `visible: false` are filtered out. */
  actions: RowAction[]
}

const BUILTIN_ICONS: Record<string, ReactNode> = {
  edit: <PencilIcon className="size-4" />,
  clone: <CopyIcon className="size-4" />,
  delete: <Trash2Icon className="size-4" />,
}

/**
 * Kebab dropdown shared by every `<ResourceTable rowActions={…}>` consumer
 * (products, customers, payment methods, …). Keeps the icon, alignment, and
 * a11y label consistent across the SPA.
 *
 * Built-in keys (`edit`, `clone`, `delete`) auto-resolve their label via
 * `admin.row_actions.<key>` and pick up the matching icon, so the typical
 * call site is:
 *
 *     <RowActions actions={[
 *       { key: 'edit', onSelect: openEdit },
 *       { key: 'delete', destructive: true, onSelect: openConfirm },
 *     ]} />
 */
export function RowActions({ actions }: RowActionsProps) {
  const { t } = useTranslation()
  const visible = actions.filter((a) => a.visible !== false)
  if (visible.length === 0) return null

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-xs" aria-label={t('admin.row_actions.menu_label')}>
          <EllipsisVerticalIcon className="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {visible.map((action) => (
          <DropdownMenuItem
            key={action.key}
            onClick={action.onSelect}
            disabled={action.disabled}
            className={action.destructive ? 'text-destructive focus:text-destructive' : undefined}
          >
            {action.icon ?? BUILTIN_ICONS[action.key]}
            {action.label ?? t(`admin.row_actions.${action.key}`)}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
