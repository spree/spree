import * as p from '@clack/prompts'
import pc from 'picocolors'

/**
 * Ask before doing something the developer may not expect, exiting when they
 * decline. `--yes` agrees up front; a run without a terminal to ask in stops
 * instead of guessing.
 */
export async function confirmOrExit(message: string, yes: boolean): Promise<void> {
  if (yes) return
  if (!process.stdin.isTTY) {
    p.cancel(`${message}\nRe-run with ${pc.bold('--yes')} to agree.`)
    process.exit(1)
  }
  const answer = await p.confirm({ message })
  if (p.isCancel(answer) || !answer) {
    p.cancel('Nothing was changed.')
    process.exit(0)
  }
}
