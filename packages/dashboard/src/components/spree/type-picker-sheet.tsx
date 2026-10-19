import type { ResourceTypeDefinition } from '@spree/admin-sdk'
import { type TypeFamily, typeDescription, typeLabel } from '@spree/dashboard-core'
import {
  Button,
  Item,
  ItemContent,
  ItemDescription,
  ItemTitle,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/** A sheet listing a type catalog's entries; picking one hands it back to the caller. */
export function TypePickerSheet({
  family,
  types,
  title,
  description,
  emptyMessage,
  open,
  onOpenChange,
  onPicked,
}: {
  family: TypeFamily
  types: ResourceTypeDefinition[]
  title: string
  description: string
  emptyMessage?: string
  open: boolean
  onOpenChange: (open: boolean) => void
  onPicked: (type: ResourceTypeDefinition) => void
}) {
  const { t } = useTranslation()

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          <SheetDescription>{description}</SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col overflow-y-auto p-4">
          {types.length === 0 ? (
            <p className="text-sm text-muted-foreground">{emptyMessage}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {types.map((type) => {
                const typeHelp = typeDescription(family, type.type, type.description)
                return (
                  <Item
                    key={type.type}
                    variant="outline"
                    render={<button type="button" />}
                    onClick={() => onPicked(type)}
                    className="cursor-pointer text-left hover:bg-accent/50"
                  >
                    <ItemContent>
                      <ItemTitle>{typeLabel(family, type.type, type.label)}</ItemTitle>
                      {typeHelp && (
                        <ItemDescription className="text-xs">{typeHelp}</ItemDescription>
                      )}
                    </ItemContent>
                  </Item>
                )
              })}
            </div>
          )}
        </div>
        <SheetFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
