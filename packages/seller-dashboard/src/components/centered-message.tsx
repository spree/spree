/** Full-height placeholder for the panel's loading and error states. */
export function CenteredMessage({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center text-muted-foreground text-sm">
      {children}
    </div>
  )
}
