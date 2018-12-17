import * as React from 'react'

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

const SidebarApi = () => <Sidebar nav={sidebarData} />

export default SidebarApi
