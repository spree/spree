import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath, isEjectedProject } from '../context.js'
import { appServices, dockerCompose } from '../docker.js'

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
      // `down` without -v preserves the postgres/storage volumes.
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
  await dockerCompose(['build', ...(await appServices(ctx.projectDir))], ctx.projectDir, {
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
 * — exported for tests. The starter Dockerfile normalizes its own build
 * context (backend/Gemfile marks the project layout; apps/dashboard marks a
 * customized dashboard), so the plan is a plain `docker build` from the
 * project root — the ejected backend and your dashboard ship in one image
 * with zero flags, exactly what Render/Railway run from the repo. A
 * Dockerfile predating the normalization builds from backend/ as before,
 * with a warning when a dashboard would be silently left out.
 */
export function planProductionBuild(
  projectDir: string,
  tag?: string,
): {
  args: string[]
  imageTag: string
  dashboard: 'custom' | 'stock-or-none' | 'unsupported-dockerfile'
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

  const hasDashboard = fs.existsSync(path.join(projectDir, 'apps', 'dashboard', 'package.json'))

  // The layout-normalizing Dockerfile leaves a distinctive marker; without
  // it, root context would break the build (the old file expects the Rails
  // app at the context root), so fall back to the old backend/ context.
  if (!fs.readFileSync(dockerfile, 'utf-8').includes('.spree-custom-dashboard')) {
    return {
      args: ['build', backendDir, '-f', dockerfile, '-t', imageTag],
      imageTag,
      dashboard: hasDashboard ? 'unsupported-dockerfile' : 'stock-or-none',
    }
  }

  ensureRootDockerignore(projectDir)
  return {
    args: ['build', projectDir, '-f', dockerfile, '-t', imageTag],
    imageTag,
    dashboard: hasDashboard ? 'custom' : 'stock-or-none',
  }
}

/**
 * A root-context build without a .dockerignore would upload node_modules and
 * friends as build context — write the standard one when missing (projects
 * scaffolded before it existed). Never overwrites.
 */
export function ensureRootDockerignore(projectDir: string): void {
  const target = path.join(projectDir, '.dockerignore')
  if (fs.existsSync(target)) return
  fs.writeFileSync(target, ROOT_DOCKERIGNORE)
}

export const ROOT_DOCKERIGNORE = `# Build context for backend/Dockerfile (repo root): keep it to sources.
**/node_modules
**/.git
.spree
apps/storefront
apps/dashboard/dist
apps/dashboard/.tanstack
backend/log
backend/tmp
backend/storage
backend/.env*
`

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
        `dashboard support — the image will NOT include your dashboard. Update the ` +
        `Dockerfile from the spree-starter template to bake it in.`,
    )
  }

  console.log(`\n${pc.bold(`Building production image ${plan.imageTag}...`)}\n`)
  await execa('docker', plan.args, { cwd: projectDir, stdio: 'inherit' })

  p.note(
    [
      `Run it:   ${pc.cyan(`docker run --rm -p 3000:3000 ${plan.imageTag}`)}`,
      `Push it:  ${pc.cyan(`docker tag ${plan.imageTag} <registry>/<repo> && docker push <registry>/<repo>`)}`,
      plan.dashboard !== 'unsupported-dockerfile'
        ? `Dashboard: served at ${pc.bold('/dashboard')} on the same origin as the API.`
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
