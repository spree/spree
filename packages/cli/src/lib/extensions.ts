import fs from 'node:fs'
import path from 'node:path'
import catalog from '../extensions.json' with { type: 'json' }

/**
 * One installable extension: a Rails gem, a dashboard plugin, or both. Catalog
 * entries and `spree add --gem … --npm …` both resolve to this shape, so the
 * install steps never care where an extension was named.
 */
export interface Extension {
  /** Human name used in prompts and messages. */
  label: string
  gem?: string
  /** `spree` — released with Spree, so pinned to the project's Spree version. */
  release?: 'spree'
  /** npm package of the Admin Dashboard plugin. */
  dashboard?: string
  /** npm package of the Seller Panel plugin. */
  sellerDashboard?: string
}

interface CatalogEntry extends Extension {
  gem: string
  aliases?: string[]
}

export const EXTENSIONS: Record<string, CatalogEntry> = catalog.extensions as Record<
  string,
  CatalogEntry
>

// RubyGems and npm naming rules, narrowed to what can never be read as a
// command-line flag or a path.
const GEM_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/
const NPM_NAME = /^(@[a-z0-9][a-z0-9._-]*\/)?[a-z0-9][a-z0-9._-]*$/

export function isValidGemName(name: string): boolean {
  return GEM_NAME.test(name)
}

export function isValidNpmName(name: string): boolean {
  return NPM_NAME.test(name)
}

/**
 * The catalog entry a user-typed name refers to: its key, one of its aliases,
 * or its full gem name. Never guesses — an unknown name is `undefined`, never
 * `spree_<name>`, so a typo cannot install a stranger's gem.
 */
export function resolveExtension(name: string): CatalogEntry | undefined {
  return findExtension(name)?.[1]
}

function findExtension(name: string): [string, CatalogEntry] | undefined {
  const wanted = name.trim().toLowerCase().replaceAll('-', '_')
  return Object.entries(EXTENSIONS).find(
    ([key, entry]) => key === wanted || entry.gem === wanted || entry.aliases?.includes(wanted),
  )
}

/** The `spree add` command for a name: its catalog name, or `--gem` for one outside the catalog. */
export function addCommandFor(name: string): string {
  const found = findExtension(name)
  return found ? `spree add ${shortestName(...found)}` : `spree add --gem ${name}`
}

/** The shortest name of every catalog entry (`paypal`, not `paypal_checkout`), for help and errors. */
export function extensionNames(): string[] {
  return Object.entries(EXTENSIONS).map(([key, entry]) => shortestName(key, entry))
}

function shortestName(key: string, entry: CatalogEntry): string {
  return entry.aliases?.[0] ?? key
}

/** Whether the Gemfile already declares the gem (commented-out lines don't count). */
export function gemfileDeclares(gemfile: string, gem: string): boolean {
  const escaped = gem.replaceAll('.', '\\.')
  return new RegExp(`^\\s*gem\\s+['"]${escaped}['"]`, 'm').test(gemfile)
}

/** Whether Bundler resolved the gem, according to a `Gemfile.lock`. */
export function lockfileIncludes(lockfile: string, gem: string): boolean {
  return lockfile.split('\n').some((line) => line.startsWith(`    ${gem} (`))
}

/** The Spree version Bundler resolved, read from `Gemfile.lock`. */
export function lockedSpreeVersion(lockfile: string): string | undefined {
  return lockfile.match(/^ {4}spree_core \(([^)]+)\)\r?$/m)?.[1]
}

// Where `bundle add` and install generators write. Copied migrations are left
// alone: once one has run, deleting its file would make the next attempt run
// it again, while keeping it lets `spree:install:migrations` skip it.
const INSTALL_TARGETS = ['Gemfile', 'Gemfile.lock', 'config']

/**
 * Snapshot of everything an install writes to, taken before `bundle add` so a
 * failed install can put the app back as it was: changed files are rewritten
 * and files the install created are deleted.
 */
export function snapshotInstallFiles(apiPath: string): () => void {
  const currentFiles = () =>
    INSTALL_TARGETS.flatMap((target) => listFiles(path.join(apiPath, target)))
  const before = new Map(currentFiles().map((file) => [file, fs.readFileSync(file)]))
  return () => {
    for (const file of currentFiles()) {
      const content = before.get(file)
      if (!content) fs.rmSync(file)
      else if (!content.equals(fs.readFileSync(file))) fs.writeFileSync(file, content)
    }
    // A file the install deleted outright is missing from currentFiles().
    for (const [file, content] of before) {
      if (fs.existsSync(file)) continue
      fs.mkdirSync(path.dirname(file), { recursive: true })
      fs.writeFileSync(file, content)
    }
  }
}

function listFiles(target: string): string[] {
  if (!fs.existsSync(target)) return []
  if (!fs.statSync(target).isDirectory()) return [target]
  return fs
    .readdirSync(target, { withFileTypes: true })
    .flatMap((entry) =>
      entry.isDirectory()
        ? listFiles(path.join(target, entry.name))
        : entry.isFile()
          ? [path.join(target, entry.name)]
          : [],
    )
}
