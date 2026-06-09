import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

/**
 * Register the `spree build` command on the CLI program.
 *
 * Rebuilds the dev image. Needed after Dockerfile or .ruby-version changes;
 * `spree bundle add` does NOT require this — gems land in the bundle_cache
 * volume which survives image rebuilds.
 *
 * `--reset-bundle` wipes the bundle_cache volume so the new image's gem
 * baseline gets re-seeded. Use when you bumped .ruby-version (gems compiled
 * against the old Ruby won't load against the new one).
 *
 * Targets docker-compose.dev.yml explicitly when present, so this works
 * before `spree eject` too (eject collapses the two files into one).
 *
 * @param program - The Commander CLI program to register the command on.
 */
export function registerBuildCommand(program: Command): void {
  program
    .command('build')
    .description('Rebuild the dev image (after Dockerfile / .ruby-version changes)')
    .option('--reset-bundle', 'also wipe the bundle_cache volume to re-seed gems')
    .option('--yes', 'skip confirmation prompts (for CI)')
    .action(async (flags: { resetBundle?: boolean; yes?: boolean }) => {
      const ctx = detectProject()
      const composeArgs = composeFileArgs(ctx.projectDir)

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
        // Stop containers without -v: `down -v` would also wipe postgres,
        // redis, meilisearch, and storage volumes — destroying dev data
        // and uploads. We only want to drop bundle_cache.
        await dockerCompose([...composeArgs, 'down'], ctx.projectDir, { stdio: 'ignore' })
        // Resolve the compose project name so we can target the namespaced
        // volume directly. Compose derives the project name from the dir
        // (or COMPOSE_PROJECT_NAME); `compose ls --format json` returns
        // whatever it actually uses for THIS compose file.
        const projectName = await resolveComposeProjectName(composeArgs, ctx.projectDir)
        await execa('docker', ['volume', 'rm', `${projectName}_bundle_cache`], {
          cwd: ctx.projectDir,
          stdio: 'ignore',
          reject: false, // Volume may not exist on first build — that's fine
        })
        s.stop('bundle_cache volume wiped.')
      }

      console.log(`\n${pc.bold('Rebuilding dev image...')}\n`)
      await dockerCompose([...composeArgs, 'build', 'web', 'worker'], ctx.projectDir, {
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

// Pre-eject projects have `docker-compose.dev.yml` alongside the prod compose;
// we need `-f` to build against it. Post-eject the two files are the same
// (eject overwrites docker-compose.yml with the dev one), so `-f` is harmless.
function composeFileArgs(projectDir: string): string[] {
  const devCompose = path.join(projectDir, 'docker-compose.dev.yml')
  return fs.existsSync(devCompose) ? ['-f', 'docker-compose.dev.yml'] : []
}

// Returns the compose project name (e.g. `my-spree-app` or whatever
// COMPOSE_PROJECT_NAME / dir basename resolves to). Used to target the
// `<project>_bundle_cache` named volume without guessing.
//
// Falls back to the project directory's basename if the compose ls call
// doesn't find an entry — matches Compose's own default behavior.
async function resolveComposeProjectName(
  composeArgs: string[],
  projectDir: string,
): Promise<string> {
  try {
    const { stdout } = await execa(
      'docker',
      ['compose', ...composeArgs, 'config', '--format', 'json'],
      { cwd: projectDir },
    )
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
