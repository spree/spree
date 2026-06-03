import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

// Rebuild the dev image. Needed after Dockerfile or .ruby-version changes;
// `spree bundle add` does NOT require this — gems land in the bundle_cache
// volume which survives image rebuilds.
//
// --reset-bundle wipes the bundle_cache volume so the new image's gem
// baseline gets re-seeded. Use when you bumped .ruby-version (gems compiled
// against the old Ruby won't load against the new one).
//
// Targets docker-compose.dev.yml explicitly when present, so this works
// before `spree eject` too (eject collapses the two files into one).
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
        // `docker compose down -v` is portable (no project-name guessing) but
        // also tears down all containers. Acceptable: rebuilding the image
        // means the user is recreating containers anyway.
        await dockerCompose([...composeArgs, 'down', '-v'], ctx.projectDir, { stdio: 'ignore' })
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
