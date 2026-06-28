import type { Category } from '@spree/admin-sdk'
import { Can, Subject } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardTitle,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, SearchIcon } from 'lucide-react'
import { useDeferredValue, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CategoryList } from '@/components/spree/categories/category-list'
import { CategoryTree } from '@/components/spree/categories/category-tree'
import { ResourceTranslationsDialog } from '@/components/spree/translations/resource-translations-dialog'
import {
  useCategories,
  useCategorySearch,
  useDeleteCategory,
  useRepositionCategory,
} from '@/hooks/use-categories'

export const Route = createFileRoute('/_authenticated/$storeId/products/categories/')({
  component: CategoriesPage,
})

function CategoriesPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { data, isLoading, error } = useCategories()
  const deleteMutation = useDeleteCategory()
  const repositionMutation = useRepositionCategory()

  const [translateId, setTranslateId] = useState<string | null>(null)

  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const searching = deferredSearch.trim().length > 0
  const {
    data: searchData,
    isLoading: searchLoading,
    error: searchError,
  } = useCategorySearch(deferredSearch)
  const activeError = searching ? searchError : error

  function openCategory(category: Category) {
    navigate({
      to: '/$storeId/products/categories/$categoryId',
      params: { storeId, categoryId: category.id },
    })
  }

  async function handleDelete(category: Category) {
    if (!window.confirm(t('admin.categories.delete_confirm', { name: category.name }))) return
    await deleteMutation.mutateAsync(category.id)
  }

  function handleReorder(id: string, parentId: string | null, position: number) {
    repositionMutation.mutate({ id, new_parent_id: parentId, new_position: position })
  }

  const rowHandlers = {
    onEdit: openCategory,
    onTranslate: (c: Category) => setTranslateId(c.id),
    onDelete: handleDelete,
    deleting: deleteMutation.isPending,
  }

  return (
    <>
      <Card className="overflow-hidden rounded-xl">
        <div className="flex flex-col items-start justify-between gap-2 border-b border-border p-3 lg:flex-row lg:items-center">
          <CardTitle>{t('admin.categories.title')}</CardTitle>
          <div className="flex items-center gap-2">
            <InputGroup className="lg:w-[300px]">
              <InputGroupAddon>
                <SearchIcon className="size-4 text-muted-foreground" />
              </InputGroupAddon>
              <InputGroupInput
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('admin.categories.search_placeholder')}
              />
            </InputGroup>
            <Can I="create" a={Subject.Category}>
              <Button
                size="sm"
                className="h-[2.125rem]"
                onClick={() =>
                  navigate({ to: '/$storeId/products/categories/new', params: { storeId } })
                }
              >
                <PlusIcon className="size-4" />
                {t('admin.categories.add_cta')}
              </Button>
            </Can>
          </div>
        </div>
        <CardContent className="p-0">
          {activeError ? (
            <p className="p-6 text-destructive" role="alert">
              {t('admin.categories.load_failed')}
            </p>
          ) : searching ? (
            searchLoading ? (
              <p className="p-6 text-muted-foreground">{t('admin.common.loading')}</p>
            ) : (
              <CategoryList categories={searchData?.data ?? []} {...rowHandlers} />
            )
          ) : isLoading ? (
            <p className="p-6 text-muted-foreground">{t('admin.common.loading')}</p>
          ) : (
            <CategoryTree
              categories={data?.data ?? []}
              {...rowHandlers}
              onReorder={handleReorder}
            />
          )}
        </CardContent>
      </Card>

      {translateId && (
        <ResourceTranslationsDialog
          resourceType="category"
          resourceId={translateId}
          open
          onOpenChange={(o) => !o && setTranslateId(null)}
        />
      )}
    </>
  )
}
