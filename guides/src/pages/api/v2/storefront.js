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
  { name: 'Storefront' }
]

/**
 * Component
 */

const IndexPage = () => (
  <Layout
    activeRootSection="api"
    title="Storefront API v2"
    description="Modern REST API based on the JSON API spec which provides you with necessary endpoints to build amazing user intefaces either in JavaScript frameworks or native mobile libraries."
  >
    <Breadcrumbs crumbs={crumbs} />
    <RedocStandalone
      specUrl="https://raw.githubusercontent.com/spree/spree/master/api/docs/v2/storefront/index.yaml"
      options={{
        disableSearch: true,
        scrollYOffset: 80,
        hideDownloadButton: true,
        theme: styles.redocTheme
      }}
    />
  </Layout>
)

export default IndexPage
