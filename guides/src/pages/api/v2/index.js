import * as React from 'react'

import Layout from '../../../components/Layout'
import SidebarApi from '../../../components/SidebarApi'

const IndexPage = () => (
  <Layout activeRootSection="api/v2">
    <SidebarApi />
  </Layout>
)

export default IndexPage
