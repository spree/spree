import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerBuildCommand(program: Command): void {
  program
    .command('build')
    .description('Rebuild the dev image (after Dockerfile / .ruby-version changes)')
    .option('--reset-bundle', 'also wipe the bundle_cache volume to re-seed gems')
    .option('--yes', 'skip confirmation prompts (for CI)')
    .action(async (flags: { resetBundle?: boolean; yes?: boolean }) => {
      const ctx = detectProject()
      // Always build against the active docker-compose.yml — the same file
      // `spree dev` runs. After `spree eject` that contains a `build:` section
      // pointing at ./backend; before eject, it's a prebuilt-image stack and
      // there's nothing to rebuild.
      if (!hasBuildSection(ctx.projectDir)) {
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
    })
}

function hasBuildSection(projectDir: string): boolean {
  const composeFile = path.join(projectDir, 'docker-compose.yml')
  if (!fs.existsSync(composeFile)) return false
  // Cheap YAML probe — looks for `build:` at the start of a line (the only
  // valid YAML position for a service-level build directive).
  return /^\s*build\s*:/m.test(fs.readFileSync(composeFile, 'utf-8'))
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
