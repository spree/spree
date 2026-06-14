import fs from 'node:fs'
import pc from 'picocolors'

/** Sentinel for "no body was given" — distinct from a body that is literally `null`. */
export const NO_BODY = Symbol('no-body')

/**
 * Reads the request body for write verbs, gh-api style:
 *   -d '{"name":"Tee"}'   inline JSON
 *   -d @payload.json      from a file
 *   -d -                  from stdin
 *
 * Returns {@link NO_BODY} when no `-d` was passed. A literal `null`/`false`/`0`
 * body is preserved (not conflated with absence) so the request still carries it.
 */
export async function readBody(data: string | undefined): Promise<unknown> {
  if (data === undefined) return NO_BODY

  let raw: string
  if (data === '-') {
    raw = await readStdin()
  } else if (data.startsWith('@')) {
    const file = data.slice(1)
    try {
      raw = fs.readFileSync(file, 'utf-8')
    } catch (error) {
      if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') {
        throw new Error(`Request body file not found: ${file}`)
      }
      throw new Error(`Could not read request body file ${file}: ${(error as Error).message}`)
    }
  } else {
    raw = data
  }

  try {
    return JSON.parse(raw)
  } catch {
    const where = data === '-' ? ' (from stdin)' : data.startsWith('@') ? ` (${data.slice(1)})` : ''
    throw new Error(`Request body is not valid JSON${where}`)
  }
}

async function readStdin(): Promise<string> {
  // Without this, `-d -` on an interactive terminal hangs with no indication
  // that it's waiting for input.
  if (process.stdin.isTTY) {
    process.stderr.write(
      `${pc.dim('Reading request body from stdin — paste JSON and press Ctrl-D...')}\n`,
    )
  }
  const chunks: Buffer[] = []
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer)
  }
  return Buffer.concat(chunks).toString('utf-8')
}
