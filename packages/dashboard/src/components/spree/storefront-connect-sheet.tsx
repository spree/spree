import type { Store } from '@spree/admin-sdk'
import {
  Button,
  CopyToClipboardButton,
  Input,
  Label,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { ExternalLinkIcon, EyeIcon, EyeOffIcon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useStorefrontPublishableKey } from '../../hooks/use-api-keys'
import { useConnectStorefront } from '../../hooks/use-store-settings'

const STOREFRONT_REPOSITORY_URL = 'https://github.com/spree/storefront'
const STOREFRONT_DEMO_URL = 'https://demo.spreecommerce.org'
const STOREFRONT_DOCS_URL = 'https://spreecommerce.org/docs/developer/storefront/nextjs/quickstart'

function ExternalLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 text-primary text-sm hover:underline"
    >
      {children}
      <ExternalLinkIcon className="size-3.5" />
    </a>
  )
}

// Mirrors Spree::Admin::StorefrontHelper#vercel_deploy_url: clone the official
// Next.js storefront with the store's credentials prefilled, and come back to
// the Getting Started page after a successful deploy.
function vercelDeployUrl(store: Store, token: string, envDescription: string): string {
  const params = new URLSearchParams({
    'repository-url': STOREFRONT_REPOSITORY_URL,
    'project-name': `${store.code}-storefront`,
    'repository-name': `${store.code}-storefront`,
    env: 'SPREE_API_URL,SPREE_PUBLISHABLE_KEY',
    envDefaults: JSON.stringify({
      SPREE_API_URL: store.api_url,
      SPREE_PUBLISHABLE_KEY: token,
    }),
    envDescription,
    envLink: `${STOREFRONT_REPOSITORY_URL}#readme`,
    'redirect-url': window.location.origin + window.location.pathname,
  })
  return `https://vercel.com/new/clone?${params.toString()}`
}

// Normalize user or Vercel-callback input (possibly a bare host like
// my-shop.vercel.app) to an origin string, mirroring the backend's
// normalize_origin. Returns null when it's not a valid http(s) URL.
export function normalizeOrigin(raw: string): string | null {
  const trimmed = raw.trim()
  if (!trimmed) return null

  const candidate = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`
  try {
    return new URL(candidate).origin
  } catch {
    return null
  }
}

function VercelMark() {
  return (
    <svg viewBox="0 0 76 65" className="size-3.5 fill-current" aria-hidden="true">
      <path d="M37.59.25l36.95 64H.64l36.95-64z" />
    </svg>
  )
}

interface StorefrontConnectSheetProps {
  /** The current store — the caller guards loading, so this is always present. */
  store: Store
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Prefill for the storefront URL field — e.g. the Vercel callback's deployment-url. */
  initialUrl?: string
}

export function StorefrontConnectSheet({
  store,
  open,
  onOpenChange,
  initialUrl,
}: StorefrontConnectSheetProps) {
  const { t } = useTranslation()
  const [url, setUrl] = useState(() => initialUrl ?? store.preferred_storefront_url ?? '')
  const [showKey, setShowKey] = useState(false)

  const {
    data: publishableKey,
    isLoading: keyLoading,
    isError: keyError,
    refetch: refetchKey,
  } = useStorefrontPublishableKey({ enabled: open })
  const token = publishableKey?.plaintext_token ?? ''

  const connect = useConnectStorefront()

  const handleSave = () => {
    const origin = normalizeOrigin(url)
    if (!origin) {
      toast.error(t('admin.pages.getting_started.storefront_sheet.invalid_url'))
      return
    }

    connect.mutate(origin, {
      onSuccess: () => {
        toast.success(t('admin.pages.getting_started.storefront_sheet.saved', { url: origin }))
        onOpenChange(false)
      },
      onError: (error) => {
        toast.error(error instanceof Error ? error.message : String(error))
      },
    })
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="flex w-full flex-col gap-6 overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{t('admin.pages.getting_started.storefront_sheet.title')}</SheetTitle>
          <SheetDescription>
            {t('admin.pages.getting_started.storefront_sheet.description')}
          </SheetDescription>
        </SheetHeader>

        <div className="flex flex-col gap-6 px-4">
          <div className="flex flex-col gap-2">
            <Label>{t('admin.pages.getting_started.storefront_sheet.api_url_label')}</Label>
            <div className="flex items-center gap-1">
              <Input readOnly value={store.api_url} spellCheck={false} />
              <CopyToClipboardButton
                value={store.api_url}
                aria-label={t('admin.actions.copy')}
                variant="ghost"
                size="icon"
              />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <Label>{t('admin.pages.getting_started.storefront_sheet.publishable_key_label')}</Label>
            {keyLoading ? (
              <Skeleton className="h-9" />
            ) : keyError ? (
              <div className="flex items-center gap-3">
                <p className="text-destructive text-sm">
                  {t('admin.pages.getting_started.storefront_sheet.key_error')}
                </p>
                <Button type="button" variant="outline" size="sm" onClick={() => refetchKey()}>
                  {t('admin.components.error_state.retry')}
                </Button>
              </div>
            ) : (
              <div className="flex items-center gap-1">
                <Input
                  readOnly
                  type={showKey ? 'text' : 'password'}
                  value={token}
                  spellCheck={false}
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  aria-label={showKey ? t('admin.actions.hide') : t('admin.actions.show')}
                  onClick={() => setShowKey((visible) => !visible)}
                >
                  {showKey ? <EyeOffIcon className="size-4" /> : <EyeIcon className="size-4" />}
                </Button>
                <CopyToClipboardButton
                  value={token}
                  aria-label={t('admin.actions.copy')}
                  variant="ghost"
                  size="icon"
                />
              </div>
            )}
          </div>

          <div className="flex flex-col gap-2 rounded-lg border p-4">
            <p className="font-medium text-sm">
              {t('admin.pages.getting_started.storefront_sheet.deploy_title')}
            </p>
            <p className="text-muted-foreground text-sm">
              {t('admin.pages.getting_started.storefront_sheet.deploy_copy')}
            </p>
            <div>
              {/* Vercel's brand deploy button: black with the triangle mark
                  (inverted in dark mode), matching vercel.com/button. */}
              <Button
                asChild
                disabled={!token}
                className="bg-black text-white hover:bg-black/85 dark:bg-white dark:text-black dark:hover:bg-white/85"
              >
                <a
                  href={
                    token
                      ? vercelDeployUrl(
                          store,
                          token,
                          t('admin.pages.getting_started.storefront_sheet.env_description'),
                        )
                      : undefined
                  }
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <VercelMark />
                  {t('admin.pages.getting_started.storefront_sheet.deploy_button')}
                </a>
              </Button>
            </div>
            <div className="mt-1 flex items-center gap-4">
              <ExternalLink href={STOREFRONT_DEMO_URL}>
                {t('admin.pages.getting_started.storefront_sheet.see_online_demo')}
              </ExternalLink>
              <ExternalLink href={STOREFRONT_DOCS_URL}>
                {t('admin.pages.getting_started.storefront_sheet.local_installation_instructions')}
              </ExternalLink>
            </div>
          </div>

          <form
            className="flex flex-col gap-3"
            onSubmit={(event) => {
              event.preventDefault()
              handleSave()
            }}
          >
            <div className="flex flex-col gap-2">
              <Label htmlFor="storefront-url">
                {t('admin.pages.getting_started.storefront_sheet.storefront_url_label')}
              </Label>
              <Input
                id="storefront-url"
                value={url}
                onChange={(event) => setUrl(event.target.value)}
                placeholder={t(
                  'admin.pages.getting_started.storefront_sheet.storefront_url_placeholder',
                )}
                spellCheck={false}
              />
              <p className="text-muted-foreground text-sm">
                {t('admin.pages.getting_started.storefront_sheet.storefront_url_help')}
              </p>
            </div>
            <div>
              <Button type="submit" disabled={!url.trim() || connect.isPending}>
                {t('admin.pages.getting_started.storefront_sheet.save')}
              </Button>
            </div>
          </form>
        </div>
      </SheetContent>
    </Sheet>
  )
}
