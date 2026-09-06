import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const carton = await client.packageTypes.create({
  name: 'Master carton',
  kind: 'carton',
  length: 40,
  width: 30,
  height: 25,
  dimensions_unit: 'cm',
  max_weight: 20,
  weight_unit: 'kg',
})

// endregion:example

export { carton }
