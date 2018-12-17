import * as React from 'react'

import Layout from '../../../components/Layout'
import Sidebar from '../../../components/Sidebar'

const sidebarData = [
  {
    section: 'API v2',
    edges: [
      {
        node: {
          fields: {
            isIndex: false,
            rootSection: 'API v2',
            section: 'API v2',
            slug: 'api/v2/authentication'
          },
          frontmatter: {
            title: 'Authentication'
          }
        }
      }
    ]
  }
]

const IndexPage = () => (
  <Layout activeRootSection="api/v2">
    <Sidebar nav={sidebarData} />
  </Layout>
)

export default IndexPage
