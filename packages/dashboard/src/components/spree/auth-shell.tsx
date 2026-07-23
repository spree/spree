import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import loginSidebarBackground from '../../assets/login_sidebar_background.png'

/**
 * Two-column layout shared by the unauthenticated auth pages (login,
 * forgot/reset password, invitation acceptance): app branding, a card slot,
 * and the "powered by" footer link on the left; brand imagery on the right
 * (hidden below the `lg` breakpoint).
 */
export function AuthShell({ children }: { children: ReactNode }) {
  const { t } = useTranslation()

  return (
    <div className="grid min-h-svh lg:grid-cols-2">
      <div className="flex flex-col gap-6 bg-muted p-6 md:p-10">
        <a href="/" className="flex items-center gap-2 self-center font-medium lg:self-start">
          <div className="flex h-6 w-6 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <GalleryVerticalEnd className="size-4" />
          </div>
          {t('admin.branding.app_name')}
        </a>
        <div className="flex flex-1 items-center justify-center">
          <div className="flex w-full max-w-sm flex-col gap-6">{children}</div>
        </div>
        <div className="text-balance text-center text-xs text-muted-foreground">
          <a
            href="https://spreecommerce.org"
            className="underline underline-offset-4 hover:text-primary"
            target="_blank"
            rel="noreferrer"
          >
            {t('admin.branding.powered_by')}
          </a>
        </div>
      </div>
      <div className="relative hidden bg-muted lg:block">
        <img
          src={loginSidebarBackground}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
      </div>
    </div>
  )
}

function GalleryVerticalEnd(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      <path d="M7 2h10" />
      <path d="M5 6h14" />
      <rect width="18" height="12" x="3" y="10" rx="2" />
    </svg>
  )
}
