import {
  LIFECYCLE_COMMANDS,
  telemetryDisabledReason,
  USAGE_DATA_DOCS,
  writeTelemetrySettings,
} from '@spree/telemetry'
import type { Command } from 'commander'
import pc from 'picocolors'

export function registerTelemetryCommand(program: Command): void {
  const telemetry = program
    .command('telemetry')
    .description('Show or change whether the CLI reports command usage')

  telemetry
    .command('status', { isDefault: true })
    .description('Show whether usage reporting is on, and why')
    .action(() => {
      const reason = telemetryDisabledReason()
      console.log(
        reason
          ? `Usage reporting is ${pc.bold('off')}: ${reason}.`
          : `Usage reporting is ${pc.bold('on')}.`,
      )
      console.log(`Reported commands: ${LIFECYCLE_COMMANDS.join(', ')}, and only from a terminal.`)
      console.log(`What is sent: ${USAGE_DATA_DOCS}`)
    })

  telemetry
    .command('disable')
    .description('Stop reporting command usage from this machine')
    .action(() => {
      saveSetting(false)
      console.log('Usage reporting is off for this machine.')
    })

  telemetry
    .command('enable')
    .description('Report command usage from this machine again')
    .action(() => {
      saveSetting(true)
      const reason = telemetryDisabledReason()
      console.log(
        reason
          ? `Turned on, but it stays off here: ${reason}.`
          : 'Usage reporting is on for this machine.',
      )
    })
}

// Fails the command when the setting cannot be saved, rather than telling the
// person reporting is off while it carries on.
function saveSetting(enabled: boolean): void {
  try {
    writeTelemetrySettings({ enabled })
  } catch (error) {
    console.error(`${pc.red('Error:')} ${error instanceof Error ? error.message : String(error)}`)
    process.exit(1)
  }
}
