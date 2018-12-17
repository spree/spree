import * as React from 'react'

import Sidebar from './Sidebar'

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
      },
      {
        node: {
          fields: {
            isIndex: false,
            rootSection: 'API v2',
            section: 'API v2',
            slug: 'api/v2/extend-the-api'
          },
          frontmatter: {
            title: 'Extend The API'
          }
        }
      },
      {
        node: {
          fields: {
            isIndex: false,
            rootSection: 'API v2',
            section: 'API v2',
            slug: 'api/v2/storefront'
          },
          frontmatter: {
            title: 'Storefront'
          }
        }
      },
      {
        node: {
          fields: {
            isIndex: true,
            rootSection: 'API v2',
            section: 'API v2',
            slug: 'api/v2/'
          },
          frontmatter: {
            title: 'Overview'
          }
        }
      }
    ]
  }
]

const SidebarApi = () => <Sidebar nav={sidebarData} />

export default SidebarApi
