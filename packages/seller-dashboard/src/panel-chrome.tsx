import { useAuth } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { StoreIcon, UsersIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * The panel's frame: a nav rail and a content column.
 *
 * Deliberately small. The admin dashboard's chrome carries a store switcher,
 * a command palette and a plugin slot system, none of which a seller managing
 * one seller needs yet.
 */
export function PanelChrome({ children }: { children: ReactNode }) {
  const { t } = useTranslation()
  const { logout } = useAuth()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  return (
    <div className="flex min-h-screen">
      <nav className="flex w-56 shrink-0 flex-col gap-1 border-border border-r p-4">
        <p className="mb-4 font-medium text-sm">{t('app.name')}</p>

        <NavLink to="/$sellerId" params={{ sellerId }} icon={<StoreIcon className="size-4" />}>
          {t('nav.profile')}
        </NavLink>
        <NavLink to="/$sellerId/team" params={{ sellerId }} icon={<UsersIcon className="size-4" />}>
          {t('nav.team')}
        </NavLink>

        <div className="mt-auto flex flex-col gap-1">
          <Button variant="ghost" size="sm" className="justify-start" asChild>
            <Link to="/">{t('seller_picker.title')}</Link>
          </Button>
          <Button variant="ghost" size="sm" className="justify-start" onClick={() => logout()}>
            {t('nav.sign_out')}
          </Button>
        </div>
      </nav>

      <main className="min-w-0 flex-1 p-8">{children}</main>
    </div>
  )
}

/**
 * A rail entry that highlights itself when its route is the active one.
 *
 * `activeProps` is TanStack's own active-state channel, so the highlight
 * follows the router rather than a copy of the current page held in state.
 */
function NavLink({
  to,
  params,
  icon,
  children,
}: {
  to: string
  params: Record<string, string>
  icon: ReactNode
  children: ReactNode
}) {
  return (
    <Button variant="ghost" className="justify-start" asChild>
      <Link
        to={to}
        params={params}
        activeOptions={{ exact: true }}
        activeProps={{ 'data-active': 'true', className: 'bg-accent text-accent-foreground' }}
      >
        {icon}
        {children}
      </Link>
    </Button>
  )
}
