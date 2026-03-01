import type { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { railsRunner } from '../docker.js'

export function registerUserCommand(program: Command): void {
  const user = program
    .command('user')
    .description('Manage admin users')

  user
    .command('create')
    .description('Create an admin user')
    .option('--email <email>', 'admin email')
    .option('--password <password>', 'admin password')
    .action(async (flags: { email?: string; password?: string }) => {
      const ctx = detectProject()

      let email = flags.email
      let password = flags.password

      if (!email) {
        const result = await p.text({
          message: 'Admin email:',
          placeholder: 'admin@example.com',
          validate(value) {
            if (!value) return 'Email is required'
            if (!value.includes('@')) return 'Invalid email'
            return undefined
          },
        })
        if (p.isCancel(result)) {
          p.cancel('Cancelled.')
          process.exit(0)
        }
        email = result
      }

      if (!password) {
        const result = await p.password({
          message: 'Admin password:',
          validate(value) {
            if (!value || value.length < 6) return 'Password must be at least 6 characters'
            return undefined
          },
        })
        if (p.isCancel(result)) {
          p.cancel('Cancelled.')
          process.exit(0)
        }
        password = result
      }

      const s = p.spinner()
      s.start('Creating admin user...')

      const safeEmail = email.replace(/'/g, "\\'")
      const safePassword = password.replace(/'/g, "\\'")

      const script = [
        `admin = Spree.admin_user_class.create!(`,
        `email: '${safeEmail}',`,
        `password: '${safePassword}',`,
        `password_confirmation: '${safePassword}'`,
        `);`,
        `admin.add_role('admin', Spree::Store.default);`,
        `print admin.email`,
      ].join(' ')

      await railsRunner(script, ctx.projectDir)

      s.stop('Admin user created.')
      p.log.success(`Email: ${pc.cyan(email)}`)
    })
}
