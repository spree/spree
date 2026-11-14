import { isNotFound, isRedirect } from '@tanstack/react-router'
import type { ErrorInfo } from 'react'

/**
 * Called with every render or loader error a panel's error screens catch. An
 * error boundary stops the error there, so it never reaches `window.onerror`,
 * where error trackers listen for everything else.
 */
export type ErrorReporter = (error: unknown, errorInfo?: ErrorInfo) => void

const reporters = new Set<ErrorReporter>()

/** Registers `reporter`; returns a function that removes it. */
export function addErrorReporter(reporter: ErrorReporter): () => void {
  reporters.add(reporter)
  return () => {
    reporters.delete(reporter)
  }
}

/**
 * Hands a caught error to every registered reporter. The router's
 * `notFound()` and `redirect()` are control flow, not errors, so they are
 * skipped. A reporter that throws doesn't stop the others.
 */
export function reportError(error: unknown, errorInfo?: ErrorInfo): void {
  if (isNotFound(error) || isRedirect(error)) return
  for (const reporter of reporters) {
    try {
      reporter(error, errorInfo)
    } catch (reporterError) {
      console.error(reporterError)
    }
  }
}
