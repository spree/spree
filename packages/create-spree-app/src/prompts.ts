import * as p from '@clack/prompts'
import type { PackageManager, ScaffoldOptions } from './types.js'

interface PromptFlags {
  directory?: string
  noStorefront?: boolean
  reactDashboard?: boolean
  noStart?: boolean
  packageManager?: PackageManager
}

export async function runPrompts(
  flags: PromptFlags,
): Promise<Omit<ScaffoldOptions, 'port' | 'mailpitSmtpPort' | 'mailpitUiPort'>> {
  const directory =
    flags.directory ??
    ((await p.text({
      message: 'Where would you like to create your project?',
      placeholder: './my-store',
      defaultValue: './my-store',
      validate(value): string | undefined {
        if (!value) return 'Please enter a directory'
        return undefined
      },
    })) as string)

  if (p.isCancel(directory)) {
    p.cancel('Setup cancelled.')
    process.exit(0)
  }

  let storefront: boolean
  if (flags.noStorefront !== undefined) {
    storefront = !flags.noStorefront
  } else {
    const storefrontResult = await p.confirm({
      message: 'Include Next.js storefront?',
      initialValue: true,
    })

    if (p.isCancel(storefrontResult)) {
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    storefront = storefrontResult
  }

  // Always scaffolded, never prompted: from Spree 6 the React Dashboard IS
  // the admin (the Rails admin engine is gone), so a project without one has
  // no back office at all. The marketplace Seller Panel ships alongside it so
  // the pair stays consistent with what the starter's Docker image bakes.
  const dashboard = true

  let start: boolean
  if (flags.noStart !== undefined) {
    start = !flags.noStart
  } else {
    const startResult = await p.confirm({
      message: 'Start services now? Requires Docker - will start Spree server and PostgreSQL',
      initialValue: true,
    })

    if (p.isCancel(startResult)) {
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    start = startResult
  }

  return {
    directory,
    storefront,
    dashboard,
    start,
    packageManager: flags.packageManager ?? 'npm',
  }
}
