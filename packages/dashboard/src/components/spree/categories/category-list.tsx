import type { Category } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  RowActions,
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { TagIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

interface CategoryListProps {
  categories: Category[]
  onEdit: (category: Category) => void
  onTranslate: (category: Category) => void
  onDelete: (category: Category) => void
  deleting?: boolean
}

/**
 * Flat list of categories — the search-mode counterpart to the tree. A filtered
 * result isn't a tree, so matches render as a flat table showing each category's
 * full path (`pretty_name`) with no drag/reorder.
 */
export function CategoryList({
  categories,
  onEdit,
  onTranslate,
  onDelete,
  deleting,
}: CategoryListProps) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('admin.categories.columns.name')}</TableHead>
          <TableHead className="w-28 text-right">
            {t('admin.categories.columns.products')}
          </TableHead>
          <TableHead className="w-12" />
        </TableRow>
      </TableHeader>
      <TableBody className="border-t border-border">
        {categories.length === 0 ? (
          <TableEmpty colSpan={3}>{t('admin.categories.no_results')}</TableEmpty>
        ) : (
          categories.map((category) => (
            <TableRow key={category.id}>
              <TableCell>
                <div className="flex items-center gap-2">
                  <TagIcon className="size-4 shrink-0 text-blue-400" />
                  <button
                    type="button"
                    className="truncate text-left hover:underline"
                    onClick={() => onEdit(category)}
                  >
                    {category.pretty_name ?? category.name}
                  </button>
                </div>
              </TableCell>
              <TableCell className="w-28 text-right text-muted-foreground tabular-nums">
                {t('admin.categories.products_count', { count: category.products_count })}
              </TableCell>
              <TableCell className="w-12 text-right">
                <RowActions
                  actions={[
                    { key: 'edit', onSelect: () => onEdit(category) },
                    {
                      key: 'translate',
                      label: t('admin.translations.manage'),
                      icon: null,
                      onSelect: () => onTranslate(category),
                    },
                    {
                      key: 'delete',
                      destructive: true,
                      visible: permissions.can('destroy', Subject.Category),
                      disabled: deleting,
                      onSelect: () => onDelete(category),
                    },
                  ]}
                />
              </TableCell>
            </TableRow>
          ))
        )}
      </TableBody>
    </Table>
  )
}
