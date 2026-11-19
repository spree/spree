import { isNotFound, isRedirect } from '@tanstack/react-router'
import type { ErrorInfo } from 'react'

/**
 * Called with every render or loader error a panel's error screens catch. An
 * error boundary stops the error there, so it never reaches `window.onerror`,
 * where error trackers listen for everything else.
 */
export type ErrorReporter = (error: unknown, errorInfo?: ErrorInfo) => void

const reporters = new Map<string, ErrorReporter>()

/**
 * Registers `reporter` under `id`; returns a function that removes it. Throws
 * when `id` is taken, so re-running a plugin's registration never reports
 * each error twice.
 */
export function addErrorReporter(id: string, reporter: ErrorReporter): () => void {
  if (reporters.has(id)) throw new Error(`Error reporter "${id}" is already registered.`)
  reporters.set(id, reporter)
  return () => {
    if (reporters.get(id) === reporter) reporters.delete(id)
  }
}

/**
 * Hands a caught error to every registered reporter. The router's
 * `notFound()` and `redirect()` are control flow, not errors, so they are
 * skipped. A reporter that throws doesn't stop the others.
 */
export function reportCaughtError(error: unknown, errorInfo?: ErrorInfo): void {
  if (isNotFound(error) || isRedirect(error)) return
  for (const reporter of reporters.values()) {
    try {
      reporter(error, errorInfo)
    } catch (reporterError) {
      console.error(reporterError)
    }
  }
}
