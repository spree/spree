import { createFileRoute, redirect } from '@tanstack/react-router'

// The profile moved under settings; old links and bookmarks follow it there.
export const Route = createFileRoute('/_authenticated/$sellerId/profile')({
  beforeLoad: ({ params }) => {
    throw redirect({ to: '/$sellerId/settings/profile', params })
  },
})
