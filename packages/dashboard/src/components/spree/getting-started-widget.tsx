import type { Store } from '@spree/admin-sdk'
import { Subject, usePermissions, useStore } from '@spree/dashboard-core'
import {
  cn,
  Popover,
  PopoverContent,
  PopoverTrigger,
  StepIcon,
  StepProgressRing,
  useSidebar,
} from '@spree/dashboard-ui'
import { ChevronRightIcon } from '@spree/dashboard-ui/icons'
import { Link, useNavigate } from '@tanstack/react-router'
import { type ReactNode, useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { StoreAddressDialog, usePrimaryStockLocation } from './setup-tasks/store-address-task'
import { SETUP_TASK_LINKS, setupTaskCopy } from './setup-tasks/types'
import { StorefrontConnectSheet } from './storefront-connect-sheet'

// Steps the checklist finishes in place rather than on another page.
const IN_PLACE_TASKS = new Set(['setup_address', 'setup_storefront'])

// Store setup progress pinned above the account menu: one row that opens the
// steps in a popover, so the checklist never takes height from the navigation.
// Each step goes straight to where it is done — a settings page, or a dialog
// opened in place. It disappears once every task is done, or for staff who
// cannot update the store.
export function GettingStartedWidget() {
  const { t } = useTranslation()
  const { store, storeId } = useStore()
  const { permissions } = usePermissions()
  const { state, isMobile, setOpenMobile } = useSidebar()
  const [open, setOpen] = useState(false)
  const [openTask, setOpenTask] = useState<string | null>(null)
  const closeTask = useCallback(() => setOpenTask(null), [])

  const tasks = (store as Store | null)?.setup_tasks ?? []
  const done = tasks.filter((task) => task.done).length
  const current = tasks.find((task) => !task.done)?.name
  const collapsed = !isMobile && state === 'collapsed'

  if (!store || !current || collapsed || !permissions.can('update', Subject.Store)) {
    return null
  }

  // On a phone the row sits in the drawer, which a link should close. Dialogs
  // opened in place keep it open: they are mounted inside it.
  const closeDrawer = () => {
    setOpen(false)
    if (isMobile) setOpenMobile(false)
  }

  const title = t('admin.pages.getting_started.title')

  return (
    <nav aria-label={title} className="mb-1">
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger
          className="flex w-full items-center gap-2.5 rounded-lg border bg-card px-3 py-2 text-base text-muted-foreground shadow-xs hover:text-foreground data-popup-open:text-foreground"
          aria-label={`${title} ${done}/${tasks.length}`}
        >
          <StepProgressRing value={done} max={tasks.length} />
          <span className="flex-1 truncate text-start font-medium">{title}</span>
          <span className="tabular-nums">
            {done}/{tasks.length}
          </span>
          <ChevronRightIcon className="size-4 shrink-0" />
        </PopoverTrigger>
        <PopoverContent
          side={isMobile ? 'top' : 'right'}
          align="end"
          sideOffset={8}
          aria-label={title}
          className="w-72 p-0 text-base"
        >
          <p className="border-b px-3 py-2.5 font-medium">{title}</p>
          <ul className="py-1">
            {tasks.map((task) => {
              const link = Object.hasOwn(SETUP_TASK_LINKS, task.name)
                ? SETUP_TASK_LINKS[task.name]
                : undefined
              const row = (
                <>
                  <StepIcon status={task.done ? 'done' : 'todo'} />
                  <span className="truncate">{setupTaskCopy(t, task.name, 'title')}</span>
                </>
              )
              const className = cn(
                'flex w-full items-center gap-2.5 px-3 py-1.5 text-start hover:bg-accent',
                task.done ? 'text-foreground' : 'text-foreground/80',
              )

              let control: ReactNode
              if (link) {
                control = (
                  <Link to={link} params={{ storeId }} className={className} onClick={closeDrawer}>
                    {row}
                  </Link>
                )
              } else if (IN_PLACE_TASKS.has(task.name)) {
                control = (
                  <button
                    type="button"
                    onClick={() => {
                      setOpen(false)
                      setOpenTask(task.name)
                    }}
                    className={className}
                  >
                    {row}
                  </button>
                )
              } else {
                // Extension tasks bring their own card body on the Getting
                // Started page, so they open there.
                control = (
                  <Link
                    to="/$storeId/getting-started"
                    params={{ storeId }}
                    search={{ task: task.name }}
                    className={className}
                    onClick={closeDrawer}
                  >
                    {row}
                  </Link>
                )
              }

              return <li key={task.name}>{control}</li>
            })}
          </ul>
        </PopoverContent>
      </Popover>

      {openTask === 'setup_address' && <AddressStep onClose={closeTask} />}
      <StorefrontConnectSheet
        store={store as Store}
        open={openTask === 'setup_storefront'}
        onOpenChange={(open) => setOpenTask(open ? 'setup_storefront' : null)}
      />
    </nav>
  )
}

function AddressStep({ onClose }: { onClose: () => void }) {
  const { storeId } = useStore()
  const navigate = useNavigate()
  const { location, isLoading } = usePrimaryStockLocation()
  const missing = !isLoading && !location

  // Without a location to write to, the Getting Started page explains why.
  useEffect(() => {
    if (!missing) return
    navigate({
      to: '/$storeId/getting-started',
      params: { storeId },
      search: { task: 'setup_address' },
    })
    onClose()
  }, [missing, navigate, onClose, storeId])

  if (!location) return null
  return <StoreAddressDialog location={location} onClose={onClose} />
}
