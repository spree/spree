import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath, isEjectedProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerBuildCommand(program: Command): void {
  program
    .command('build')
    .description('Rebuild the dev image (after Dockerfile / .ruby-version changes)')
    .option('--reset-bundle', 'also wipe the bundle_cache volume to re-seed gems')
    .option('--yes', 'skip confirmation prompts (for CI)')
    .option(
      '--production',
      'build the production image instead — includes apps/dashboard when present',
    )
    .option('--tag <tag>', 'image tag for --production (default: <project>-spree:latest)')
    .action(
      async (flags: {
        resetBundle?: boolean
        yes?: boolean
        production?: boolean
        tag?: string
      }) => {
        if (flags.production) {
          await buildProductionImage(detectProject().projectDir, flags.tag)
          return
        }
        await buildDevImage(flags)
      },
    )
}

async function buildDevImage(flags: { resetBundle?: boolean; yes?: boolean }): Promise<void> {
  const ctx = detectProject()

  if (hasMonorepoSpreePath(ctx.projectDir)) {
    p.cancel(
      [
        'This project uses SPREE_PATH for monorepo development.',
        `Use ${pc.bold('pnpm server:build')} from the monorepo root instead of ${pc.bold('spree build')}.`,
        'It builds against the edge compose overlay the running stack was started with.',
      ].join('\n'),
    )
    process.exit(1)
  }

  // Always build against the active docker-compose.yml — the same file
  // `spree dev` runs. After `spree eject` that contains a `build:` section
  // pointing at ./backend; before eject, it's a prebuilt-image stack and
  // there's nothing to rebuild.
  if (!isEjectedProject(ctx.projectDir)) {
    console.error(
      `\n${pc.red('Error:')} docker-compose.yml has no \`build:\` section. ` +
        `Run ${pc.bold('spree eject')} first to switch to a build-from-source stack.\n`,
    )
    process.exit(1)
  }

  if (flags.resetBundle) {
    if (!flags.yes) {
      const confirmed = await p.confirm({
        message:
          'Wipe the bundle_cache volume? Any gems added via `spree bundle add` since the last image build will be lost.',
        initialValue: false,
      })
      if (p.isCancel(confirmed) || !confirmed) {
        p.cancel('Build cancelled.')
        process.exit(0)
      }
    }

    const s = p.spinner()
    s.start('Wiping bundle_cache volume...')
    try {
      // `down` without -v preserves postgres/redis/meilisearch/storage volumes.
      await dockerCompose(['down'], ctx.projectDir, { stdio: 'ignore' })
      const projectName = await resolveComposeProjectName(ctx.projectDir)
      const volumeName = `${projectName}_bundle_cache`
      // Check before removal so we can report missing-volume distinctly
      // from a real failure (wrong permissions, daemon issue).
      const exists = await volumeExists(volumeName, ctx.projectDir)
      if (exists) {
        await execa('docker', ['volume', 'rm', volumeName], {
          cwd: ctx.projectDir,
          stdio: 'ignore',
        })
        s.stop('bundle_cache volume wiped.')
      } else {
        s.stop(`bundle_cache volume not present (looked for ${volumeName}).`)
      }
    } catch (error) {
      s.stop('Failed to wipe bundle_cache volume.')
      throw error
    }
  }

  console.log(`\n${pc.bold('Rebuilding dev image...')}\n`)
  await dockerCompose(['build', 'web', 'worker'], ctx.projectDir, {
    stdio: 'inherit',
  })

  p.note(
    [
      `Image rebuilt. Start the stack with ${pc.bold('spree dev')}.`,
      flags.resetBundle
        ? `On next boot, gems will re-seed into a fresh ${pc.dim('bundle_cache')} volume.`
        : '',
    ]
      .filter(Boolean)
      .join('\n'),
    'Build complete',
  )
}

/**
 * What `spree build --production` will run, computed without touching Docker
 * — exported for tests. When the project carries a customized dashboard
 * (`apps/dashboard`) AND the backend Dockerfile supports source selection
 * (the `DASHBOARD_SOURCE` build arg from spree-starter), the plan stages a
 * filtered copy of the app (no node_modules/build output — Docker named
 * contexts don't apply .dockerignore) and selects the `custom` dashboard
 * stage. Older projects hit neither branch and build exactly what
 * `docker build backend/` would — nothing changes for them.
 */
export function planProductionBuild(
  projectDir: string,
  tag?: string,
): {
  args: string[]
  imageTag: string
  dashboard: 'custom' | 'stock-or-none' | 'unsupported-dockerfile'
  stagedDashboardDir?: string
} {
  const backendDir = path.join(projectDir, 'backend')
  const dockerfile = path.join(backendDir, 'Dockerfile')
  if (!fs.existsSync(dockerfile)) {
    throw new Error('No backend/Dockerfile found. Is this a create-spree-app project?')
  }

  const imageTag =
    tag ??
    `${path
      .basename(projectDir)
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, '')}-spree:latest`

  const args = ['build', backendDir, '-f', dockerfile, '-t', imageTag]

  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  if (!fs.existsSync(path.join(dashboardDir, 'package.json'))) {
    return { args, imageTag, dashboard: 'stock-or-none' }
  }

  if (!fs.readFileSync(dockerfile, 'utf-8').includes('DASHBOARD_SOURCE')) {
    return { args, imageTag, dashboard: 'unsupported-dockerfile' }
  }

  const staged = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-dashboard-src-'))
  fs.cpSync(dashboardDir, staged, {
    recursive: true,
    filter: (src) => {
      const base = path.basename(src)
      return base !== 'node_modules' && base !== 'dist' && base !== '.tanstack'
    },
  })
  args.push('--build-arg', 'DASHBOARD_SOURCE=custom', '--build-context', `dashboard-src=${staged}`)
  return { args, imageTag, dashboard: 'custom', stagedDashboardDir: staged }
}

/**
 * Build the production image (the Dockerfile's final stage) — the one you
 * push to a registry and run on Render/Railway/AWS/anywhere. Unlike the dev
 * flow this needs no compose file and no prior `spree eject`.
 */
async function buildProductionImage(projectDir: string, tag?: string): Promise<void> {
  let plan: ReturnType<typeof planProductionBuild>
  try {
    plan = planProductionBuild(projectDir, tag)
  } catch (err) {
    console.error(`\n${pc.red('Error:')} ${err instanceof Error ? err.message : String(err)}\n`)
    process.exit(1)
  }

  if (plan.dashboard === 'custom') {
    p.log.info(`Including your dashboard from ${pc.bold('apps/dashboard/')} (built in-image).`)
  } else if (plan.dashboard === 'unsupported-dockerfile') {
    p.log.warn(
      `${pc.bold('apps/dashboard/')} exists, but ${pc.bold('backend/Dockerfile')} predates ` +
        `dashboard support (no DASHBOARD_SOURCE build arg) — the image will NOT include your ` +
        `dashboard. Update the Dockerfile from the spree-starter template to bake it in.`,
    )
  }

  console.log(`\n${pc.bold(`Building production image ${plan.imageTag}...`)}\n`)
  try {
    await execa('docker', plan.args, { cwd: projectDir, stdio: 'inherit' })
  } finally {
    if (plan.stagedDashboardDir) {
      fs.rmSync(plan.stagedDashboardDir, { recursive: true, force: true })
    }
  }

  p.note(
    [
      `Run it:   ${pc.cyan(`docker run --rm -p 3000:3000 ${plan.imageTag}`)}`,
      `Push it:  ${pc.cyan(`docker tag ${plan.imageTag} <registry>/<repo> && docker push <registry>/<repo>`)}`,
      plan.dashboard !== 'unsupported-dockerfile'
        ? `Dashboard: served at ${pc.bold('/dashboard')} when the image includes one.`
        : '',
    ]
      .filter(Boolean)
      .join('\n'),
    'Production image built',
  )
}

async function resolveComposeProjectName(projectDir: string): Promise<string> {
  try {
    const { stdout } = await execa('docker', ['compose', 'config', '--format', 'json'], {
      cwd: projectDir,
    })
    const parsed = JSON.parse(stdout) as { name?: string }
    if (parsed.name) return parsed.name
  } catch {
    // Fall through to basename fallback.
  }
  return path
    .basename(projectDir)
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '')
}

async function volumeExists(name: string, projectDir: string): Promise<boolean> {
  try {
    await execa('docker', ['volume', 'inspect', name], {
      cwd: projectDir,
      stdio: 'ignore',
    })
    return true
  } catch {
    return false
  }
}
