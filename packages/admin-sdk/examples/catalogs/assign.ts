import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A company assignment covers the node and its whole subtree.
const assignment = await client.catalogs.assign('cat_86Rf07xd4z', {
  assignable_type: 'company',
  assignable_id: 'comp_86Rf07xd4z',
})

// endregion:example

export { assignment }
