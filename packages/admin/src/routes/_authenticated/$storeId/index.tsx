import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

function DashboardPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Dashboard</h1>
      <p className="text-muted-foreground">Welcome to the Spree Admin dashboard.</p>
    </div>
  )
}
