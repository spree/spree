import type { Store } from '@spree/admin-sdk'
import { Subject, usePermissions, useStore } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Says so when the last Getting Started step is finished.
 *
 * The sidebar checklist disappears at that moment, so without this the
 * merchant's last save just makes it vanish. Fires only on the change from
 * unfinished to finished while the dashboard is open, never for a store that
 * loads already set up.
 */
export function useSetupCompleteToast() {
  const { t } = useTranslation()
  const { store } = useStore()
  const { permissions } = usePermissions()
  const tasks = (store as Store | null)?.setup_tasks
  const allDone = tasks ? tasks.length > 0 && tasks.every((task) => task.done) : null
  const canSetUp = permissions.can('update', Subject.Store)
  const previous = useRef<boolean | null>(null)

  useEffect(() => {
    if (allDone === null) return
    if (previous.current === false && allDone && canSetUp) {
      toastManager.add({
        type: 'success',
        title: t('admin.pages.getting_started.completed.title'),
        description: t('admin.pages.getting_started.completed.description'),
      })
    }
    previous.current = allDone
  }, [allDone, canSetUp, t])
}
