import { AlertTriangleIcon, RotateCcwIcon } from 'lucide-react'
import { Component, type ReactNode } from 'react'
import { EmptyState } from '@/components/spree/empty-state'
import { Button } from '@/components/ui/button'

interface ErrorStateProps {
  /** Headline. Defaults to "Something went wrong". */
  title?: ReactNode
  /** Smaller text below the title. Pass an Error and we'll show its message. */
  description?: ReactNode
  /** Error object — when supplied, its message is shown if `description` is omitted. */
  error?: Error | null
  /** Called by the retry button. When omitted, the button is hidden. */
  onRetry?: () => void
  /** Override the retry label. Default "Try again". */
  retryLabel?: string
}

/**
 * Friendly error display. Use directly when an async operation has failed
 * (replacing the inline `<p className="text-destructive">Failed to load…</p>`
 * scattered through detail pages), or as a route's `errorComponent`.
 */
export function ErrorState({
  title = 'Something went wrong',
  description,
  error,
  onRetry,
  retryLabel = 'Try again',
}: ErrorStateProps) {
  const message = description ?? error?.message ?? 'An unexpected error occurred. Please try again.'

  return (
    <EmptyState
      icon={<AlertTriangleIcon />}
      title={title}
      description={message}
      action={
        onRetry && (
          <Button variant="outline" size="sm" onClick={onRetry}>
            <RotateCcwIcon className="size-4" />
            {retryLabel}
          </Button>
        )
      }
    />
  )
}

interface RouteErrorBoundaryProps {
  children: ReactNode
  /** Optional fallback renderer; receives the caught error and a reset function. */
  fallback?: (error: Error, reset: () => void) => ReactNode
}

interface RouteErrorBoundaryState {
  error: Error | null
}

/**
 * Route-level error boundary. Wrap a route component (or any subtree) so a
 * thrown render error shows an `<ErrorState>` instead of crashing the SPA.
 *
 * For TanStack Router data errors (loader/component throws), prefer the
 * route's `errorComponent: ErrorState` — that surface receives `{ error, reset }`
 * directly. This boundary is for cases where a child component throws during
 * render outside the loader path.
 */
export class RouteErrorBoundary extends Component<
  RouteErrorBoundaryProps,
  RouteErrorBoundaryState
> {
  state: RouteErrorBoundaryState = { error: null }

  static getDerivedStateFromError(error: Error): RouteErrorBoundaryState {
    return { error }
  }

  reset = () => {
    this.setState({ error: null })
  }

  render() {
    const { error } = this.state
    if (!error) return this.props.children

    if (this.props.fallback) {
      return this.props.fallback(error, this.reset)
    }

    return <ErrorState error={error} onRetry={this.reset} />
  }
}
