import type { ApiKey, Store } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useStore } from '@spree/dashboard-core'
import {
  Button,
  Input,
  Label,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckIcon, CopyIcon, ExternalLinkIcon, EyeIcon, EyeOffIcon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

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

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false)

  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      onClick={async () => {
        await navigator.clipboard.writeText(value)
        setCopied(true)
        setTimeout(() => setCopied(false), 1500)
      }}
    >
      {copied ? <CheckIcon className="size-4 text-green-600" /> : <CopyIcon className="size-4" />}
    </Button>
  )
}

interface StorefrontConnectSheetProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Prefill for the storefront URL field — e.g. the Vercel callback's deployment-url. */
  initialUrl?: string
}

export function StorefrontConnectSheet({
  open,
  onOpenChange,
  initialUrl,
}: StorefrontConnectSheetProps) {
  const { t } = useTranslation()
  const { store, refetch } = useStore()
  const queryClient = useQueryClient()
  const [url, setUrl] = useState(() => initialUrl ?? store?.preferred_storefront_url ?? '')
  const [showKey, setShowKey] = useState(false)

  const keysQueryKey = useResourceKey('storefront-publishable-key')
  const { data: publishableKey, isLoading: keyLoading } = useQuery({
    queryKey: keysQueryKey,
    enabled: open,
    queryFn: async () => {
      // Reuse the oldest active publishable key; mint one for stores that have
      // none — same behavior as the legacy admin storefront page.
      const { data: keys } = await adminClient.apiKeys.list({ per_page: 100 })
      const existing = keys.find((key: ApiKey) => key.key_type === 'publishable' && !key.revoked_at)
      if (existing) return existing

      return adminClient.apiKeys.create({ name: 'Storefront', key_type: 'publishable' })
    },
  })

  const token = publishableKey?.plaintext_token ?? ''

  const saveUrl = useMutation({
    mutationFn: async (rawUrl: string) => {
      const origin = normalizeOrigin(rawUrl)
      if (!origin) throw new Error(t('admin.getting_started.storefront_sheet.invalid_url'))

      await adminClient.store.update({ preferred_storefront_url: origin })
      try {
        // Best-effort: the origin may already be allowed (duplicate), which
        // must not fail the save — the URL preference is what completes setup.
        await adminClient.allowedOrigins.create({ origin })
      } catch {
        // already allowed or rejected as duplicate
      }
      return origin
    },
    onSuccess: async (origin) => {
      await refetch()
      await queryClient.invalidateQueries({ queryKey: keysQueryKey })
      toast.success(t('admin.getting_started.storefront_sheet.saved', { url: origin }))
      onOpenChange(false)
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : String(error))
    },
  })

  if (!store) return null

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="flex w-full flex-col gap-6 overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{t('admin.getting_started.storefront_sheet.title')}</SheetTitle>
          <SheetDescription>
            {t('admin.getting_started.storefront_sheet.description')}
          </SheetDescription>
        </SheetHeader>

        <div className="flex flex-col gap-6 px-4">
          <div className="flex flex-col gap-2">
            <Label>{t('admin.getting_started.storefront_sheet.api_url_label')}</Label>
            <div className="flex items-center gap-1">
              <Input readOnly value={store.api_url} spellCheck={false} />
              <CopyButton value={store.api_url} />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <Label>{t('admin.getting_started.storefront_sheet.publishable_key_label')}</Label>
            {keyLoading ? (
              <Skeleton className="h-9" />
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
                  onClick={() => setShowKey((visible) => !visible)}
                >
                  {showKey ? <EyeOffIcon className="size-4" /> : <EyeIcon className="size-4" />}
                </Button>
                <CopyButton value={token} />
              </div>
            )}
          </div>

          <div className="flex flex-col gap-2 rounded-lg border p-4">
            <p className="font-medium text-sm">
              {t('admin.getting_started.storefront_sheet.deploy_title')}
            </p>
            <p className="text-muted-foreground text-sm">
              {t('admin.getting_started.storefront_sheet.deploy_copy')}
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
                          t('admin.getting_started.storefront_sheet.env_description'),
                        )
                      : undefined
                  }
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <VercelMark />
                  {t('admin.getting_started.storefront_sheet.deploy_button')}
                </a>
              </Button>
            </div>
            <div className="mt-1 flex items-center gap-4">
              <ExternalLink href={STOREFRONT_DEMO_URL}>
                {t('admin.getting_started.storefront_sheet.see_online_demo')}
              </ExternalLink>
              <ExternalLink href={STOREFRONT_DOCS_URL}>
                {t('admin.getting_started.storefront_sheet.local_installation_instructions')}
              </ExternalLink>
            </div>
          </div>

          <form
            className="flex flex-col gap-3"
            onSubmit={(event) => {
              event.preventDefault()
              saveUrl.mutate(url)
            }}
          >
            <div className="flex flex-col gap-2">
              <Label htmlFor="storefront-url">
                {t('admin.getting_started.storefront_sheet.storefront_url_label')}
              </Label>
              <Input
                id="storefront-url"
                value={url}
                onChange={(event) => setUrl(event.target.value)}
                placeholder="https://myshop.com"
                spellCheck={false}
              />
              <p className="text-muted-foreground text-sm">
                {t('admin.getting_started.storefront_sheet.storefront_url_help')}
              </p>
            </div>
            <div>
              <Button type="submit" disabled={!url.trim() || saveUrl.isPending}>
                {t('admin.getting_started.storefront_sheet.save')}
              </Button>
            </div>
          </form>
        </div>
      </SheetContent>
    </Sheet>
  )
}
