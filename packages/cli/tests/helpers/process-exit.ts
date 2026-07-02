import { vi } from 'vitest'

// `process.exit` is stubbed to throw so a command's exit shows up as a rejected
// promise the test can assert on, instead of tearing down the vitest worker.
export class ExitError extends Error {
  constructor(public code: number) {
    super(`process.exit(${code})`)
  }
}

// Spy on process.exit for the current test. Pair with `vi.restoreAllMocks()` in
// an afterEach so the spy never leaks into later tests.
export function mockProcessExit() {
  return vi.spyOn(process, 'exit').mockImplementation(((code?: number) => {
    throw new ExitError(code ?? 0)
  }) as never)
}
