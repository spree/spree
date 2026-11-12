import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import { execa } from 'execa'
import pc from 'picocolors'
import {
  addPackageCommand,
  extensionInstallGenerator,
  LIST_GENERATORS,
  MIGRATE,
  runGeneratorCommand,
} from '../backend.js'
import { findApiDir, isEjectedProject } from '../context.js'
import { dockerComposeCapture, dockerComposeExecOrRun, restartAppServices } from '../docker.js'
import {
  type Extension,
  gemfileDeclares,
  lockedSpreeVersion,
  lockfileIncludes,
  snapshotInstallFiles,
} from '../lib/extensions.js'
import { confirmOrExit } from '../lib/prompt.js'
import type { ProjectContext } from '../types.js'
import { detectPackageManager } from './add.js'
import { ejectProject } from './eject.js'

export interface AddExtensionOptions {
  /** Agree to every confirmation: ejecting, and installing outside the catalog. */
  yes: boolean
}

// `dir` is both the folder under apps/ and the `spree add` name that creates it.
const PLUGIN_TARGETS = [
  { field: 'dashboard', dir: 'dashboard' },
  { field: 'sellerDashboard', dir: 'seller-dashboard' },
] as const

/**
 * Install an extension end to end: eject a project still on the prebuilt
 * image, add the gem, run its install generator when it has one, migrate,
 * install its dashboard plugins, and restart a running server.
 *
 * Safe to re-run. A gem the Gemfile already lists is not added again; on an
 * ejected project its generator (keeping files that exist) and migrations run
 * again to repair a half-finished install. If a step after `bundle add`
 * fails, the Gemfile, its lock and `config/` are put back as they were.
 */
export async function addExtension(
  ctx: ProjectContext,
  extension: Extension,
  opts: AddExtensionOptions,
): Promise<void> {
  const gemChanged = extension.gem ? await installGem(ctx, extension.gem, extension, opts) : false
  const pluginsAdded = await installPlugins(ctx, extension)

  if (gemChanged)
    await restartAppServices(ctx.projectDir, 'Restarting the server to load the new gem')
  if (pluginsAdded) {
    p.log.info(`Restart ${pc.bold('spree dev')} so the dashboard picks up the new plugin.`)
  }
}

/** @return whether the gem was installed or repaired, so the server needs a restart */
async function installGem(
  ctx: ProjectContext,
  gem: string,
  extension: Extension,
  opts: AddExtensionOptions,
): Promise<boolean> {
  const apiDir = findApiDir(ctx.projectDir)
  const apiPath = path.join(ctx.projectDir, apiDir)
  const gemfilePath = path.join(apiPath, 'Gemfile')
  if (!fs.existsSync(gemfilePath)) {
    p.cancel(`No ${apiDir}/Gemfile found.`)
    process.exit(1)
  }

  if (!isEjectedProject(ctx.projectDir)) {
    // What the prebuilt image runs is its own Gemfile.lock, not the one on
    // disk, which may list gems added by hand since.
    const imageLockfile = await dockerComposeCapture(['cat', 'Gemfile.lock'], ctx.projectDir)
    if (lockfileIncludes(imageLockfile, gem)) {
      p.log.info(`${pc.bold(gem)} is already part of this project. Nothing to install.`)
      return false
    }

    await confirmOrExit(
      [
        `This project runs the prebuilt Spree image, which cannot load new gems.`,
        `Installing ${extension.label} ejects it first: the Rails app is then built from`,
        `./${apiDir}, with a new development database that does not have your current data.`,
        'Eject now?',
      ].join('\n'),
      opts.yes,
    )
    try {
      await ejectProject(ctx.projectDir)
    } catch (error) {
      p.cancel(
        `Ejecting failed, so ${extension.label} was not installed. Fix the problem above, run ${pc.bold('spree eject')}, then run this command again. ${error instanceof Error ? error.message : String(error)}`,
      )
      process.exit(1)
    }
  }

  const listed = gemfileDeclares(fs.readFileSync(gemfilePath, 'utf-8'), gem)
  // A repair adds nothing, so there is nothing to roll back.
  const restore = listed ? undefined : snapshotInstallFiles(apiPath)
  try {
    if (!listed) await bundleAdd(ctx.projectDir, apiPath, gem, extension.release)
    await runInstallGenerator(ctx.projectDir, gem, listed)
    p.log.step('Running migrations...')
    await dockerComposeExecOrRun(MIGRATE, ctx.projectDir)
  } catch (error) {
    if (restore) {
      restore()
      p.log.warn(
        `Put ${apiDir}/Gemfile, Gemfile.lock and config/ back as they were. Copied migrations were kept so running this command again picks up where it stopped; check ${pc.bold('git status')} for anything else the installer wrote.`,
      )
    }
    p.cancel(
      `Could not install ${extension.label}. ${error instanceof Error ? error.message : String(error)}`,
    )
    process.exit(1)
  }

  p.log.success(
    listed
      ? `${pc.bold(gem)} was already in the Gemfile; ran its installer and migrations again.`
      : `${pc.bold(gem)} installed.`,
  )
  return true
}

async function bundleAdd(
  projectDir: string,
  apiPath: string,
  gem: string,
  release: Extension['release'],
): Promise<void> {
  const args = addPackageCommand(gem)
  // Unpinned, Bundler picks the newest stable release, which for a gem that
  // moved into Spree is its old pre-6.0 line.
  if (release === 'spree') {
    const lockfile = path.join(apiPath, 'Gemfile.lock')
    const version = fs.existsSync(lockfile)
      ? lockedSpreeVersion(fs.readFileSync(lockfile, 'utf-8'))
      : undefined
    if (!version) throw new Error("Could not read the project's Spree version from Gemfile.lock.")
    args.push('--version', `>= ${version}`)
  }
  p.log.step(`Adding ${pc.bold(gem)}...`)
  await dockerComposeExecOrRun(args, projectDir)
}

// An install generator is optional — many gems register themselves from their
// engine and have nothing to copy into the app.
async function runInstallGenerator(
  projectDir: string,
  gem: string,
  keepExisting: boolean,
): Promise<void> {
  const generator = extensionInstallGenerator(gem)
  const help = await dockerComposeCapture(LIST_GENERATORS, projectDir)
  const listed = help.split('\n').some((line) => line.trim() === generator)
  if (!listed) return

  p.log.step(`Running ${pc.bold(generator)}...`)
  // On a repair, files the first run wrote (and the developer may have
  // edited) are kept rather than stopping at Thor's overwrite prompt.
  const args = runGeneratorCommand(generator, keepExisting ? ['--skip'] : [])
  await dockerComposeExecOrRun(args, projectDir)
}

/** @return whether any plugin was installed */
async function installPlugins(ctx: ProjectContext, extension: Extension): Promise<boolean> {
  let installed = false
  for (const target of PLUGIN_TARGETS) {
    const pkg = extension[target.field]
    if (!pkg) continue

    const appDir = path.join(ctx.projectDir, 'apps', target.dir)
    if (!fs.existsSync(path.join(appDir, 'package.json'))) {
      p.log.warn(
        `Skipped ${pc.bold(pkg)}: this project has no apps/${target.dir}/. Add it with ${pc.bold(`spree add ${target.dir}`)}, then run this command again.`,
      )
      continue
    }

    const pm = detectPackageManager(ctx.projectDir, appDir)
    p.log.step(`Adding ${pc.bold(pkg)} to apps/${target.dir}/...`)
    try {
      await execa(pm, [pm === 'npm' ? 'install' : 'add', pkg], { cwd: appDir, stdio: 'inherit' })
      installed = true
    } catch (error) {
      p.log.warn(
        `Could not add ${pkg}; add it by hand in apps/${target.dir}/. ${error instanceof Error ? error.message : String(error)}`,
      )
    }
  }
  return installed
}
