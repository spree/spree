import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const REFERENCE_SCRIPT = fileURLToPath(new URL('./reference.mjs', import.meta.url))

// How each coding agent is run headless. Every agent runs with its permission
// prompts off, inside a throwaway directory, and prints a JSON event stream.
export const AGENTS = {
  // Changes nothing. Calibrates the checks: every task should fail on the
  // untouched scaffold, or its check can't tell a solution from no work.
  baseline: {
    format: 'stream-json',
    command: () => ['true', []],
  },
  // Applies the hand-written solution in tasks/<task>/reference/. Calibrates
  // the checks the other way: every task should pass with it.
  reference: {
    format: 'stream-json',
    command: (_prompt, { task }) => ['node', [REFERENCE_SCRIPT, task]],
  },
  claude: {
    format: 'stream-json',
    command: (prompt, { model, cwd }) => {
      // Headless runs skip the trust prompt that enables a project's MCP
      // servers, so the docs server create-spree-app configured is passed in.
      const mcpConfig = path.join(cwd, '.mcp.json')
      return [
        'claude',
        [
          '-p',
          prompt,
          '--output-format',
          'stream-json',
          '--verbose',
          '--dangerously-skip-permissions',
          ...(fs.existsSync(mcpConfig) ? ['--mcp-config', mcpConfig] : []),
          ...(model ? ['--model', model] : []),
        ],
      ]
    },
  },
  codex: {
    format: 'codex',
    command: (prompt, { model }) => [
      'codex',
      [
        'exec',
        '--json',
        '--dangerously-bypass-approvals-and-sandbox',
        ...(model ? ['--model', model] : []),
        prompt,
      ],
    ],
  },
  cursor: {
    format: 'stream-json',
    command: (prompt, { model }) => [
      'cursor-agent',
      [
        '-p',
        '--output-format',
        'stream-json',
        '--force',
        ...(model ? ['--model', model] : []),
        prompt,
      ],
    ],
  },
}
