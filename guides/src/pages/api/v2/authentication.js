// --- Dependencies
import * as React from 'react'
import { RedocStandalone } from 'redoc'

// --- Utils
import styles from '../../../utils/styles'

// --- Components
import Layout from '../../../components/Layout'
import Breadcrumbs from '../../../components/Breadcrumbs'

/**
 * Helpers
 */

const crumbs = [
  { name: 'API', url: '/api/overview' },
  { name: 'V2', url: '/api/v2' },
  { name: 'Authentication' }
]

/**
 * Component
 */

const AuthenticationPage = () => (
  <Layout
    activeRootSection="api"
    title="API V2 Authentication"
    description="Token authentication for API v2 access based on oAuth"
  >
    <Breadcrumbs crumbs={crumbs} />
    <RedocStandalone
      specUrl="https://raw.githubusercontent.com/spree/spree/master/api/docs/oauth/index.yml"
      options={{
        disableSearch: true,
        scrollYOffset: 80,
        hideDownloadButton: true,
        theme: styles.redocTheme
      }}
    />
  </Layout>
)

export default AuthenticationPage
