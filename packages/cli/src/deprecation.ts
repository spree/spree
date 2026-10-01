import pc from 'picocolors'

/**
 * Print the one-line notice a deprecated command or flag shows before it runs.
 * Written to stderr so scripts capturing stdout are unaffected.
 */
export function warnDeprecated(used: string, replacement: string): void {
  console.error(
    pc.yellow(
      `${pc.bold(used)} is deprecated and will be removed in Spree 7. Use ${pc.bold(replacement)} instead.`,
    ),
  )
}
