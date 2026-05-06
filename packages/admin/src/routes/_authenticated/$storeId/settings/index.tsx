import { createFileRoute, redirect } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/settings/')({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$storeId/settings/store',
      params: { storeId: params.storeId },
      replace: true,
    })
  },
})
