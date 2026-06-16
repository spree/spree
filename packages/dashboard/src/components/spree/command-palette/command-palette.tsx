import {
  type NavEntry,
  type Permissions,
  type SearchGroup,
  type SettingsNavEntry,
  useAuth,
  useCommandPalette,
  useGlobalSearch,
  useNavEntries,
  usePermissions,
  useSettingsNav,
  useTranslation,
} from '@spree/dashboard-core'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@spree/dashboard-ui'
import { useNavigate, useParams } from '@tanstack/react-router'
import { Loader2Icon, LogOutIcon, type LucideIcon, PackageIcon, SettingsIcon } from 'lucide-react'
import { type ReactNode, useMemo, useState } from 'react'

export function CommandPalette() {
  const { open, setOpen } = useCommandPalette()
  // Skip the entire subtree (and its hooks) while the palette is closed —
  // it's mounted at the layout root and otherwise re-renders on every nav.
  if (!open) return null

  return <CommandPaletteContent setOpen={setOpen} />
}

function CommandPaletteContent({ setOpen }: { setOpen: (open: boolean) => void }) {
  const { t } = useTranslation()
  const { storeId: rawStoreId } = useParams({ strict: false }) as { storeId?: string }
  const storeId = rawStoreId ?? 'default'
  const navigate = useNavigate()
  const { logout } = useAuth()
  const { permissions } = usePermissions()
  const { main, bottom } = useNavEntries()
  const settingsNav = useSettingsNav()

  const [input, setInput] = useState('')
  const { groups, hasResults, isLoading, isEnabled } = useGlobalSearch(input)

  const close = () => {
    setOpen(false)
    setInput('')
  }

  // Flatten every nav + settings entry the user can reach into one searchable
  // list so the palette stays in lockstep with the sidebars — no hardcoded
  // subset to drift out of date. Permission filtering mirrors app-sidebar.tsx
  // and settings-sidebar.tsx. Recomputed only when the registries, permissions,
  // store, or translations change — not on every keystroke.
  const gotoCommands = useMemo(
    () => buildGotoCommands({ main, bottom, settingsNav, permissions, storeId, t }),
    [main, bottom, settingsNav, permissions, storeId, t],
  )

  const q = input.trim().toLowerCase()
  const matches = (label: string) => !q || label.toLowerCase().includes(q)
  const gotoItems = gotoCommands.filter((c) =>
    matches(t('admin.components.command_palette.goto_label', { label: c.label })),
  )
  const showLogout = matches(t('admin.auth.logout'))

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!next) close()
      }}
    >
      <DialogHeader className="sr-only">
        <DialogTitle>{t('admin.components.command_palette.title')}</DialogTitle>
        <DialogDescription>{t('admin.components.command_palette.description')}</DialogDescription>
      </DialogHeader>
      <DialogContent
        className="top-1/3 translate-y-0 overflow-hidden p-0 sm:max-w-2xl"
        showCloseButton={false}
        // Don't restore focus to the trigger after navigating — the trigger is
        // gone (we navigated away) and focus would land on the first sidebar
        // link, painting it with a misleading focus ring.
        finalFocus={false}
      >
        {/* The server filters resource results via Ransack; static commands
            are pre-filtered in JS. Either way, cmdk shouldn't filter again. */}
        <Command shouldFilter={false}>
          <CommandInput
            value={input}
            onValueChange={setInput}
            placeholder={t('admin.components.command_palette.placeholder')}
          />
          <CommandList>
            <SearchStatus
              isEnabled={isEnabled}
              isLoading={isLoading}
              hasResults={hasResults}
              query={input}
            />

            {groups.map((group) => (
              <ResourceGroup
                key={group.entry.key}
                group={group}
                storeId={storeId}
                onNavigate={(to) => {
                  close()
                  navigate({ to })
                }}
              />
            ))}

            {hasResults && (gotoItems.length > 0 || showLogout) && <CommandSeparator />}

            {gotoItems.length > 0 && (
              <CommandGroup heading={t('admin.components.command_palette.goto')}>
                {gotoItems.map(({ key, label, icon: Icon, url }) => (
                  <CommandItem
                    key={key}
                    value={`goto-${key}`}
                    onSelect={() => {
                      close()
                      navigate({ to: url })
                    }}
                  >
                    <Icon />
                    {label}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {gotoItems.length > 0 && showLogout && <CommandSeparator />}

            {showLogout && (
              <CommandGroup heading={t('admin.nav.account')}>
                <CommandItem
                  value="action-logout"
                  onSelect={() => {
                    close()
                    logout()
                  }}
                >
                  <LogOutIcon />
                  {t('admin.auth.logout')}
                </CommandItem>
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface GotoCommand {
  /** Stable key — registry entry key, used as the React key + cmdk value. */
  key: string
  /** Resolved, translated label shown in the list. */
  label: string
  /** Icon — falls back to a section-appropriate default when the entry has none. */
  icon: LucideIcon
  /** Fully-built href including `/$storeId`, ready to hand to `navigate`. */
  url: string
}

/** True when the user may `read` the entry's subject (no subject ⇒ always visible). */
function canRead(subject: NavEntry['subject'], permissions: Permissions): boolean {
  return !subject || permissions.can('read', subject)
}

/**
 * Flatten the main nav (with children), the bottom nav, and every settings
 * entry into a single permission-filtered command list. Mirrors the path
 * building and permission rules used by the two sidebars so the palette can
 * reach every page they can.
 */
function buildGotoCommands({
  main,
  bottom,
  settingsNav,
  permissions,
  storeId,
  t,
}: {
  main: NavEntry[]
  bottom: NavEntry[]
  settingsNav: ReturnType<typeof useSettingsNav>
  permissions: Permissions
  storeId: string
  t: ReturnType<typeof useTranslation>['t']
}): GotoCommand[] {
  const commands: GotoCommand[] = []
  const pathFor = (path: string) => (path === '/' ? `/${storeId}` : `/${storeId}${path}`)

  // Main + bottom nav, including nested children. A parent and its children
  // are independent destinations, each gated on its own subject.
  for (const entry of [...main, ...bottom]) {
    if (canRead(entry.subject, permissions)) {
      commands.push({
        key: entry.key,
        label: entry.label,
        icon: entry.icon ?? PackageIcon,
        url: pathFor(entry.path),
      })
    }
    for (const child of entry.children ?? []) {
      if (!canRead(child.subject, permissions)) continue
      commands.push({
        key: child.key,
        label: child.label,
        // Children render no icon in the sidebar; inherit the parent's so the
        // palette row still has a glyph.
        icon: entry.icon ?? PackageIcon,
        url: pathFor(child.path),
      })
    }
  }

  // Settings pages live under `/$storeId/settings`. Labels resolve from
  // `labelKey` (built-ins) or the literal `label` (plugins).
  for (const entry of settingsNav.all) {
    if (!canRead(entry.subject, permissions)) continue
    commands.push({
      key: entry.key,
      label: settingsLabel(entry, t),
      icon: entry.icon ?? SettingsIcon,
      url: `/${storeId}/settings${entry.path}`,
    })
  }

  return commands
}

function settingsLabel(entry: SettingsNavEntry, t: ReturnType<typeof useTranslation>['t']): string {
  return entry.labelKey ? t(entry.labelKey) : (entry.label ?? entry.key)
}

/**
 * Renders one resource's search results. The heading, row contents, result key,
 * and destination all come from the registered `SearchEntry`, so the palette
 * stays agnostic to which resources are searchable.
 */
function ResourceGroup({
  group,
  storeId,
  onNavigate,
}: {
  group: SearchGroup
  storeId: string
  onNavigate: (to: string) => void
}): ReactNode {
  const { t } = useTranslation()
  const { entry, items } = group
  return (
    <CommandGroup heading={t(entry.headingKey)}>
      {items.map((item) => (
        <CommandItem
          key={`${entry.key}-${entry.getKey(item)}`}
          value={`${entry.key}-${entry.getKey(item)}`}
          onSelect={() => onNavigate(entry.getRoute(item, storeId).to)}
        >
          {entry.renderRow(item)}
        </CommandItem>
      ))}
    </CommandGroup>
  )
}

function SearchStatus({
  isEnabled,
  isLoading,
  hasResults,
  query,
}: {
  isEnabled: boolean
  isLoading: boolean
  hasResults: boolean
  query: string
}): ReactNode {
  const { t } = useTranslation()
  if (isEnabled && isLoading) {
    return (
      <div className="flex items-center justify-center gap-2 py-6 text-sm text-muted-foreground">
        <Loader2Icon className="size-4 animate-spin" />
        {t('admin.common.searching')}
      </div>
    )
  }
  if (isEnabled && !hasResults) {
    return (
      <CommandEmpty>{t('admin.components.command_palette.no_results', { query })}</CommandEmpty>
    )
  }
  if (!isEnabled && !query) {
    return <CommandEmpty>{t('admin.components.command_palette.empty_hint')}</CommandEmpty>
  }
  return null
}
