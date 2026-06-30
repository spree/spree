import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerCompose, primeBundleVolume } from '../docker.js'

export function registerUpdateCommand(program: Command): void {
  program
    .command('update')
    .description('Pull latest image and recreate containers')
    .action(async () => {
      const ctx = detectProject()

      p.log.step('Pulling latest images...')
      await dockerCompose(['pull'], ctx.projectDir, { stdio: 'inherit' })

      const s = p.spinner()
      s.start('Recreating containers...')
      // Prime the shared bundle_cache volume with web alone first so the up
      // below doesn't race the copy-up if this follows a `down -v` (cold volume).
      await primeBundleVolume(ctx.projectDir, { stdio: 'ignore' })
      await dockerCompose(['up', '-d'], ctx.projectDir)
      s.stop('Containers recreated.')

      p.log.success('Update complete! Migrations will run automatically on startup.')
      p.log.info('Run `spree logs` to follow the startup progress.')
    })
}
