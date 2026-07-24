import type { ReactNode } from 'react'
import loginSidebarBackground from '../../assets/login_sidebar_background.png'

/**
 * Two-column layout shared by the unauthenticated auth pages (login,
 * forgot/reset password, invitation acceptance): app branding, a card slot,
 * and the "powered by" footer link on the left; brand imagery on the right
 * (hidden below the `lg` breakpoint).
 */
export function AuthShell({ children }: { children: ReactNode }) {
  return (
    <div className="grid min-h-svh lg:grid-cols-2">
      <div className="flex flex-col gap-6 bg-muted p-6 md:p-10">
        <div className="flex flex-1 items-center justify-center">
          <div className="flex w-full max-w-sm flex-col gap-6">{children}</div>
        </div>
      </div>
      <div className="relative hidden bg-muted lg:block border-l">
        <img
          src={loginSidebarBackground}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
      </div>
    </div>
  )
}
