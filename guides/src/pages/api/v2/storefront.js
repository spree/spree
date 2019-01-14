import * as React from 'react'
import { RedocStandalone } from 'redoc'

import Layout from '../../../components/Layout'
import Breadcrumbs from '../../../components/Breadcrumbs'

const crumbs = [
  { name: 'API', url: '/api/overview' },
  { name: 'V2', url: '/api/v2' },
  { name: 'Storefront' }
]

const IndexPage = () => (
  <Layout activeRootSection="api/v2">
    <Breadcrumbs crumbs={crumbs} />
    <RedocStandalone
      specUrl="https://raw.githubusercontent.com/spree/spree/master/api/docs/v2/storefront/index.yaml"
      options={{
        disableSearch: true,
        scrollYOffset: 80,
        hideDownloadButton: true,
        theme: {
          colors: {
            primary: {
              main: '#0066CC'
            },
            success: {
              main: '#99CC00'
            },
            border: {
              dark: '#EEE'
            }
          },
          typography: {
            smoothing: 'unset',
            fontSize: '16px',
            fontFamily: '"Source Sans Pro", sans-serif;',
            headings: {
              fontFamily: '"Source Sans Pro", sans-serif;'
            },
            code: {
              fontSize: '16px',
              fontFamily: '"Roboto Mono", monospace;',
              fontWeight: 400,
              backgroundColor: '#0066CC',
              color: '#FFF'
            }
          },
          rightPanel: {
            backgroundColor: '#444'
          },
          menu: {
            width: '19rem',
            backgroundColor: '#f4f4f4'
          }
        }
      }}
    />
  </Layout>
)

export default IndexPage
