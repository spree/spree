import type { Store } from '@spree/admin-sdk'
import { Subject, usePermissions, useStore } from '@spree/dashboard-core'
import { cn, StepIcon, StepProgressRing, useSidebar } from '@spree/dashboard-ui'
import { ChevronDownIcon } from '@spree/dashboard-ui/icons'
import { Link, useNavigate } from '@tanstack/react-router'
import { type ReactNode, useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { StoreAddressDialog, usePrimaryStockLocation } from './setup-tasks/store-address-task'
import { SETUP_TASK_LINKS, setupTaskCopy } from './setup-tasks/types'
import { StorefrontConnectSheet } from './storefront-connect-sheet'

// Steps the checklist finishes in place rather than on another page.
const IN_PLACE_TASKS = new Set(['setup_address', 'setup_storefront'])

const MINIMIZED_KEY = 'spree-setup-checklist-minimized'

function readMinimized(): boolean {
  try {
    return window.localStorage.getItem(MINIMIZED_KEY) === '1'
  } catch {
    return false
  }
}

function writeMinimized(minimized: boolean) {
  try {
    if (minimized) window.localStorage.setItem(MINIMIZED_KEY, '1')
    else window.localStorage.removeItem(MINIMIZED_KEY)
  } catch {
    // Storage blocked: the checklist opens expanded on the next visit.
  }
}

// Store setup checklist pinned above the account menu. Each step goes straight
// to where it is done — a settings page, or a dialog opened in place. It
// replaces the old Getting Started nav entry, so it disappears the same way:
// once every task is done, or for staff who cannot update the store.
export function GettingStartedWidget() {
  const { t } = useTranslation()
  const { store, storeId } = useStore()
  const { permissions } = usePermissions()
  const { state } = useSidebar()
  const [minimized, setMinimized] = useState(readMinimized)
  const [openTask, setOpenTask] = useState<string | null>(null)
  const closeTask = useCallback(() => setOpenTask(null), [])

  const tasks = (store as Store | null)?.setup_tasks ?? []
  const done = tasks.filter((task) => task.done).length
  const current = tasks.find((task) => !task.done)?.name

  if (!store || !current || state === 'collapsed' || !permissions.can('update', Subject.Store)) {
    return null
  }

  const toggle = () => {
    setMinimized(!minimized)
    writeMinimized(!minimized)
  }

  return (
    <nav
      aria-label={t('admin.pages.getting_started.title')}
      className="mb-1 overflow-hidden rounded-xl border bg-card text-sm shadow-xs"
    >
      <button
        type="button"
        onClick={toggle}
        aria-expanded={!minimized}
        className={cn(
          'flex w-full items-center gap-2.5 px-3 py-2.5 text-muted-foreground hover:text-foreground',
          !minimized && 'border-b',
        )}
      >
        <StepProgressRing value={done} max={tasks.length} />
        <span className="flex-1 truncate text-start font-medium">
          {t('admin.pages.getting_started.title')}
        </span>
        <span className="tabular-nums">
          {done}/{tasks.length}
        </span>
        <ChevronDownIcon
          className={cn('size-4 shrink-0 transition-transform', minimized && 'rotate-180')}
        />
      </button>
      {!minimized && (
        <ul className="py-1">
          {tasks.map((task) => {
            const link = SETUP_TASK_LINKS[task.name]
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
                <Link to={link} params={{ storeId }} className={className}>
                  {row}
                </Link>
              )
            } else if (IN_PLACE_TASKS.has(task.name)) {
              control = (
                <button type="button" onClick={() => setOpenTask(task.name)} className={className}>
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
                >
                  {row}
                </Link>
              )
            }

            return <li key={task.name}>{control}</li>
          })}
        </ul>
      )}

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
