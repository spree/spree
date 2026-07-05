import * as p from '@clack/prompts'
import type { PackageManager, ScaffoldOptions } from './types.js'

interface PromptFlags {
  directory?: string
  noStorefront?: boolean
  noSampleData?: boolean
  noStart?: boolean
  packageManager?: PackageManager
}

export async function runPrompts(flags: PromptFlags): Promise<Omit<ScaffoldOptions, 'port'>> {
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

  let sampleData: boolean
  if (flags.noSampleData !== undefined) {
    sampleData = !flags.noSampleData
  } else {
    const sampleResult = await p.confirm({
      message: 'Include sample data? (products, categories, images)',
      initialValue: true,
    })

    if (p.isCancel(sampleResult)) {
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    sampleData = sampleResult
  }

  let start: boolean
  if (flags.noStart !== undefined) {
    start = !flags.noStart
  } else {
    const startResult = await p.confirm({
      message: 'Start services now? (requires Docker)',
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
    sampleData,
    start,
    packageManager: flags.packageManager ?? 'npm',
  }
}
