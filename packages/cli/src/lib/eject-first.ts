import * as p from '@clack/prompts'
import pc from 'picocolors'
import { ejectProject } from '../commands/eject.js'
import { findApiDir, runsFromSource } from '../context.js'
import { confirmOrExit } from './prompt.js'

export interface EjectFirstOptions {
  /** What needs the ejected project, as the start of a sentence: "Installing Adyen". */
  task: string
  /** The exact command that agrees up front, for a run with no terminal to ask in. */
  retry?: string
  yes: boolean
}

/**
 * Eject a project still on the prebuilt image before a command that changes
 * `server/`, which that image never loads. Asks first, because ejecting is
 * slow and moves the app to a new database; with no terminal to ask in it
 * stops and names the command that agrees. A monorepo edge project already
 * runs from source, so it is left alone.
 */
export async function ejectFirst(
  projectDir: string,
  { task, retry, yes }: EjectFirstOptions,
): Promise<void> {
  if (runsFromSource(projectDir)) return

  const apiDir = findApiDir(projectDir)
  await confirmOrExit(
    [
      `This project runs the prebuilt Spree image, which does not load code or gems from ./${apiDir}.`,
      `${task} needs the project ejected first. Ejecting builds the Rails app from ./${apiDir}`,
      'with live reloading. The first build takes a few minutes, and the app moves to a new',
      'development database that does not have your current data.',
      'Eject now?',
    ].join('\n'),
    yes,
    { note: 'Ejecting needs the developer to agree, so ask them first.', retry },
  )

  try {
    await ejectProject(projectDir)
  } catch (error) {
    p.cancel(
      `Ejecting failed, so nothing else was done. Fix the problem above, run ${pc.bold('spree eject')}, then run this command again. ${error instanceof Error ? error.message : String(error)}`,
    )
    process.exit(1)
  }
}
