import * as p from '@clack/prompts'
import pc from 'picocolors'

export interface UnattendedHelp {
  /** Shown before the retry instruction, only when there is no terminal to ask in. */
  note?: string
  /** The exact command that agrees up front; defaults to "with --yes". */
  retry?: string
}

/**
 * Ask before doing something the developer may not expect, exiting when they
 * decline. `--yes` agrees up front; a run without a terminal to ask in stops
 * instead of guessing.
 */
export async function confirmOrExit(
  message: string,
  yes: boolean,
  unattended: UnattendedHelp = {},
): Promise<void> {
  if (yes) return
  if (!process.stdin.isTTY) {
    const retry = unattended.retry ? `as ${pc.bold(unattended.retry)}` : `with ${pc.bold('--yes')}`
    p.cancel([message, unattended.note, `Re-run ${retry} to agree.`].filter(Boolean).join('\n'))
    process.exit(1)
  }
  const answer = await p.confirm({ message })
  if (p.isCancel(answer) || !answer) {
    p.cancel('Nothing was changed.')
    process.exit(0)
  }
}
